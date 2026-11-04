/* timing.c: a trace-driven timing model of a small in-order core (sim64 --timing).  Documentation, parameters and limits: docs/timing-model.md.
 *
 * The program runs functionally in sim64; for every executed instruction the executor leaves a record (timing.h).  Here each record is fed, in program
 * order, to any number of model instances.  A model computes, for the instruction, the cycle in which its bytes are in the prefetch buffer, the cycle
 * it is decoded, and the cycle it issues, from
 *   - the fetch unit: one aligned window of W bytes per cycle, an I-cache (optional), a prefetch buffer of N bytes with back pressure,
 *   - the decode stage (iw instructions and decw bytes per cycle, the length decode of the prefix-coded encodings as extra latency `ldec`),
 *   - a queue of dq instructions between decode and issue,
 *   - the issue stage (iw instructions per cycle, mp memory accesses per cycle, one branch per cycle) with a register scoreboard,
 *   - result latencies by class, a D-cache (optional), non-pipelined divide units, block instructions and system calls as counted costs,
 *   - branch prediction (static, bimodal, perfect...), a BTB, a return stack, an indirect-target table, and the redirect of the fetch unit.
 * Every idle issue cycle is charged to the front end (waiting for instruction bytes, with the cause) or to the back end (waiting for an operand or a unit).
 * No wrong-path instructions are fetched or executed; no memory dependences (a load after a store to the same address costs a load); no interrupts.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include "fmt.h"
#include "calib.h"
#include "pdp64-consts.h"
#include "pdp64enc.h"
#include "timing.h"

struct tm_rec tm_cur;
int tm_on;

/* ------------------------------------------------------------------------------------------------------------------ */
/* the record of an instruction                                                                                        */

void tm_begin(uint64_t pc, int nparcels)
{
	struct tm_rec *t = &tm_cur;
	t->pc = pc; t->len = 2 * nparcels; t->n = 0; t->rmask = t->wmask = 0; t->nld = t->nst = t->ldb = t->stb = 0;
	t->cls = TC_ALU; t->bk = BK_NONE; t->back = 0; t->fused = 0;
}
void tm_mem(int store, uint64_t addr, int size)
{
	struct tm_rec *t = &tm_cur;
	if (store) { t->nst++; t->stb += size; } else { t->nld++; t->ldb += size; }
	if (t->n < (t->cls == TC_BLOCK ? 8 : TM_MAXEV)) {		/* a block instruction moves bytes one at a time: keep only the first few for the cache */
		struct tm_ev *e = &t->ev[t->n++];
		e->k = store ? TM_EV_ST : TM_EV_LD; e->r = 0; e->sz = size; e->addr = addr;
	}
}

static int64_t sx(uint64_t v, int bits) { return bits >= 64 || bits <= 0 ? (int64_t)v : (int64_t)(v << (64 - bits)) >> (64 - bits); }

/* the original encoding: class from the decoded fields */
void tm_fmt(const struct fmt *f)
{
	struct tm_rec *t = &tm_cur;
	int opc = f->opc;
	if (!tm_on) return;
	t->cls = TC_ALU;
	if (opc <= OPGROUP_LEA) { t->cls = opc == OPGROUP_LEA ? TC_ALU : TC_MOVE; return; }
	if (opc >= MN_ALU_ADD && opc <= MN_ALU_FCMP) {
		if (opc == MN_ALU_MUL || opc == MN_ALU_MULH) t->cls = TC_MUL;
		else if (opc == MN_ALU_FADD || opc == MN_ALU_FSUB || opc == MN_ALU_FCMP) t->cls = TC_FADD;
		else if (opc == MN_ALU_FMUL) t->cls = TC_FMUL;
		return;
	}
	if (opc >= MN_BRANCH_BR && opc <= MN_BRANCH_BLOS) {
		int64_t d = f->shape == FS_BR0 ? (int8_t)((f->reg << lowbits) | f->low) : sx(f->d, branchbits(f->len));
		t->cls = TC_BRANCH; t->bk = opc == MN_BRANCH_BR ? BK_JMP_D : BK_COND; t->back = d < 0;
		return;
	}
	if (opc == OPGROUP_CBR || opc == OPGROUP_CBW || opc == OPGROUP_CBRR || opc == OPGROUP_SOB || opc == OPGROUP_TAG) {
		int bits = opc == OPGROUP_CBR ? cbbits(f->len) : opc == OPGROUP_CBW ? cbwbits(f->len) : opc == OPGROUP_CBRR ? cbrbits(f->len) : branchbits(f->len);
		t->cls = TC_BRANCH; t->bk = BK_COND; t->back = sx(f->d, bits) < 0;
		return;
	}
	if (opc == OPGROUP_SOP) {
		int sub = f->reg;
		if (sub == MN_SOP_PUSH || sub == MN_SOP_POP || sub == MN_SOP_PUSHM || sub == MN_SOP_POPM) { t->cls = TC_MOVE; return; }
		if (sub == MN_SOP_JMP || sub == MN_SOP_CALL) {
			int direct = f->shape == FS_WIDE && (f->low == AMODE_PCREL || f->low == AMODE_ABS);
			t->cls = sub == MN_SOP_CALL ? TC_CALL : TC_BRANCH;
			t->bk = sub == MN_SOP_CALL ? (direct ? BK_CALL_D : BK_CALL_I) : (direct ? BK_JMP_D : BK_JMP_I);
		}
		return;
	}
	if (opc == OPGROUP_XFER) {
		t->cls = f->reg == MN_XFER_CALLI ? TC_CALL : TC_BRANCH;
		t->bk = f->reg == MN_XFER_CALLI ? BK_CALL_I : BK_JMP_I;
		return;
	}
	if (opc == OPGROUP_SYS) {
		if (f->reg == 0 && f->low == MN_SYS_NONE_RET) { t->cls = TC_RET; t->bk = BK_RET; }
		else if (f->reg == MN_SYS_TRAP || f->reg == MN_SYS_TRAPL || (f->reg == 0 && f->low == MN_SYS_NONE_HALT)) t->cls = TC_SYS;
		return;
	}
	if (opc == OPGROUP_BESC) { if (f->sub == MN_BESC_CLMULL || f->sub == MN_BESC_CLMULH) t->cls = TC_MUL; return; }
	if (opc == OPGROUP_AESC) {
		int s = f->sub;
		if (s == MN_AESC_DIV || s == MN_AESC_DIVU || s == MN_AESC_MOD || s == MN_AESC_MODU) t->cls = TC_DIV;
		else if (s == MN_AESC_MULHU) t->cls = TC_MUL;
		return;
	}
	if (opc == OPGROUP_MBLK) { t->cls = TC_BLOCK; return; }
	if (opc == OPGROUP_FESC) {
		int s = f->sub;
		if (s == MN_FESC_FDIV || s == MN_FESC_FSQRT || s == MN_FESC_FDIV32 || s == MN_FESC_FSQRT32 || s == MN_FESC_FDIV16 || s == MN_FESC_FSQRT16) t->cls = TC_FDIV;
		else if (s == MN_FESC_FMUL32 || s == MN_FESC_FMUL16 || (s >= MN_FESC_FMADD && s <= MN_FESC_FNMSUB) || (s >= MN_FESC_FMADD32 && s <= MN_FESC_FNMSUB32) || (s >= MN_FESC_FMADD16 && s <= MN_FESC_FNMSUB16)) t->cls = TC_FMUL;
		else t->cls = TC_FADD;
	}
}

/* the prefix-coded encodings: class from the mnemonic (cached per table) */
struct mnc { uint8_t done, cls, bk, fused, dir_op; };	/* dir_op: operand index to test for a direct transfer; 0xff none */
static struct mnc *MC[3];
static const char *const CCS[] = { "ne", "eq", "pl", "mi", "vc", "vs", "cc", "cs", "ge", "lt", "gt", "le", "hi", "los" };
static int is_cc(const char *s) { for (size_t i = 0; i < sizeof CCS / sizeof *CCS; i++) if (!strcmp(s, CCS[i])) return 1; return 0; }
static int starts(const char *s, const char *p) { return !strncmp(s, p, strlen(p)); }
static void classify_name(const char *n, struct mnc *c)
{
	c->done = 1; c->cls = TC_ALU; c->bk = BK_NONE; c->fused = 0; c->dir_op = 0xff;
	if (!strcmp(n, "br")) { c->cls = TC_BRANCH; c->bk = BK_JMP_D; return; }
	if (n[0] == 'b' && is_cc(n + 1)) { c->cls = TC_BRANCH; c->bk = BK_COND; return; }
	if (starts(n, "cb") && is_cc(n + 2)) { c->cls = TC_BRANCH; c->bk = BK_COND; return; }
	if (!strcmp(n, "sob") || !strcmp(n, "btag") || !strcmp(n, "bntag")) { c->cls = TC_BRANCH; c->bk = BK_COND; return; }
	if (!strcmp(n, "jmp")) { c->cls = TC_BRANCH; c->bk = BK_JMP_D; c->dir_op = 0; return; }
	if (!strcmp(n, "call")) { c->cls = TC_CALL; c->bk = BK_CALL_D; c->dir_op = 0; return; }
	if (!strcmp(n, "jmpi") || !strcmp(n, "jtag")) { c->cls = TC_BRANCH; c->bk = BK_JMP_I; return; }
	if (!strcmp(n, "calli")) { c->cls = TC_CALL; c->bk = BK_CALL_I; return; }
	if (!strcmp(n, "ret")) { c->cls = TC_RET; c->bk = BK_RET; return; }
	if (!strcmp(n, "movcall")) { c->cls = TC_CALL; c->bk = BK_CALL_D; c->fused = 1; c->dir_op = 2; return; }
	if (!strcmp(n, "popmret") || !strcmp(n, "popret")) { c->cls = TC_RET; c->bk = BK_RET; c->fused = 1; return; }
	if (!strcmp(n, "mov2")) { c->cls = TC_MOVE; c->fused = 1; return; }
	if (starts(n, "mov") || !strcmp(n, "push") || !strcmp(n, "pop") || !strcmp(n, "pushm") || !strcmp(n, "popm")) { c->cls = TC_MOVE; return; }
	if (!strcmp(n, "mul") || !strcmp(n, "mulh") || !strcmp(n, "mulhu") || !strcmp(n, "mulv") || starts(n, "clmul")) { c->cls = TC_MUL; return; }
	if (!strcmp(n, "div") || !strcmp(n, "divu") || !strcmp(n, "mod") || !strcmp(n, "modu")) { c->cls = TC_DIV; return; }
	if (!strcmp(n, "mcpy") || !strcmp(n, "mmov") || !strcmp(n, "mset") || !strcmp(n, "mcmp") || !strcmp(n, "mscn") || !strcmp(n, "mscnn")) { c->cls = TC_BLOCK; return; }
	if (!strcmp(n, "trap") || !strcmp(n, "trapl") || !strcmp(n, "halt")) { c->cls = TC_SYS; return; }
	if (n[0] == 'f' && strcmp(n, "fence") && strcmp(n, "fsflags")) {
		if (starts(n, "fdiv") || starts(n, "fsqrt")) c->cls = TC_FDIV;
		else if (starts(n, "fmul") || starts(n, "fmadd") || starts(n, "fmsub") || starts(n, "fnmadd") || starts(n, "fnmsub")) c->cls = TC_FMUL;
		else c->cls = TC_FADD;
	}
}
void tm_enc(int enc, int mn, const char *name, const struct einsn *in)
{
	struct tm_rec *t = &tm_cur;
	if (!tm_on) return;
	const struct etab *tab = enc == 1 ? &enc_tab_16 : &enc_tab_32;
	if (!MC[enc]) MC[enc] = calloc(tab->nmn, sizeof **MC);
	struct mnc *c = &MC[enc][mn];
	if (!c->done) classify_name(name, c);
	t->cls = c->cls; t->bk = c->bk; t->fused = c->fused;
	if (c->bk == BK_COND) {
		int last = in->nops - 1;
		t->back = in->op[last].k == EK_PC && in->op[last].v < 0;
	} else if (c->dir_op != 0xff) {
		int k = in->op[c->dir_op].k;
		int direct = k == EK_PC || k == EK_A;
		if (!direct) t->bk = c->bk == BK_CALL_D ? BK_CALL_I : BK_JMP_I;
	}
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* parameters                                                                                                          */

struct cfg {
	int iw, decw, dq, W, N, fl, dl, ldec, ldecp;
	int pred, bht, btb, tkb, ras, ibtb, brlat, mpx;
	int ic, isz, iline, iways, imiss, ipf;
	int dc, dsz, dline, dways, dmiss;
	int alu, ld, mul, div, fadd, fmul, fdiv, mp, blkb, blkw, sys;
};
enum { P_NONE, P_STATIC, P_BIMODAL, P_PERFECT, P_TAKEN };
static const struct param { const char *name; int off, def, lo, hi; const char *help; } PARAMS[] = {
#define P(n, d, lo, hi, h) { #n, offsetof(struct cfg, n), d, lo, hi, h }
	P(iw, 1, 1, 4, "issue width: instructions per cycle (decode width is the same)"),
	P(decw, 16, 2, 64, "decode bytes per cycle (an instruction longer than this takes several cycles)"),
	P(dq, 4, 1, 16, "instructions between decode and issue (decode can run ahead of issue by this many)"),
	P(W, 8, 2, 64, "fetch width: bytes per cycle from an aligned window"),
	P(N, 32, 4, 256, "prefetch buffer bytes (raised to W+9 if smaller: an instruction may be 10 bytes)"),
	P(fl, 1, 1, 8, "fetch latency: cycles from the window request to its bytes in the buffer (cache hit)"),
	P(dl, 1, 1, 8, "decode stage: cycles from decode to being ready to issue"),
	P(ldec, -1, -1, 8, "length-decode latency added to the front end of every encoding (-1: use ldec0 for pdp64/r20 and ldecp for /16 and /32)"),
	P(ldecp, 1, 0, 8, "length-decode latency of pdp64/16 and pdp64/32 (prefix-coded) when ldec=-1; pdp64/r20 has 0"),
	P(pred, P_BIMODAL, 0, 4, "conditional branch prediction: none (always not taken) static (backward taken) bimodal perfect taken"),
	P(bht, 2048, 1, 1 << 20, "bimodal table entries (2-bit counters)"),
	P(btb, 0, 0, 1 << 20, "branch target buffer entries (0: none); a hit redirects the fetch unit with no bubble"),
	P(tkb, 1, 0, 8, "bubble of a predicted-taken transfer without BTB hit: cycles from the decode of the branch to the fetch request of its target"),
	P(ras, 16, 0, 256, "return address stack entries (0: returns are predicted like indirect jumps)"),
	P(ibtb, 64, 1, 1 << 20, "indirect-target table entries (last target seen)"),
	P(brlat, 1, 1, 8, "branch resolution: cycles from issue (operands ready) to the redirect of the fetch unit when mispredicted"),
	P(mpx, 0, 0, 32, "extra cycles of every misprediction"),
	P(ic, 0, 0, 1, "I-cache on (0: instruction fetch always hits)"),
	P(isz, 16384, 256, 1 << 26, "I-cache bytes"),
	P(iline, 32, 8, 256, "I-cache line bytes (at least W)"),
	P(iways, 2, 1, 16, "I-cache associativity"),
	P(imiss, 20, 1, 1000, "I-cache miss penalty in cycles"),
	P(ipf, 0, 0, 1, "I-cache next-line prefetch on a miss"),
	P(dc, 0, 0, 1, "D-cache on (0: loads always hit)"),
	P(dsz, 16384, 256, 1 << 26, "D-cache bytes"),
	P(dline, 32, 8, 256, "D-cache line bytes"),
	P(dways, 2, 1, 16, "D-cache associativity"),
	P(dmiss, 20, 1, 1000, "D-cache miss penalty in cycles"),
	P(alu, 1, 1, 16, "ALU latency (issue to use)"),
	P(ld, 3, 1, 16, "load-use latency on a D-cache hit (issue to use)"),
	P(mul, 3, 1, 32, "multiply latency (pipelined)"),
	P(div, 20, 1, 200, "integer divide latency (not pipelined)"),
	P(fadd, 4, 1, 32, "floating-point add/sub/compare/convert latency (pipelined)"),
	P(fmul, 4, 1, 32, "floating-point multiply and fused multiply-add latency (pipelined)"),
	P(fdiv, 20, 1, 200, "floating-point divide and square root latency (not pipelined)"),
	P(mp, 1, 1, 4, "memory accesses per cycle"),
	P(blkb, 2, 0, 100, "block instruction (mcpy...) fixed cost in cycles"),
	P(blkw, 8, 1, 64, "block instruction bytes per cycle"),
	P(sys, 20, 1, 1000, "trap / halt: cycles (the pipeline is held)"),
#undef P
};
#define NPARAMS ((int)(sizeof PARAMS / sizeof *PARAMS))
void tm_help(FILE *o)
{
	fprintf(o, "timing model parameters (--timing=name=value,...; also name=LABEL for the label of the result line, pred=none|static|bimodal|perfect|taken, ldec0=N):\n");
	for (int i = 0; i < NPARAMS; i++) fprintf(o, "  %-6s %-8d %s\n", PARAMS[i].name, PARAMS[i].def, PARAMS[i].help);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* caches                                                                                                              */

struct cache { int sets, ways, lshift; uint64_t *tag; int64_t *rdy; uint64_t *age; uint64_t clk, acc, miss; };
static int cache_init(struct cache *c, int size, int line, int ways)
{
	c->lshift = 0; while ((1 << c->lshift) < line) c->lshift++;
	c->ways = ways; c->sets = size / (line * ways);
	if (c->sets < 1) c->sets = 1;
	size_t n = (size_t)c->sets * ways;
	c->tag = malloc(n * sizeof *c->tag); c->rdy = calloc(n, sizeof *c->rdy); c->age = calloc(n, sizeof *c->age);
	for (size_t i = 0; i < n; i++) c->tag[i] = ~(uint64_t)0;
	c->clk = c->acc = c->miss = 0;
	return c->tag && c->rdy && c->age;
}
/* access at time `now`: returns 1 on a hit.  *avail: the time the line's data is there (now on a hit unless the line is still being filled; now+pen on a miss) */
static int cache_access(struct cache *c, uint64_t addr, int64_t now, int pen, int64_t *avail)
{
	uint64_t line = addr >> c->lshift;
	size_t set = (size_t)(line % c->sets) * c->ways, v = set;
	c->acc++; c->clk++;
	for (int w = 0; w < c->ways; w++)
		if (c->tag[set + w] == line) { c->age[set + w] = c->clk; *avail = c->rdy[set + w] > now ? c->rdy[set + w] : now; return 1; }
	for (int w = 1; w < c->ways; w++) if (c->age[set + w] < c->age[v]) v = set + w;
	c->tag[v] = line; c->age[v] = c->clk; c->rdy[v] = now + pen; c->miss++;
	*avail = now + pen;
	return 0;
}
static void cache_install(struct cache *c, uint64_t addr, int64_t rdy)
{
	uint64_t line = addr >> c->lshift;
	size_t set = (size_t)(line % c->sets) * c->ways, v = set;
	for (int w = 0; w < c->ways; w++) if (c->tag[set + w] == line) return;
	for (int w = 1; w < c->ways; w++) if (c->age[set + w] < c->age[v]) v = set + w;
	c->tag[v] = line; c->age[v] = ++c->clk; c->rdy[v] = rdy;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the model                                                                                                           */

enum { FC_START, FC_SEQ, FC_IMISS, FC_TAKEN, FC_MISP, FC_DEC, FC_QUEUE, FC_N };		/* why the front end had nothing to issue */
static const char *const FC_NAME[FC_N] = { "start", "seq", "imiss", "taken", "misp", "dec", "queue" };
enum { XC_ALU, XC_LOAD, XC_DMISS, XC_MUL, XC_DIV, XC_FP, XC_BLOCK, XC_STRUCT, XC_NONE, XC_N };	/* why the back end could not issue (the producer of the operand) */
static const char *const XC_NAME[XC_N] = { "alu", "load", "dmiss", "mul", "div", "fp", "block", "struct", "none" };

struct stage { int64_t cur; int n, bytes, mem, br; };
struct win { int64_t arr, req; int cause; };

struct tm_model {
	struct cfg c;
	char name[64];
	int enc, ld_extra;
	/* fetch */
	int newseg, segcause; int64_t R;
	uint64_t nextwin, seg_pc0, firstwin, seg_base, cum; int64_t qready; unsigned nseg;
	uint64_t cumend[256]; int64_t dtime[256]; unsigned nins;	/* per instruction (ring): the stream position of its end (bytes of instructions since the start) and its decode cycle */
	struct win wr[32];
	struct cache ic, dc;
	/* stages */
	struct stage dec, iss;
	int64_t ihist[16]; unsigned ni;
	int64_t lastc, lastissue;
	/* back end */
	int64_t ready[TM_NREG]; uint8_t pcls[TM_NREG];
	int64_t div_free, fdiv_free;
	int64_t loc[TM_NREG]; uint8_t locA[TM_NREG], loctag[TM_NREG]; uint32_t locst[TM_NREG], stamp;
	/* predictors */
	int8_t *bht; uint64_t *btb_tag, *btb_tgt, *ib_tgt; uint64_t *ras_st; int ras_top, ras_n;
	/* statistics */
	uint64_t insns, bytes, active, occ_blk, occ_sys, occ_mem;
	uint64_t fe[FC_N], ex[XC_N];
	uint64_t branches, cond, taken_n, mispred, ret_n, ret_miss, ind_n, ind_miss, btb_hit;
	uint64_t fused_n, cls_n[TC_NCLASS];
	/* per pc */
	uint32_t *pc_n; uint64_t *pc_cyc, *pc_fe, *pc_ex; int pcprof;
};
static uint64_t text_lo, text_hi;
void tm_set_text(uint64_t lo, uint64_t hi) { text_lo = lo; text_hi = hi; }

static int parse_pred(const char *v)
{
	if (!strcmp(v, "none")) return P_NONE; if (!strcmp(v, "static")) return P_STATIC; if (!strcmp(v, "bimodal")) return P_BIMODAL;
	if (!strcmp(v, "perfect")) return P_PERFECT; if (!strcmp(v, "taken")) return P_TAKEN; return -1;
}

struct tm_model *tm_new(const char *spec, int enc, char *err, size_t errsz)
{
	struct tm_model *m = calloc(1, sizeof *m);
	struct cfg *c = &m->c;
	int ldec0 = 0;
	char *buf = strdup(spec ? spec : ""), *save = NULL;
	for (int i = 0; i < NPARAMS; i++) *(int *)((char *)c + PARAMS[i].off) = PARAMS[i].def;
	snprintf(m->name, sizeof m->name, "m");
	for (char *tok = strtok_r(buf, ",", &save); tok; tok = strtok_r(NULL, ",", &save)) {
		char *eq = strchr(tok, '=');
		if (!eq) { snprintf(err, errsz, "timing: '%s' is not name=value", tok); goto bad; }
		*eq = 0; const char *k = tok, *v = eq + 1;
		if (!strcmp(k, "name") || !strcmp(k, "label")) { snprintf(m->name, sizeof m->name, "%s", v); continue; }
		if (!strcmp(k, "ldec0")) { ldec0 = atoi(v); continue; }
		if (!strcmp(k, "pred") && parse_pred(v) >= 0) { c->pred = parse_pred(v); continue; }
		int found = 0;
		for (int i = 0; i < NPARAMS; i++) if (!strcmp(k, PARAMS[i].name)) {
			long x = strtol(v, NULL, 0);
			if (x < PARAMS[i].lo || x > PARAMS[i].hi) { snprintf(err, errsz, "timing: %s=%s out of range [%d,%d]", k, v, PARAMS[i].lo, PARAMS[i].hi); goto bad; }
			*(int *)((char *)c + PARAMS[i].off) = (int)x; found = 1; break;
		}
		if (!found) { snprintf(err, errsz, "timing: unknown parameter '%s' (sim64 --timing-help)", k); goto bad; }
	}
	m->enc = enc;
	m->ld_extra = c->ldec >= 0 ? c->ldec : enc ? c->ldecp : ldec0;
	if (c->N < c->W + 9) c->N = c->W + 9;
	if (c->iline < c->W) c->iline = c->W;
	if (c->ic && !cache_init(&m->ic, c->isz, c->iline, c->iways)) goto bad;
	if (c->dc && !cache_init(&m->dc, c->dsz, c->dline, c->dways)) goto bad;
	m->bht = malloc(c->bht); memset(m->bht, -1, c->bht);
	if (c->btb) { m->btb_tag = malloc(c->btb * 8); m->btb_tgt = calloc(c->btb, 8); memset(m->btb_tag, 0xff, c->btb * 8); }
	m->ib_tgt = calloc(c->ibtb, 8);
	if (c->ras) m->ras_st = calloc(c->ras, 8);
	m->newseg = 1; m->segcause = FC_START; m->R = 0;
	m->lastc = -1; m->lastissue = -1;
	m->dec.cur = -1; m->iss.cur = -1;
	free(buf);
	return m;
bad:
	free(buf); free(m);
	return NULL;
}

static inline int64_t mx(int64_t a, int64_t b) { return a > b ? a : b; }
static inline int64_t mn64(int64_t a, int64_t b) { return a < b ? a : b; }
static int prio(int cause) { return cause == FC_IMISS ? 5 : cause == FC_MISP ? 4 : cause == FC_TAKEN ? 3 : cause == FC_START ? 2 : 1; }

static void seg_start(struct tm_model *m, uint64_t pc)
{
	const struct cfg *c = &m->c;
	m->nextwin = m->firstwin = pc / c->W; m->seg_pc0 = pc; m->seg_base = m->cum; m->qready = m->R; m->nseg = 0;
	m->newseg = 0;
}

static void fetch_window(struct tm_model *m)
{
	const struct cfg *c = &m->c;
	uint64_t wi = m->nextwin;
	int64_t req = m->qready, bafter = (int64_t)(m->seg_base + (wi + 1) * c->W) - (int64_t)m->seg_pc0, need = bafter - c->N;
	if (need > 0 && m->nins && m->cumend[(m->nins - 1) & 255] >= (uint64_t)need) {		/* back pressure: wait until the buffer has room, i.e. until the instructions up to stream position `need` are decoded */
		unsigned j = m->nins - 1;
		while (j > 0 && m->nins - j < 250 && m->cumend[(j - 1) & 255] >= (uint64_t)need) j--;
		req = mx(req, m->dtime[j & 255]);
	}
	int64_t avail = req; int hit = 1;
	if (c->ic) {
		hit = cache_access(&m->ic, wi * c->W, req, c->imiss, &avail);
		if (!hit && c->ipf) cache_install(&m->ic, wi * c->W + c->iline, avail);
	}
	struct win *w = &m->wr[wi & 31];
	w->req = req; w->arr = avail + c->fl;
	w->cause = avail > req ? FC_IMISS : wi == m->firstwin ? m->segcause : FC_SEQ;
	m->qready = mx(req + 1, avail);
	m->nextwin++;
}

static int64_t pack_dec(struct tm_model *m, int64_t t, int len)
{
	const struct cfg *c = &m->c;
	struct stage *s = &m->dec;
	if (t > s->cur) { s->cur = t; s->n = 0; s->bytes = 0; }
	if (s->n >= c->iw || (s->n > 0 && s->bytes + len > c->decw)) { s->cur++; s->n = 0; s->bytes = 0; }
	int64_t d = s->cur;
	s->n++; s->bytes += len;
	if (len > c->decw) { int extra = (len + c->decw - 1) / c->decw - 1; s->cur += extra; s->n = c->iw; s->bytes = c->decw; d = s->cur; }
	return d;
}
/* the issue slot: iw instructions, mp memory accesses, one branch per cycle.  An instruction with more memory accesses than ports holds the stage for the extra cycles. */
static int64_t pack_iss(struct tm_model *m, int64_t t, int nmem, int isbr, int occ)
{
	const struct cfg *c = &m->c;
	struct stage *s = &m->iss;
	int nm = nmem < c->mp ? nmem : c->mp;
	if (t > s->cur) { s->cur = t; s->n = 0; s->mem = 0; s->br = 0; }
	if (s->n >= c->iw || s->mem + nm > c->mp || s->br + isbr > 1) { s->cur++; s->n = 0; s->mem = 0; s->br = 0; }
	int64_t at = s->cur;
	s->n++; s->mem += nm; s->br += isbr;
	if (occ > 0) { s->cur += occ; s->n = c->iw; s->mem = c->mp; s->br = 1; }
	return at;
}

static int xtag_of(int cls)
{
	switch (cls) { case TC_MUL: return XC_MUL; case TC_DIV: return XC_DIV; case TC_FADD: case TC_FMUL: case TC_FDIV: return XC_FP; case TC_BLOCK: case TC_SYS: return XC_BLOCK; default: return XC_ALU; }
}
static int oplat(const struct cfg *c, int cls)
{
	switch (cls) { case TC_MUL: return c->mul; case TC_DIV: return c->div; case TC_FADD: return c->fadd; case TC_FMUL: return c->fmul; case TC_FDIV: return c->fdiv;
	case TC_MOVE: case TC_CALL: case TC_RET: return 1; default: return c->alu; }
}

static void feed(struct tm_model *m, const struct tm_rec *r)
{
	const struct cfg *c = &m->c;
	int64_t d, F, T = 0, t, ab, db, vt = -1;
	int tcause = XC_NONE, seen = 0, missed = 0;
	m->insns++; m->bytes += r->len; m->cls_n[r->cls]++; if (r->fused) m->fused_n++;
	if (m->newseg) seg_start(m, r->pc);

	/* ---- fetch: the windows that hold the instruction */
	uint64_t w0 = r->pc / c->W, w1 = (r->pc + r->len - 1) / c->W;
	while (m->nextwin <= w1) fetch_window(m);
	int64_t arrive = 0; int fcause = FC_SEQ;
	for (uint64_t w = w0; w <= w1; w++) {
		struct win *x = &m->wr[w & 31];
		if (x->arr > arrive) arrive = x->arr;
		if (prio(x->cause) > prio(fcause)) fcause = x->cause;
	}
	/* ---- decode */
	int64_t dstart = arrive + m->ld_extra;
	if (m->ni >= (unsigned)c->dq) {
		int64_t q = m->ihist[(m->ni - c->dq) & 15];
		if (q > dstart) { dstart = q; fcause = FC_QUEUE; }
	}
	d = pack_dec(m, dstart, r->len);
	if (d > dstart && fcause != FC_QUEUE) fcause = FC_DEC;
	m->cum += r->len; m->cumend[m->nins & 255] = m->cum; m->dtime[m->nins & 255] = d; m->nins++; m->nseg++;
	F = d + c->dl;

	/* ---- operands: every register the instruction reads, and the registers it writes (write after write), must be ready */
	uint64_t mask = r->rmask | (r->wmask & ~(1ull << 32));
	for (uint64_t b = mask; b; b &= b - 1) {
		int x = __builtin_ctzll(b);
		if (m->ready[x] > T) { T = m->ready[x]; tcause = m->pcls[x]; }
	}
	if (r->cls == TC_DIV && m->div_free > T) { T = m->div_free; tcause = XC_STRUCT; }
	if (r->cls == TC_FDIV && m->fdiv_free > T) { T = m->fdiv_free; tcause = XC_STRUCT; }

	/* ---- issue */
	int nmem = r->nld + r->nst, occ = 0, cost = 0;
	if (r->cls == TC_BLOCK) {
		unsigned bytes = r->ldb > r->stb ? r->ldb : r->stb;
		cost = c->blkb + (int)((bytes + c->blkw - 1) / c->blkw);
		if (cost < 1) cost = 1;
		occ = cost - 1; nmem = 0;
	} else if (r->cls == TC_SYS) { cost = c->sys; occ = cost - 1; }
	else if (nmem > c->mp) occ = (nmem + c->mp - 1) / c->mp - 1;
	t = pack_iss(m, mx(F, T), r->cls == TC_BLOCK ? 0 : nmem, r->bk != BK_NONE, occ);
	m->ihist[m->ni & 15] = t; m->ni++;

	/* ---- the idle cycles before this issue are charged to the front end up to the cycle the instruction was ready (F), then to the back end */
	int64_t idle = t > m->lastc ? t - m->lastc - 1 : 0, fei = 0, exi = 0;
	if (idle > 0) {
		fei = mx(0, mn64(t, F) - (m->lastc + 1));
		if (fei > idle) fei = idle;
		exi = idle - fei;
		if (fcause == FC_QUEUE) { exi += fei; fei = 0; }
		if (fei) m->fe[fcause] += fei;
		if (exi) m->ex[tcause == XC_NONE && T <= F ? XC_STRUCT : tcause] += exi;
	}
	if (t != m->lastissue) m->active++;
	int64_t prevlast = m->lastc;
	m->lastissue = t;
	m->lastc = mx(m->lastc, t + occ);
	if (occ) { if (r->cls == TC_BLOCK) m->occ_blk += occ; else if (r->cls == TC_SYS) m->occ_sys += occ; else m->occ_mem += occ; }
	if (m->pcprof && r->pc >= text_lo && r->pc < text_hi) {
		size_t i = (r->pc - text_lo) >> 1;
		m->pc_n[i]++; m->pc_cyc[i] += m->lastc - prevlast; m->pc_fe[i] += fei; m->pc_ex[i] += exi;
	}

	/* ---- execute: walk the register and memory accesses in order.  ab: when the address registers are ready; db: when the data operands are; vt: when the loaded value is there */
	ab = db = t;
	m->stamp++;
	int ld0 = r->cls == TC_MOVE || r->cls == TC_CALL || r->cls == TC_RET;
	int base = oplat(c, r->cls), cls_tag = xtag_of(r->cls);
	if (r->cls == TC_BLOCK || r->cls == TC_SYS) {
		for (uint64_t b = r->wmask; b; b &= b - 1) { int x = __builtin_ctzll(b); m->loc[x] = t + cost; m->loctag[x] = XC_BLOCK; m->locst[x] = m->stamp; m->locA[x] = 0; }
		if (r->cls == TC_BLOCK) {	/* the data cache sees the first and last byte only; no miss penalty (documented) */
			for (int k = 0; k < r->n && c->dc; k++) if (r->ev[k].k == TM_EV_LD || r->ev[k].k == TM_EV_ST) { int64_t av; cache_access(&m->dc, r->ev[k].addr, t, 0, &av); }
		}
	} else {
		int nev = r->n;
		for (int k = 0; k < nev; k++) {
			const struct tm_ev *e = &r->ev[k];
			int x = e->r;
			switch (e->k) {
			case TM_EV_R:
				if (m->locst[x] == m->stamp) { db = mx(db, m->loc[x]); if (m->locA[x]) ab = mx(ab, m->loc[x]); }
				break;
			case TM_EV_LD: case TM_EV_ST: {
				int64_t lat = c->ld, av = ab;
				int miss = 0;
				if (c->dc) { miss = !cache_access(&m->dc, e->addr, ab, c->dmiss, &av); }
				if (e->k == TM_EV_LD) {
					if (av > ab) { lat += av - ab; }
					vt = ab + lat; seen = 1; missed = miss || av > ab;
				}
				break;
			}
			case TM_EV_W: {
				int64_t b0 = seen ? mx(db, vt) : db;
				int lat = (seen && ld0) ? 0 : base;
				m->loc[x] = b0 + lat; m->locA[x] = 0; m->locst[x] = m->stamp;
				m->loctag[x] = seen ? (missed ? XC_DMISS : XC_LOAD) : cls_tag;
				break;
			}
			case TM_EV_WA:
				m->loc[x] = mx(ab, t) + c->alu; m->locA[x] = 1; m->locst[x] = m->stamp; m->loctag[x] = XC_ALU;
				break;
			}
		}
	}
	for (uint64_t b = (r->wmask | 0); b; b &= b - 1) {
		int x = __builtin_ctzll(b);
		if (m->locst[x] != m->stamp) continue;
		if (x == 32) { if (m->loc[x] > m->ready[x]) { m->ready[x] = m->loc[x]; m->pcls[x] = m->loctag[x]; } }
		else { m->ready[x] = m->loc[x]; m->pcls[x] = m->loctag[x]; }
	}
	if (r->cls == TC_DIV) m->div_free = t + c->div;
	if (r->cls == TC_FDIV) m->fdiv_free = t + c->fdiv;

	/* ---- control transfers: prediction, and what the fetch unit does next */
	if (r->bk != BK_NONE || r->next != r->pc + r->len) {
		int taken = r->next != r->pc + r->len, ok = 1;
		int64_t resolve = (seen ? vt : t) + c->brlat;
		uint64_t idx;
		m->branches++;
		switch (r->bk) {
		case BK_COND: {
			int ptaken;
			m->cond++;
			idx = (r->pc >> 1) % c->bht;
			switch (c->pred) {
			case P_NONE: ptaken = 0; break;
			case P_TAKEN: ptaken = 1; break;
			case P_PERFECT: ptaken = taken; break;
			case P_STATIC: ptaken = r->back; break;
			default: ptaken = m->bht[idx] < 0 ? r->back : m->bht[idx] >= 2;
			}
			ok = ptaken == taken;
			if (c->pred == P_BIMODAL) {
				int v = m->bht[idx] < 0 ? (r->back ? 2 : 1) : m->bht[idx];
				v += taken ? (v < 3) : -(v > 0);
				m->bht[idx] = v;
			}
			break;
		}
		case BK_JMP_D: case BK_CALL_D: break;
		case BK_JMP_I: case BK_CALL_I: {
			m->ind_n++;
			idx = (r->pc >> 1) % c->ibtb;
			ok = c->pred == P_PERFECT || m->ib_tgt[idx] == r->next;
			if (!ok) m->ind_miss++;
			m->ib_tgt[idx] = r->next;
			break;
		}
		case BK_RET: {
			m->ret_n++;
			if (c->pred == P_PERFECT) ok = 1;
			else if (c->ras) { ok = m->ras_n && m->ras_st[m->ras_top] == r->next; if (m->ras_n) { m->ras_top = (m->ras_top + c->ras - 1) % c->ras; m->ras_n--; } }
			else { idx = (r->pc >> 1) % c->ibtb; ok = m->ib_tgt[idx] == r->next; m->ib_tgt[idx] = r->next; }
			if (!ok) m->ret_miss++;
			break;
		}
		}
		if (r->bk == BK_CALL_D || r->bk == BK_CALL_I) {
			if (c->ras) { m->ras_top = (m->ras_top + 1) % c->ras; m->ras_st[m->ras_top] = r->pc + r->len; if (m->ras_n < c->ras) m->ras_n++; }
		}
		if (!ok) {
			m->mispred++; m->newseg = 1; m->segcause = FC_MISP; m->R = resolve + c->mpx;
			if (taken) m->taken_n++;
		} else if (taken) {
			m->taken_n++;
			m->newseg = 1; m->segcause = FC_TAKEN;
			int hit = 0;
			if (c->btb) {
				idx = (r->pc >> 1) % c->btb;
				hit = m->btb_tag[idx] == r->pc && m->btb_tgt[idx] == r->next;
			}
			if (hit) { m->btb_hit++; m->R = m->wr[w1 & 31].req + 1; }
			else m->R = d + c->tkb;
		}
		if (c->btb && taken) { idx = (r->pc >> 1) % c->btb; m->btb_tag[idx] = r->pc; m->btb_tgt[idx] = r->next; }
	}
}

void tm_retire(struct tm_model **ms, int nm, uint64_t next_pc)
{
	tm_cur.next = next_pc;
	for (int i = 0; i < nm; i++) feed(ms[i], &tm_cur);
}

void tm_total_cycles(struct tm_model *m, uint64_t *cycles, uint64_t *insns) { *cycles = (uint64_t)(m->lastc + 1); *insns = m->insns; }

void tm_pcprof(struct tm_model *m)
{
	if (text_hi <= text_lo) return;
	size_t n = ((text_hi - text_lo) >> 1) + 1;
	m->pc_n = calloc(n, 4); m->pc_cyc = calloc(n, 8); m->pc_fe = calloc(n, 8); m->pc_ex = calloc(n, 8);
	m->pcprof = 1;
}

static const char *encname(int e) { return e == 2 ? "pdp64/32" : e == 1 ? "pdp64/16" : "pdp64/r20"; }
void tm_report(struct tm_model **ms, int nm, FILE *o, const char *prog)
{
	for (int i = 0; i < nm; i++) {
		struct tm_model *m = ms[i];
		uint64_t cycles = (uint64_t)(m->lastc + 1);
		fprintf(o, "tm name=%s prog=%s enc=%s insns=%llu bytes=%llu cycles=%llu ipc=%.4f bpc=%.3f cpi=%.4f active=%llu",
		    m->name, prog, encname(m->enc), (unsigned long long)m->insns, (unsigned long long)m->bytes, (unsigned long long)cycles,
		    cycles ? (double)m->insns / cycles : 0, cycles ? (double)m->bytes / cycles : 0, m->insns ? (double)cycles / m->insns : 0, (unsigned long long)m->active);
		uint64_t fe = 0, ex = 0;
		for (int k = 0; k < FC_N; k++) { fprintf(o, " fe_%s=%llu", FC_NAME[k], (unsigned long long)m->fe[k]); fe += m->fe[k]; }
		for (int k = 0; k < XC_N - 1; k++) { fprintf(o, " ex_%s=%llu", XC_NAME[k], (unsigned long long)m->ex[k]); ex += m->ex[k]; }
		fprintf(o, " occ_blk=%llu occ_sys=%llu occ_mem=%llu fe=%llu ex=%llu", (unsigned long long)m->occ_blk, (unsigned long long)m->occ_sys, (unsigned long long)m->occ_mem, (unsigned long long)fe, (unsigned long long)ex);
		fprintf(o, " branches=%llu cond=%llu taken=%llu mispred=%llu rets=%llu retmiss=%llu ind=%llu indmiss=%llu btbhit=%llu fused=%llu",
		    (unsigned long long)m->branches, (unsigned long long)m->cond, (unsigned long long)m->taken_n, (unsigned long long)m->mispred, (unsigned long long)m->ret_n,
		    (unsigned long long)m->ret_miss, (unsigned long long)m->ind_n, (unsigned long long)m->ind_miss, (unsigned long long)m->btb_hit, (unsigned long long)m->fused_n);
		if (m->c.ic) fprintf(o, " iacc=%llu imiss=%llu", (unsigned long long)m->ic.acc, (unsigned long long)m->ic.miss);
		if (m->c.dc) fprintf(o, " dacc=%llu dmiss=%llu", (unsigned long long)m->dc.acc, (unsigned long long)m->dc.miss);
		fprintf(o, "\n");
	}
}

/* per-pc profile of model m (the one with pcprof): "pc count cycles fe ex" */
void tm_pcdump(struct tm_model *m, FILE *o)
{
	if (!m->pcprof) return;
	fprintf(o, "#pc count cycles fe_idle ex_idle\n");
	size_t n = (text_hi - text_lo) >> 1;
	for (size_t i = 0; i < n; i++)
		if (m->pc_n[i]) fprintf(o, "%llx %u %llu %llu %llu\n", (unsigned long long)(text_lo + 2 * i), m->pc_n[i], (unsigned long long)m->pc_cyc[i], (unsigned long long)m->pc_fe[i], (unsigned long long)m->pc_ex[i]);
}
