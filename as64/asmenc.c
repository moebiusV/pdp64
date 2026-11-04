/* asmenc.c: assembling for the prefix-coded encodings (pdp64/16 and pdp64/32).  Included by as64.c, which owns the symbols, the expressions and the
 * passes; the bits come from the shared codec (common/pdp64enc.c) and its generated tables.  See spec/README.md.
 *
 * An instruction of the source becomes one or two instructions of the codec (an einsn: a mnemonic and operands of the shapes R, I, B, X, PI, PD, PC, A):
 *   - the operands are the operands as written, in the order written; the mnemonic is the word the grammar matched, with an alias replaced by the word it
 *     stands for (bhis is bcc, mulu is mul...);
 *   - a cbCC for which no form reaches (a far target, a wide immediate, an external label) is assembled as cmp + bCC (the flags are written);
 *   - `movq #imm, rd` whose constant fits no movq form is assembled as movql (a ten-byte instruction with the 64-bit immediate);
 * The length of an instruction is the length of the first form that takes its operands; as in the old encoding it never shrinks between passes.
 */
#include "pdp64enc.h"
#include "pdp64-mnnames.h"
#include "pdp64-extnames.h"

enum { ENC_OLD = 0, ENC_16 = 1, ENC_32 = 2 };		/* the value of e_flags & EF_PDP64_ENC (as64/relocs.h) */
static int enc_mode;
static struct etab *etab;
static int enc_stats;
static const char *enc_lens_path;
static FILE *enc_lens;
static long enc_ninsn, enc_nbytes, enc_nexpanded;

static const char *mn_canon[32][512];
static const char *mn_word[32][512];

static void enc_setup(int mode)
{
	enc_mode = mode;
	if (mode == ENC_OLD) return;
	etab = mode == ENC_16 ? &enc_tab_16 : &enc_tab_32;
	enc_init(etab);
	for (unsigned i = 0; i < sizeof mnnames / sizeof *mnnames; i++) {
		mn_canon[mnnames[i].mg][mnnames[i].num] = mnnames[i].canon;
		mn_word[mnnames[i].mg][mnnames[i].num] = mnnames[i].name;
	}
	for (int i = 0; i < N_EXT_NAMES; i++) mn_canon[MG_EXT][i] = mn_word[MG_EXT][i] = ext_names[i];
}

static const char *stmt_canon(const struct stmt *st)
{
	if (st->mg == MG_COND) return "set";
	if (st->mg == MG_SYSREG) return st->mnum == MN_SYSREG_MFSR ? "mfsr" : "mtsr";
	return mn_canon[st->mg][st->mnum];
}

/* one instruction of the codec with what its relocation, if it has one, needs */
struct hw {
	struct einsn in;
	int relop;			/* the operand with the unresolved value, or -1 */
	int relsym;
	int64_t reladd;
	int isbranch;
	int relocal;			/* relop is a symbol of this section (a relocation only for the linker's relaxation) */
};

/* The operand `dst` is the address of symbol sym (+add).  local: the symbol is in this section, its value is already in the operand.  An instruction has
   one relocation: a second symbol is an error if both are external; a local one that finds no room cannot be adjusted, and poisons .text (NOADJ_TEXT). */
static int take_rel(const struct stmt *st, struct hw *h, int dst, int sym, int64_t add, int local)
{
	if (local && !relax_on) return 0;
	if (h->relop >= 0) {
		if (local) { text_poison = 1; return 0; }
		if (!h->relocal) { err(st->line, "only one operand of an instruction can be a relocatable symbol"); return -1; }
		text_poison = 1;
	}
	h->relop = dst; h->relsym = sym; h->reladd = add; h->relocal = local;
	return 0;
}

static int reg_limit(void) { return enc_mode == ENC_32 ? 32 : 16; }

/* an operand of the source as operand `dst` of the codec instruction.  addr is the address of the first parcel of the instruction it belongs to. */
static int econv(const struct stmt *st, int k, int dst, int64_t addr, int poolable, int isbranch, struct hw *h)
{
	const struct oper *o = &st->ops[k];
	struct eop *e = &h->in.op[dst];
	struct val v = vconst(0);

	memset(e, 0, sizeof *e);
	if (o->kind == OK_REG) { e->k = EK_R; e->r = o->reg; return 0; }
	if (o->e.n) v = eval(o->e, st->line);
	switch (o->kind) {
	case OK_IMM: case OK_ABS:
		e->k = o->kind == OK_IMM ? EK_I : EK_A;
		if (CONST(v)) { e->v = v.c; return 0; }
		if (v.m >= 0) { err(st->line, "cannot subtract a symbol here"); return -1; }
		e->ext = 1;
		return take_rel(st, h, dst, v.p, v.c, 0);
	case OK_POOL: {
		if (!poolable) { err(st->line, "= is for 64-bit operations: a literal-pool load can be the source of movq, push or an ALU instruction; use #imm otherwise"); return -1; }
		if (!CONST(v)) { err(st->line, "a literal-pool load takes a constant: a relocatable symbol is not allowed in =expr"); return -1; }
		int ps = pool_get(v.c);
		e->k = EK_PC; e->v = pending(ps) ? 0 : syms[ps].val - addr;
		return take_rel(st, h, dst, ps, 0, 1);
	}
	case OK_BARE: case OK_BASED:
		if (o->kind == OK_BASED && o->special == 0) {
			if (!CONST(v)) { err(st->line, "a displacement from a register must be a constant"); return -1; }
			e->k = EK_B; e->r = o->reg; e->v = v.c;
			return 0;
		}
		if (o->kind == OK_BASED && o->special == BASESPEC_DP) {
			if (!CONST(v)) { err(st->line, "a displacement from DP must be a constant"); return -1; }
			e->k = EK_B; e->r = EBASE_DP; e->v = v.c;
			return 0;
		}
		if (o->kind == OK_BASED && o->e.n == 0) v = vconst(0);
		e->k = EK_PC;
		if (o->kind == OK_BARE || !CONST(v)) {
			if (CONST(v)) { err(st->line, "a bare number is not an address; write @n or #n"); return -1; }
			if (v.m >= 0) { err(st->line, "cannot subtract a symbol here"); return -1; }
			if (samesec(v.p) || pending(v.p)) {
				e->v = pending(v.p) ? 0 : syms[v.p].val + v.c - addr;
				if (isbranch && (e->v & 1)) { err(st->line, "branch to an odd address"); return -1; }
				return take_rel(st, h, dst, v.p, v.c, 1);
			} else {
				e->ext = 1;
				return take_rel(st, h, dst, v.p, v.c, 0);
			}
		} else { e->v = v.c; if (relax_on) text_poison = 1; }	/* d(pc) written as a number: a distance the linker cannot see */
		return 0;
	case OK_INDEXED:
		if (!CONST(v)) { err(st->line, "a displacement from a register must be a constant"); return -1; }
		e->k = EK_X; e->r = o->reg; e->x = o->reg2; e->s = (uint8_t)o->scale; e->v = v.c;
		return 0;
	case OK_POSTINC: case OK_PREDEC: case OK_PREDEC2:
		e->k = o->kind == OK_POSTINC ? EK_PI : EK_PD; e->r = o->reg;
		if (o->e.n) {
			if (!CONST(v)) { err(st->line, "a stride must be a constant"); return -1; }
			e->v = v.c;		/* 0, no stride written, is the instruction's own size (8 outside the moves) */
		}
		return 0;
	}
	err(st->line, "bad operand");
	return -1;
}

static void hw_init(struct hw *h, int mn)
{
	memset(h, 0, sizeof *h);
	h->in.mn = mn; h->relop = -1; h->relsym = -1;
}

/* the length in parcels of a codec instruction, at least minn; 0 if no form takes it */
static int hw_len(const struct hw *h, int minn)
{
	uint16_t par[5];
	return enc_encode_n(etab, &h->in, par, NULL, NULL, minn);
}

/* pushm, popm, popmret: the operand is a register mask; written as a signed number (a mask of r31 set is -2^31 and up) it is its low 32 bits.  Returns -1 after an error. */
static int mask_fix(const struct stmt *st, struct eop *e)
{
	if (e->k != EK_I || e->ext) { err(st->line, "pushm/popm take #mask"); return -1; }
	if (e->v < -((int64_t)1 << 31) || e->v >= ((int64_t)1 << 32)) { err(st->line, "register mask out of range"); return -1; }
	e->v &= 0xFFFFFFFF;
	if (enc_mode == ENC_16 && e->v > 0xFFFF) { err(st->line, "register mask out of range (%s has registers r0 to r15)", etab->name); return -1; }
	return 0;
}

/* registers beyond the encoding's */
static int regs_ok(const struct stmt *st, int report)
{
	int lim = reg_limit();
	for (int k = 0; k < st->nops; k++) {
		const struct oper *o = &st->ops[k];
		int bad = -1;
		if (o->kind == OK_REG && o->reg >= lim) bad = o->reg;
		else if ((o->kind == OK_BASED && o->special == 0 || o->kind == OK_INDEXED || o->kind == OK_POSTINC || o->kind == OK_PREDEC || o->kind == OK_PREDEC2) && o->reg >= lim) bad = o->reg;
		else if (o->kind == OK_INDEXED && o->reg2 >= lim) bad = o->reg2;
		if (bad >= 0) {
			if (report) err(st->line, "r%d: %s has registers r0 to r%d", bad, enc_mode ? etab->name : "this encoding", lim - 1);
			return 0;
		}
	}
	return 1;
}

/* the instruction(s) of a statement.  Returns the number of codec instructions (1 or 2), or -1 after an error.  slot[] is 0 for a single instruction,
   2 and 3 for the two of an expanded cbCC (their lengths are remembered apart, so that a cbCC that changes its mind does not inherit a length). */
static int eplan(const struct stmt *st, int64_t pos, const int minn[4], struct hw hw[2], int slot[2])
{
	const char *name = stmt_canon(st);
	int mg = st->mg, n = st->nops;

	if (!name) { err(st->line, "this instruction is not in the encoding %s", etab->name); return -1; }
	if (!regs_ok(st, 1)) return -1;
	int isbranch = mg == MG_BRANCH || mg == MG_CBRANCH || mg == MG_SOB || mg == MG_TAG;
	int poolable = (mg == MG_MOV && st->mnum == MN_MOV_MOVQ) || (mg == MG_SOP && st->mnum == MN_SOP_PUSH) ||
	    (mg == MG_ALU && st->mnum != MN_ALU_SHL && st->mnum != MN_ALU_SHR && st->mnum != MN_ALU_SAR);
	int mn = enc_mn_find(etab, name);
	if (mn < 0) { err(st->line, "%s: this instruction does not exist in %s", name, etab->name); return -1; }
	hw_init(&hw[0], mn);
	slot[0] = 0; slot[1] = 0;
	if (mg == MG_COND) {							/* set cc, rd */
		if (n != 1 || st->ops[0].kind != OK_REG) { err(st->line, "set cc, register"); return -1; }
		hw[0].in.nops = 2;
		hw[0].in.op[0].k = EK_I; hw[0].in.op[0].v = st->cc;
		return econv(st, 0, 1, pos, 0, 0, &hw[0]) < 0 ? -1 : 1;
	}
	if (mg == MG_SYSREG) {							/* mfsr rd, name / mtsr name, rs */
		int ismf = st->mnum == MN_SYSREG_MFSR, k = ismf ? 0 : 1;
		const char *form = ismf ? "mfsr register, name" : "mtsr name, register";
		if (st->srpos < 0 || n != 2) { err(st->line, "%s: expected a system register name and a register", form); return -1; }
		if (st->srpos != (ismf ? 1 : 0)) { err(st->line, "%s: the system register is the %s operand", form, ismf ? "second" : "first"); return -1; }
		if (st->ops[k].kind != OK_REG) { err(st->line, "%s: the %s operand must be a general register", form, ismf ? "first" : "second"); return -1; }
		if (!ismf && SYSREG_READONLY(st->srnum)) { err(st->line, "mtsr: this system register is read only"); return -1; }
		hw[0].in.nops = 2;
		hw[0].in.op[k].k = EK_R; hw[0].in.op[k].r = st->ops[k].reg;
		hw[0].in.op[st->srpos].k = EK_I; hw[0].in.op[st->srpos].v = st->srnum;
		return 1;
	}
	if (n > 4) { err(st->line, "too many operands"); return -1; }
	hw[0].isbranch = isbranch;
	hw[0].in.nops = n;
	for (int k = 0; k < n; k++)
		if (econv(st, k, k, pos, poolable, isbranch, &hw[0]) < 0) return -1;
	if ((!strcmp(name, "pushm") || !strcmp(name, "popm")) && (n != 1 || mask_fix(st, &hw[0].in.op[0]))) { if (n != 1) err(st->line, "pushm/popm take #mask"); return -1; }
	if (hw_len(&hw[0], minn[0])) return 1;
	/* movq #imm, rd with a constant of more than the forms of movq take: movql */
	if (!strcmp(name, "movq") && n == 2 && hw[0].in.op[0].k == EK_I && !hw[0].in.op[0].ext && hw[0].in.op[1].k == EK_R) {
		int ql = enc_mn_find(etab, "movql");
		if (ql >= 0) { struct hw q = hw[0]; q.in.mn = ql; if (hw_len(&q, minn[0])) { hw[0] = q; return 1; } }
	}
	/* a cbCC no form reaches: cmp, then the branch */
	if (mg == MG_CBRANCH && n == 3) {
		char bn[16];
		snprintf(bn, sizeof bn, "b%s", name + 2);
		int cm = enc_mn_find(etab, "cmp"), bm = enc_mn_find(etab, bn);
		if (cm >= 0 && bm >= 0) {
			struct hw c, b;
			hw_init(&c, cm); hw_init(&b, bm);
			c.in.nops = 2; c.in.op[0] = hw[0].in.op[0]; c.in.op[1] = hw[0].in.op[1];
			int n1 = hw_len(&c, minn[2]);
			if (n1) {
				b.isbranch = 1; b.in.nops = 1;
				if (econv(st, 2, 0, pos + 2 * n1, 0, 1, &b) < 0) return -1;
				if (hw_len(&b, minn[3])) { hw[0] = c; hw[1] = b; slot[0] = 2; slot[1] = 3; return 2; }
			}
		}
	}
	return 1;		/* the caller finds that no form takes it */
}

/* a message for an instruction no form takes */
static void enc_nofit(const struct stmt *st, const struct hw *h)
{
	char shape[200] = "";
	static const char *kn[] = { "", "register", "immediate", "d(Rn)", "d(Rn)(Rx*s)", "(Rn)+", "-(Rn)", "pc-relative", "absolute" };
	for (int k = 0; k < h->in.nops; k++) { strcat(shape, k ? ", " : ""); strcat(shape, kn[h->in.op[k].k]); }
	err(st->line, "%s: no form of this instruction in %s takes %s%s (a meaningless combination, or a value out of range)", enc_mn_name(etab, h->in.mn), etab->name,
	    h->in.nops ? "these operands: " : "no operands", shape);
}

/* encode one codec instruction: parcels to bytes, the relocation record.  Returns the parcels (0: no form; the message is given in the final pass). */
static int hw_emit(const struct stmt *st, struct hw *h, int minn, int final, uint8_t *bytes, int *relkind)
{
	uint16_t par[5];
	int n = enc_encode_n(etab, &h->in, par, NULL, NULL, minn);
	*relkind = 0;
	if (!n) { enc_nofit(st, h); return 0; }
	for (int i = 0; i < n; i++) enc_st16(bytes + 2 * i, par[i]);
	if (final && h->relop >= 0) {
		struct efield f;
		int want = h->in.op[h->relop].k == EK_PC ? ES_PC : ES_A;
		if (enc_reloc_field(etab, par, n, want, &f)) { err(st->line, "internal error: no field for the relocation"); return 0; }
		if (h->relocal && f.oi != h->relop) { text_poison = 1; return n; }	/* the linker would patch another operand: no relocation, no relaxation */
		*relkind = want == ES_PC ? (f.unit == 2 ? R_PDP64_INSN_BR : R_PDP64_INSN_PC) : R_PDP64_INSN_ABS;
	}
	return n;
}

/* Relaxation measures every distance on the layout of the pass before, for the labels as for the instructions (the iteration of the model: all positions
   from the lengths at the start of the pass).  So a label defined in a pass takes its value when the pass ends. */
static struct { int sym, sect; int64_t val; } *defer;
static int ndefer, capdefer;
static void set_sym_val(int k, int sect, int64_t val)
{
	if (!enc_mode) { syms[k].sect = sect; syms[k].val = val; return; }
	if (ndefer == capdefer) { capdefer = capdefer ? capdefer * 2 : 1024; defer = realloc(defer, capdefer * sizeof *defer); }
	defer[ndefer].sym = k; defer[ndefer].sect = sect; defer[ndefer].val = val; ndefer++;
}
static void commit_syms(void)
{
	for (int i = 0; i < ndefer; i++) { syms[defer[i].sym].sect = defer[i].sect; syms[defer[i].sym].val = defer[i].val; }
	ndefer = 0;
}

/* ---- one statement in a pass ---------------------------------------------------------------------------------------- */
static uint8_t *egrow;			/* 4 per statement: the least number of parcels of each codec instruction slot, as relaxation has found */
static int32_t *esize;			/* bytes the statement took in the last pass */
static int64_t *epos;			/* where the statement was in the last pass: relaxation measures every distance on the layout of the pass before (as the model does) */

static void enc_note(const struct stmt *st, int n, int64_t off)
{
	enc_ninsn++;
	if (enc_lens) fprintf(enc_lens, "%d %d %lld\n", st->line, n, (long long)off);
}

/* the bytes of statement i at pos, in a pass; returns the size in bytes.  *changed is set if a length or a size differs from the last pass. */
static int enc_insn(int i, int64_t pos, int final, int *changed)
{
	struct stmt *st = &prog[i];
	struct hw hw[2];
	int slot[2], total = 0, nb[2] = { 0, 0 }, rk[2] = { 0, 0 };
	uint8_t bytes[2][10];

	if (!esize) { egrow = calloc(nprog + 1, 4); esize = calloc(nprog + 1, sizeof *esize); epos = calloc(nprog + 1, sizeof *epos); }
	int64_t addr = epos[i];
	if (epos[i] != pos) { epos[i] = pos; *changed = 1; }
	int minn[4] = { egrow[4 * i], 0, egrow[4 * i + 2], egrow[4 * i + 3] };
	int nh = eplan(st, addr, minn, hw, slot);
	if (nh < 0) return esize[i] ? esize[i] : 2;				/* an error: the size it had, so that the others do not move */
	for (int h = 0; h < nh; h++) {
		int idx = 4 * i + slot[h], old = egrow[idx];
		int n = hw_emit(st, &hw[h], old, final, bytes[h], &rk[h]);
		if (!n) return esize[i] ? esize[i] : 2;
		if (n > old) { egrow[idx] = n; *changed = 1; if (final) { err(st->line, "internal error: relaxation did not converge"); return 0; } }
		nb[h] = 2 * n; total += 2 * n;
	}
	if (final) {
		int off = 0;
		if (pos & 1) { err(st->line, "an instruction at an odd address (%lld): put .even before it", (long long)pos); return 0; }
		if (cur_sec == SEC_BSS) { err(st->line, "an instruction in .bss"); return 0; }
		for (int h = 0; h < nh; h++) {
			if (hw[h].relop >= 0) addreloc(cur_sec, (int64_t)sec[cur_sec].n + off, rk[h], hw[h].relsym, hw[h].reladd);
			off += nb[h];
		}
		for (int h = 0; h < nh; h++) { enc_note(st, nb[h] / 2, (int64_t)sec[cur_sec].n); emit_bytes_n(bytes[h], nb[h]); }
		enc_nbytes += total;
		if (nh == 2) enc_nexpanded++;
	}
	if (esize[i] != total) { esize[i] = total; *changed = 1; }
	return total;
}

/* a one-parcel SYS instruction with no operand (nop, lpad) */
static void enc_sys0(const char *name)
{
	struct einsn in;
	uint16_t par[5];
	uint8_t b[2];
	memset(&in, 0, sizeof in);
	in.mn = enc_mn_find(etab, name);
	if (in.mn < 0 || enc_encode(etab, &in, par, NULL, NULL) != 1) { fprintf(stderr, "%s: internal error: cannot encode %s\n", progname, name); exit(2); }
	enc_st16(b, par[0]);
	emit_bytes_n(b, 2);
}
