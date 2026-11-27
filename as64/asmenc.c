/* asmenc.c: assembling the instruction encoding of the pdp64.  Included by as64.c, which owns the symbols, the expressions and the
 * passes; the bits come from the shared codec (common/pdp64enc.c) and its generated tables.  See spec/README.md.
 *
 * An instruction of the source becomes one or two instructions of the codec (an einsn: a mnemonic and operands of the shapes R, I, B, X, PI, PD, PC, A):
 *   - the operands are the operands as written, in the order written; the mnemonic is the word the grammar matched, with an alias replaced by the word it
 *     stands for (bhis is bcc, mulu is mul...); `jmp label` is br;
 *   - a cbCC for which no form reaches (a target beyond the long forms, an external label) is assembled as the opposite cbCC over a br to the target;
 * The length of an instruction is the length of the first form that takes its operands; it never shrinks between passes.
 */
#include <stdarg.h>
#include "pdp64enc.h"
#include "pdp64-mnnames.h"
#include "pdp64-extnames.h"
#include "pdp64-marks.h"

static struct etab *etab;
static int enc_stats;
static const char *enc_lens_path;
static FILE *enc_lens;
static long enc_ninsn, enc_nbytes, enc_nexpanded;

static const char *mn_canon[32][8192];			/* (group, number): the numbers of mn-ext go to 0x1000 + the word for an alias */
static const char *mn_word[32][8192];

static void enc_setup(void)
{
	etab = &enc_tab;
	enc_init(etab);
	for (unsigned i = 0; i < sizeof mnnames / sizeof *mnnames; i++) {
		mn_canon[mnnames[i].mg][mnnames[i].num] = mnnames[i].canon;
		mn_word[mnnames[i].mg][mnnames[i].num] = mnnames[i].name;
	}
	for (int i = 0; i < N_EXT_NAMES; i++) mn_canon[MG_EXT][i] = mn_word[MG_EXT][i] = ext_names[i];
	for (int i = 0; ext_alias[i].name; i++) { mn_word[MG_EXT][0x1000 + ext_alias[i].target] = ext_alias[i].name; mn_canon[MG_EXT][0x1000 + ext_alias[i].target] = ext_names[ext_alias[i].target]; }
}

static const char *stmt_canon(const struct stmt *st)
{
	if (st->mg == MG_SYSREG) return st->mnum == MN_SYSREG_MFSR ? "mfsr" : "mtsr";
	return mn_canon[st->mg][st->mnum];
}


/* ---- the width and kind suffixes ----------------------------------------------------------------------------------------------------------------------------------------------------
 * The width and kind of an operation is a dotted suffix of its mnemonic (`mov.s8 (r1), r2`, `aadd.s32 r1, (r2), r3`, `fadd.f32 r1, r2, r3`); the encoding has a word for each (movb, aaddl, fadd32).  The
 * rows of spec/grammars.d/61-asm-suffixes.hbnf (build/x/pdp64-marks.h) say which word each spelling is; the number of the mn-surface word the parser matched is the position of its row.  surface_resolve gives the
 * statement the word of the encoding and refuses what the spelling cannot mean. */
static int word_find(const char *name, int *mg, int *mnum)
{
	for (unsigned i = 0; i < sizeof mnnames / sizeof *mnnames; i++)
		if (!strcmp(mnnames[i].name, name)) { *mg = mnnames[i].mg; *mnum = mnnames[i].num; return 1; }
	for (int i = 0; i < N_EXT_NAMES; i++)
		if (!strcmp(ext_names[i], name)) { *mg = MG_EXT; *mnum = i; return 1; }
	for (int i = 0; ext_alias[i].name; i++)
		if (!strcmp(ext_alias[i].name, name)) { *mg = MG_EXT; *mnum = 0x1000 + ext_alias[i].target; return 1; }
	return 0;
}

static int is_memop(const struct oper *o) { return o->kind != OK_REG && o->kind != OK_IMM && o->kind != OK_POOL && o->kind != OK_VREG; }

/* The operands of fcvt (map-marks of 61-asm-suffixes.hbnf): the format of each operand is written on it, `fcvt r1.f16, r2.f32`, the source first and the destination last.  The pair of marks says which
   word of the encoding it is.  Returns 0 and the word of the statement, or -1 after an error. */
static int fcvt_resolve(struct stmt *st)
{
	char forms[900];
	fcvt_forms(forms, sizeof forms);
	int bad = st->nops != 2;
	for (int k = 0; k < st->nops && k < 2; k++)
		if (st->ops[k].kind != OK_REG || st->ops[k].mark == 0) bad = 1;
	if (bad) {
		int k = st->nops == 2 && st->ops[0].kind == OK_REG && st->ops[0].mark != 0 ? 1 : 0;
		if (st->nops == 2) err(st->line, "fcvt: operand %d has no format: a conversion names the format of both its operands, written directly after a register, the source first (`fcvt r1.f16, r2.f32`; a name such as buf.f32 is a symbol, not a mark); %s", k + 1, forms);
		else err(st->line, "fcvt: a conversion has two register operands, each with its format (`fcvt r1.f16, r2.f32`); %s", forms);
		return -1;
	}
	for (int k = 0; k < 2; k++)
		if (st->ops[k].mark < 0) {
			if (st->ops[k].marktext.n == 3 && !memcmp(st->ops[k].marktext.p, ".f8", 3))
				err(st->line, "fcvt: .f8 is no such format: there is no 8-bit floating-point format (the formats are .f16, .f32 and .f64)");
			else
				err(st->line, "fcvt: %.*s is no such format: the formats are .s8 .u8 .s16 .u16 .s32 .u32 .s64 .u64 .f16 .f32 .f64", st->ops[k].marktext.n, st->ops[k].marktext.p);
			return -1;
		}
	static const char *const fm[] = { "", "s8", "u8", "s16", "u16", "s32", "u32", "s64", "u64", "f16", "f32", "f64" };
	const char *a = fm[st->ops[0].mark], *b = fm[st->ops[1].mark];
	for (const struct markrow *r = mark_rows; r->word; r++)
		if (!strcmp(r->src, a) && !strcmp(r->dst, b)) {
			int mg, mn;
			if (!word_find(r->word, &mg, &mn)) { err(st->line, "internal error: the word %s of the conversions is not a word of the encoding", r->word); return -1; }
			st->mg = mg; st->mnum = mn;
			st->ops[0].mark = st->ops[1].mark = 0;
			return 0;
		}
	const char *hint = !strcmp(a, b) ? "the two formats are the same: a move copies it"
	    : a[0] != 'f' && b[0] != 'f' ? "both are integers: a move converts between them (mov.s32, mov.u16 ...)"
	    : a[0] == 'f' && b[0] == 'f' ? "there is no direct conversion between these floating-point formats: go through the single or the double (fcvt r1.f64, r2.f32 and then fcvt r1.f32, r2.f16, for instance)"
	    : "no instruction converts between these two: an integer that is not 32-bit signed or 64-bit is widened to 64 bits first (mov.s8, mov.s16, mov.u8, mov.u16, mov.u32 r1, r1) and then converted as a 64-bit integer with `fcvt r1.s64, r2.f64` (a register that holds a sign-extended 32-bit integer is already one), and a double goes to a single with `fcvt r1.f64, r2.f32`";
	err(st->line, "fcvt r1.%s, r2.%s: no such conversion: %s; %s", a, b, hint, forms);
	return -1;
}

/* The word of the encoding that a suffixed spelling is.  The statement is changed (the group and the number); -1 after an error. */
static int surface_resolve(struct stmt *st)
{
	if (st->kind != S_INSN) return 0;
	int marked = 0;
	for (int k = 0; k < st->nops; k++) if (st->ops[k].mark != 0) marked = 1;
	if (st->mg != MG_SURFACE) {
		if (marked) { err(st->line, "an operand takes no format mark here: the width is a suffix of the mnemonic (mov.s8 (r1), r2), and only fcvt, which has two formats, writes them on its operands (`fcvt r1.f16, r2.f32`)"); return -1; }
		return 0;
	}
	const struct surfrow *r = &surface_rows[st->mnum];
	if (strchr(r->flags, 'o')) return fcvt_resolve(st);
	if (marked) {
		if (!strncmp(r->spell, "fcvt", 4)) err(st->line, "%s: the short form takes no marks on its operands: write `%s Rs, Rd`, or the full form with a mark on each operand (`fcvt r1.%s, r2.f%s`); there is one way to write each", r->spell, r->spell,
		    r->spell + 5, !strcmp(r->spell + 5, "s32") ? "32" : "64");
		else err(st->line, "%s: an operand takes no format mark here: the width is a suffix of the mnemonic, and only fcvt, which has two formats, writes them on its operands", r->spell);
		return -1;
	}
	char w[40];
	snprintf(w, sizeof w, "%s", r->word);
	int mem = 0;
	for (int k = 0; k < st->nops; k++) if (is_memop(&st->ops[k])) mem = 1;
	if (strchr(r->flags, 's') && st->nops >= 1 && (st->ops[0].kind == OK_IMM || st->ops[0].kind == OK_POOL)) {
		err(st->line, "%s: a constant has no width: the move of a constant is the plain mov", r->spell);
		return -1;
	}
	if (strchr(r->flags, 'u') && !mem) {
		err(st->line, "%s: a user access needs a memory operand (a move between registers is not one)", r->spell);
		return -1;
	}
	if (strchr(r->flags, 'z') && st->nops == 2 && st->ops[0].kind == OK_REG && is_memop(&st->ops[1])) {		/* a store does not extend: the word that stores the same bits */
		snprintf(w, sizeof w, "mov%s", r->word + 4);
	}
	int mg, mn;
	if (!word_find(w, &mg, &mn)) { err(st->line, "internal error: the word %s of the suffixes is not a word of the encoding", w); return -1; }
	st->mg = mg; st->mnum = mn;
	return 0;
}

/* a check instruction: ct<cc>, cteq, ctne, chk2 (errata 152): each gets a record in the table of check sites */
static int is_check(const struct stmt *st)
{
	if (st->kind != S_INSN || st->mg != MG_EXT) return 0;
	const char *c = stmt_canon(st);
	return c && (!strcmp(c, "chk2") || (c[0] == 'c' && c[1] == 't' && c[2] != 0));
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

static int reg_limit(void) { return 32; }

/* an operand of the source as operand `dst` of the codec instruction.  addr is the address of the first parcel of the instruction it belongs to. */
static int econv(const struct stmt *st, int k, int dst, int64_t addr, int poolable, int isbranch, struct hw *h)
{
	const struct oper *o = &st->ops[k];
	struct eop *e = &h->in.op[dst];
	struct val v = vconst(0);

	memset(e, 0, sizeof *e);
	if (o->kind == OK_REG) { e->k = EK_R; e->r = o->reg; return 0; }
	if (o->kind == OK_VREG) { e->k = EK_V; e->s = 0; e->r = o->reg; return 0; }
	if (o->x) v = eval(o->x, st->line);
	switch (o->kind) {
	case OK_IMM: case OK_ABS:
		e->k = o->kind == OK_IMM ? EK_I : EK_A;
		if (CONST(v)) { e->v = v.c; return 0; }
		if (v.m >= 0) { err(st->line, "cannot subtract a symbol here"); return -1; }
		e->ext = 1;
		return take_rel(st, h, dst, v.p, v.c, 0);
	case OK_POOL: {
		if (!poolable) { err(st->line, "= is for 64-bit operations: a literal-pool load can be the source of mov, push or an ALU instruction; use #imm otherwise"); return -1; }
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
		if (o->kind == OK_BASED && !o->x) v = vconst(0);
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
		if (o->x) {
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
			if (report) err(st->line, "r%d: %s has registers r0 to r%d", bad, etab->name, lim - 1);
			return 0;
		}
	}
	return 1;
}

/* one instruction of an alias expansion: the mnemonic, then operands as pairs ('R', register) or ('I', value), ended by -1 */
static int aemit(const struct stmt *st, struct hw *h, const char *name, ...)
{
	va_list ap;
	int mn = enc_mn_find(etab, name);
	if (mn < 0) { err(st->line, "%s: this instruction does not exist in %s", name, etab->name); return 0; }
	hw_init(h, mn);
	va_start(ap, name);
	for (;;) {
		int k = va_arg(ap, int);
		if (k < 0) break;
		int v = va_arg(ap, int);
		struct eop *e = &h->in.op[h->in.nops++];
		memset(e, 0, sizeof *e);
		if (k == 'R') { e->k = EK_R; e->r = v; } else { e->k = EK_I; e->v = v; }
	}
	va_end(ap);
	return 1;
}

/* the instruction(s) of a statement.  Returns the number of codec instructions (1 to 5), or -1 after an error.  slot[] is 0 for a single instruction,
   2 and 3 for the two of an expanded cbCC (their lengths are remembered apart, so that a cbCC that changes its mind does not inherit a length). */
static int eplan(const struct stmt *src, int64_t pos, const int minn[8], struct hw hw[5], int slot[5])
{
	struct stmt rs = *src;
	const struct stmt *st = &rs;
	if (surface_resolve(&rs) < 0) return -1;
	const char *name = stmt_canon(st);
	int mg = st->mg, n = st->nops;

	if (!name) { err(st->line, "this instruction is not in the encoding %s", etab->name); return -1; }
	if (!regs_ok(st, 1)) return -1;
	int fcb = mg == MG_EXT && name[0] == 'f' && name[1] == 'c' && name[2] == 'b';		/* fcbCC, fcbCC32: floating-point compare and branch */
	int isbranch = mg == MG_BRANCH || mg == MG_CBRANCH || mg == MG_SOB || mg == MG_TAG || fcb;
	/* `jmp label` is `br label`: the same operation with the same reach, and br has the one-parcel form besides (docs/errata.md 214).  The other jmp operands (a register, memory, an absolute address) stay jmp. */
	if (mg == MG_SOP && st->mnum == MN_SOP_JMP && n == 1 && st->ops[0].kind == OK_BARE) { name = "br"; isbranch = 1; }
	/* fneg32 and fabs32 (sign operations on a binary32 held sign-extended in a register): `fneg32 Rs, Rd` is `xor #-2147483648, Rd`, `fabs32 Rs, Rd` is
	   `and #0x7FFFFFFF, Rd`, each after a `mov Rs, Rd` when the registers differ.  They write N and Z as the xor and the and do; the number of an alias is 0x100 plus its word's. */
	if (mg == MG_ALU && (st->mnum == 0x11C || st->mnum == 0x11D)) {
		int neg = st->mnum == 0x11C;
		const char *w = neg ? "fneg32" : "fabs32";
		if (n != 2 || st->ops[0].kind != OK_REG || st->ops[1].kind != OK_REG) { err(st->line, "%s Rs, Rd: two registers", w); return -1; }
		int mv = enc_mn_find(etab, "movq"), op = enc_mn_find(etab, name);
		if (mv < 0 || op < 0) { err(st->line, "%s: this instruction does not exist in %s", name, etab->name); return -1; }
		struct hw m, x;
		hw_init(&m, mv); hw_init(&x, op);
		m.in.nops = 2; m.in.op[0].k = EK_R; m.in.op[0].r = st->ops[0].reg; m.in.op[1].k = EK_R; m.in.op[1].r = st->ops[1].reg;
		x.in.nops = 2; x.in.op[0].k = EK_I; x.in.op[0].v = neg ? -2147483648LL : 0x7FFFFFFFLL; x.in.op[1].k = EK_R; x.in.op[1].r = st->ops[1].reg;
		slot[0] = 0; slot[1] = 0;
		if (st->ops[0].reg == st->ops[1].reg) {
			if (!hw_len(&x, minn[0])) return 1;
			hw[0] = x; return 1;
		}
		if (!hw_len(&m, minn[2]) || !hw_len(&x, minn[3])) return 1;
		hw[0] = m; hw[1] = x; slot[0] = 2; slot[1] = 3; return 2;
	}
	/* abs, min, minu, max, maxu are assembler aliases that expand to a fixed short sequence of existing instructions, with the register r12 as the one scratch register they may write (no flag exists, so
	   nothing else is touched).  abs Rs, Rd (signed; the most negative number stays itself):  movq Rs, r12 ; sar #63, r12 ; [movq Rs, Rd] ; xor r12, Rd ; sub r12, Rd.
	   min Ra, Rb, Rd and its three kin:  setCC Ra, Rb, r12 ; neg r12 ; bsel r12, Ra, Rb, Rd  with CC lt (min), cs (minu), gt (max) or hi (maxu): the all-ones mask of the comparison selects Ra, else Rb.  Every operand
	   is read before Rd is written, so Rd may be Ra or Rb and Ra may be Rb; r12 itself may not be an operand. */
	{
		const char *al = NULL;
		if (mg == MG_ALU && st->mnum == 0x122) al = "abs";
		else if (mg == MG_EXT && st->mnum >= 0x1000) al = mn_word[MG_EXT][st->mnum];
		if (al && (!strcmp(al, "abs") || !strcmp(al, "min") || !strcmp(al, "minu") || !strcmp(al, "max") || !strcmp(al, "maxu"))) {
			int isabs = !strcmp(al, "abs"), want = isabs ? 2 : 3;
			if (n != want) { err(st->line, isabs ? "abs Rs, Rd: two registers" : "%s Ra, Rb, Rd: three registers", al); return -1; }
			for (int k = 0; k < n; k++) if (st->ops[k].kind != OK_REG) { err(st->line, isabs ? "abs Rs, Rd: two registers" : "%s Ra, Rb, Rd: three registers", al); return -1; }
			for (int k = 0; k < n; k++) if (st->ops[k].reg == 12) { err(st->line, "%s: r12 is the assembler's scratch register for this word and cannot be an operand", al); return -1; }
			struct hw *h = hw; int nh = 0;
			static const int sl[5] = { 1, 4, 5, 6, 7 };
#define EMIT(...) do { if (!aemit(st, &h[nh], __VA_ARGS__, -1)) return -1; slot[nh] = sl[nh]; nh++; } while (0)
			if (isabs) {
				int rs = st->ops[0].reg, rd = st->ops[1].reg;
				EMIT("movq", 'R', rs, 'R', 12);
				EMIT("sar", 'I', 63, 'R', 12);
				if (rs != rd) EMIT("movq", 'R', rs, 'R', rd);
				EMIT("xor", 'R', 12, 'R', rd);
				EMIT("sub", 'R', 12, 'R', rd);
			} else {
				const char *cc = !strcmp(al, "min") ? "setlt" : !strcmp(al, "max") ? "setgt" : !strcmp(al, "minu") ? "setcs" : "sethi";
				int ra = st->ops[0].reg, rb = st->ops[1].reg, rd = st->ops[2].reg;
				EMIT(cc, 'R', ra, 'R', rb, 'R', 12);
				EMIT("neg", 'R', 12);
				EMIT("bsel", 'R', 12, 'R', ra, 'R', rb, 'R', rd);
			}
#undef EMIT
			return nh;
		}
	}
	/* rol is an assembler mapping onto ror: a rotate left by n is a rotate right by 64 - n, so `rol Rs, #n, Rd` is `ror Rs, #(64-n), Rd` and `rol #n, Rd` is `ror #(64-n), Rd`.  The machine has the one rotate and its count is
	   taken modulo 64, so a rotate left by a count in a register is not one instruction: rol takes a constant.  The count of either word is a constant from -64 to 63 (a negative count of ror rotates left, which is how the disassembler
	   prints the short form's counts), taken modulo 64 as the machine does.  The shortest form that holds it is used: the two-byte `ror #c, Rd` (a signed count of four bits, -8 to 7, for a register that is the source and
	   the destination and is r0 to r15), else `ror Rs, #c, Rd` (four bytes, the count 0 to 63). */
	if (mg == MG_BESC && (st->mnum == MN_BESC_ROR || st->mnum == MN_BESC_ROL)) {
		int rol = st->mnum == MN_BESC_ROL;
		int ci = n == 2 ? 0 : 1;
		int konst = (n == 2 || n == 3) && st->ops[ci].kind == OK_IMM;
		if (!konst && rol) { err(st->line, "rol takes a constant count: the machine's rotate is ror, whose count is taken modulo 64, so a rotate left by a register is ror by the negated register (neg it first)"); return -1; }
		if (konst) {
			const char *w = rol ? "rol" : "ror";
			int rs = n == 3 ? st->ops[0].reg : st->ops[1].reg, rd = st->ops[n - 1].reg;
			if ((n == 3 && (st->ops[0].kind != OK_REG || st->ops[2].kind != OK_REG)) || (n == 2 && st->ops[1].kind != OK_REG)) { err(st->line, "%s Rs, #n, Rd or %s #n, Rd: registers and a constant count", w, w); return -1; }
			struct val v = st->ops[ci].x ? eval(st->ops[ci].x, st->line) : vconst(0);
			if (!CONST(v)) { err(st->line, "%s takes a constant count", w); return -1; }
			if (v.c < -64 || v.c > 63) { err(st->line, "%s: the count is from -64 to 63", w); return -1; }
			int64_t c = (rol ? -v.c : v.c) & 63;
			int ro = enc_mn_find(etab, "ror");
			if (ro < 0) { err(st->line, "%s: this instruction does not exist in %s", w, etab->name); return -1; }
			struct hw r;
			hw_init(&r, ro);
			slot[0] = 0; slot[1] = 0;
			if (rs == rd) {								/* the register is both: the short form, if the count and the register fit it */
				r.in.nops = 2; r.in.op[0].k = EK_I; r.in.op[0].v = c >= 32 ? c - 64 : c; r.in.op[1].k = EK_R; r.in.op[1].r = rd;
				if (hw_len(&r, minn[0])) { hw[0] = r; return 1; }
			}
			hw_init(&r, ro);
			r.in.nops = 3; r.in.op[0].k = EK_R; r.in.op[0].r = rs; r.in.op[1].k = EK_I; r.in.op[1].v = c; r.in.op[2].k = EK_R; r.in.op[2].r = rd;
			hw[0] = r;
			return 1;
		}
	}
	int poolable = (mg == MG_MOV && st->mnum == MN_MOV_MOVQ) || (mg == MG_SOP && st->mnum == MN_SOP_PUSH) ||
	    (mg == MG_ALU && st->mnum != MN_ALU_SHL && st->mnum != MN_ALU_SHR && st->mnum != MN_ALU_SAR);
	int mn = enc_mn_find(etab, name);
	if (mn < 0) { err(st->line, "%s: this instruction does not exist in %s", name, etab->name); return -1; }
	hw_init(&hw[0], mn);
	slot[0] = 0; slot[1] = 0;
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
	{
		int dst = 0;
		for (int k = 0; k < n; k++) {
			if (econv(st, k, dst++, pos, poolable, isbranch, &hw[0]) < 0)
				return -1;
		}
		hw[0].in.nops = dst;
	}
	if ((!strcmp(name, "pushm") || !strcmp(name, "popm")) && (n != 1 || mask_fix(st, &hw[0].in.op[0]))) { if (n != 1) err(st->line, "pushm/popm take #mask"); return -1; }
	if (fcb) {									/* fcbgt and fcbge are fcblt and fcble with the two registers exchanged (a NaN makes both false, so the exchange is exact) */
		if (n != 3 || st->ops[0].kind != OK_REG || st->ops[1].kind != OK_REG) { err(st->line, "%s Ra, Rb, target: two registers and a label", mn_word[mg][st->mnum]); return -1; }
		if (st->mnum >= 0x1000) { struct eop tmp = hw[0].in.op[0]; hw[0].in.op[0] = hw[0].in.op[1]; hw[0].in.op[1] = tmp; }
	}
	if (hw_len(&hw[0], minn[0])) return 1;
	/* a cbCC no form reaches (a target beyond the long forms, an external label): the opposite condition branches over a br to the target; no flag is involved.  The linker is told not to move code in this object
	   (text_poison): the skip distance is a constant that a shrinking br would make wrong. */
	if (mg == MG_CBRANCH && n == 3) {
		static const char *inv[][2] = { { "cbeq", "cbne" }, { "cblt", "cbge" }, { "cbgt", "cble" }, { "cbcs", "cbcc" }, { "cbhi", "cblos" } };
		const char *iname = NULL;
		for (unsigned k = 0; k < sizeof inv / sizeof *inv; k++) {
			if (!strcmp(name, inv[k][0])) iname = inv[k][1];
			else if (!strcmp(name, inv[k][1])) iname = inv[k][0];
		}
		int im = iname ? enc_mn_find(etab, iname) : -1, bm = enc_mn_find(etab, "br");
		if (im >= 0 && bm >= 0) {
			struct hw c, b;
			int n1 = 2, n2 = 0;
			for (int round = 0; round < 4; round++) {
				hw_init(&b, bm);
				b.isbranch = 1; b.in.nops = 1;
				if (econv(st, 2, 0, pos + 2 * n1, 0, 1, &b) < 0) return -1;
				n2 = hw_len(&b, minn[3]);
				if (!n2) return 1;
				hw_init(&c, im);
				c.in.nops = 3; c.in.op[0] = hw[0].in.op[0]; c.in.op[1] = hw[0].in.op[1];
				c.in.op[2].k = EK_PC; c.in.op[2].v = 2 * (n1 + n2);
				int m1 = hw_len(&c, minn[2]);
				if (!m1) return 1;
				if (m1 == n1) { hw[0] = c; hw[1] = b; slot[0] = 2; slot[1] = 3; text_poison = 1; return 2; }
				n1 = m1;
			}
		}
	}
	return 1;		/* the caller finds that no form takes it */
}

/* the word as the source writes it: a word of the encoding that has a suffixed spelling is shown as that spelling */
static const char *shown_word(const char *w)
{
	for (const struct surfrow *r = surface_rows; r->spell; r++) if (r->shown && !strcmp(r->word, w)) return r->spell;
	return w;
}

/* a message for an instruction no form takes */
static void enc_nofit(const struct stmt *src, const struct hw *h)
{
	struct stmt rs = *src;
	const struct stmt *st = &rs;
	surface_resolve(&rs);		/* it resolved before: the word of the encoding says which group the statement is in */
	char shape[200] = "";
	static const char *kn[] = { "", "register", "immediate", "d(Rn)", "d(Rn)(Rx*s)", "(Rn)+", "-(Rn)", "pc-relative", "absolute", "vector register" };
	for (int k = 0; k < h->in.nops; k++) {
		const char *s = h->in.op[k].k < sizeof kn / sizeof *kn ? kn[h->in.op[k].k] : "operand";
		strcat(shape, k ? ", " : ""); strcat(shape, s);
	}
	if (st->mg == MG_ATOM) {
		int ll = (st->mnum & 31) == MN_ATOM_LL;
		err(st->line, "%s: an atomic is written `%s`: the address is a register in parentheses, with no offset, index or increment, and every other operand is a register (given: %s)",
		    shown_word(enc_mn_name(etab, h->in.mn)), ll ? "ll (Ra), Rd" : "OP Rs, (Ra), Rd", h->in.nops ? shape : "no operands");
		return;
	}
	err(st->line, "%s: no form of this instruction in %s takes %s%s (a meaningless combination, or a value out of range%s)", shown_word(enc_mn_name(etab, h->in.mn)), etab->name,
	    h->in.nops ? "these operands: " : "no operands", shape, enc_force ? "; .encode asks for a form of more parcels than any this instruction has" : "");
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
	if (ndefer == capdefer) { capdefer = capdefer ? capdefer * 2 : 1024; defer = realloc(defer, capdefer * sizeof *defer); }
	defer[ndefer].sym = k; defer[ndefer].sect = sect; defer[ndefer].val = val; ndefer++;
}
static void commit_syms(void)
{
	for (int i = 0; i < ndefer; i++) { syms[defer[i].sym].sect = defer[i].sect; syms[defer[i].sym].val = defer[i].val; }
	ndefer = 0;
}

/* ---- one statement in a pass ---------------------------------------------------------------------------------------- */
static uint8_t *egrow;			/* 8 per statement: the least number of parcels of each codec instruction slot, as relaxation has found */
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
	struct hw hw[5];
	int slot[5], total = 0, nb[5] = { 0 }, rk[5] = { 0 };
	uint8_t bytes[5][10];

	if (!esize) { egrow = calloc(nprog + 1, 8); esize = calloc(nprog + 1, sizeof *esize); epos = calloc(nprog + 1, sizeof *epos); }
	int64_t addr = epos[i];
	if (epos[i] != pos) { epos[i] = pos; *changed = 1; }
	int minn[8] = { egrow[8 * i] > enc_force ? egrow[8 * i] : enc_force, 0, egrow[8 * i + 2], egrow[8 * i + 3] };
	int nh = eplan(st, addr, minn, hw, slot);
	if (nh < 0) return esize[i] ? esize[i] : 2;				/* an error: the size it had, so that the others do not move */
	for (int h = 0; h < nh; h++) {
		int idx = 8 * i + slot[h], old = egrow[idx];
		int n = hw_emit(st, &hw[h], idx == 8 * i && enc_force > old ? enc_force : old, final, bytes[h], &rk[h]);
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
