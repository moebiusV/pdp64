/* as64: the pdp64 assembler.
 *
 * The grammar does the reading (asmp.c: spec/pdp64-asm.hbnf), the grammar does the encoding of instruction bits (fmtp.c:
 * spec/pdp64.hbnf) and of the object file records (elf.hbnf, included below).  What is left, and is here, is what no
 * grammar says: symbols and expressions, choosing the length of each instruction, and which fields need a relocation.
 *
 * Addresses, lengths and relocations (docs/errata.md 3, docs/elf-pdp64.md):
 *   - a PC-relative displacement, and a branch displacement, count from the first parcel of the instruction;
 *   - branches count in 2-byte parcels, `d(PC)` in bytes;
 *   - an instruction grows (len 0..3) until its displacement or immediate fits; it never shrinks, so the loop ends;
 *   - a reference to a symbol of another section, or to an undefined one, is a 32-bit field with a relocation.
 */
#include <ctype.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "asmir.h"
#include "fmt.h"
#include "elf-parser.c"
#include "relocs.h"
#include "pdp64-consts.h"

/* ------------------------------------------------------------------------------------------------------------------ */
/* symbols and values                                                                                                  */

enum { SEC_TEXT, SEC_DATA, SEC_BSS, NSEC };
enum { SC_UNDEF = -1, SC_PENDING = -2, SC_ABS = 3, SC_COMMON = 4 };	/* sym.sect besides 0..NSEC-1 */

struct sym {
	char *name;
	int sect;		/* section number, or one of SC_* */
	int64_t val;		/* offset in its section; the value if SC_ABS; the size if SC_COMMON */
	int global, assigned;
	int islocal;		/* a numeric label's definition: never in the symbol table, relocs use the section */
	int outidx;
};
static struct sym *syms;
static int nsyms, capsyms;

static const char *progname = "as64", *srcname;
static int errors, final_pass;
static void err(int line, const char *fmt, ...)
{
	va_list ap;
	if (!final_pass) return;			/* the earlier passes only measure; the last one reports */
	fprintf(stderr, "%s:%d: ", srcname, line);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
	errors++;
}

/* a numeric local label is a name of digits only */
static int all_digits(const char *p, int n)
{
	if (n <= 0) return 0;
	for (int i = 0; i < n; i++) if (p[i] < '0' || p[i] > '9') return 0;
	return 1;
}

static int symfind(const char *p, int n)
{
	for (int i = 0; i < nsyms; i++)
		if (!syms[i].islocal && (int)strlen(syms[i].name) == n && memcmp(syms[i].name, p, n) == 0)
			return i;
	return -1;
}
static int symadd(const char *p, int n)
{
	if (nsyms == capsyms) {
		capsyms = capsyms ? capsyms * 2 : 256;
		syms = realloc(syms, capsyms * sizeof *syms);
	}
	memset(&syms[nsyms], 0, sizeof syms[nsyms]);
	syms[nsyms].name = malloc(n + 1);
	memcpy(syms[nsyms].name, p, n);
	syms[nsyms].name[n] = 0;
	syms[nsyms].sect = SC_UNDEF;
	syms[nsyms].outidx = -1;
	return nsyms++;
}
static int symget(const char *p, int n)
{
	if (n >= 2 && p[0] == '"') { p++; n -= 2; }			/* a quoted name: ELF takes any bytes */
	int i = symfind(p, n);
	return i >= 0 ? i : symadd(p, n);
}

/* a value: constant + one positive symbol - one negative symbol */
struct val { int64_t c; int p, m; };
#define CONST(v) ((v).p < 0 && (v).m < 0)

/* numeric local labels: definitions in statement order */
struct lloc { int num, stmt, sym; };
static struct lloc *lloc;
static int nlloc, caplloc;

static struct stmt *prog;
static int nprog;

/* the state of the pass in progress */
static int cur_sec, cur_stmt;
static int64_t offs[NSEC];

/* ------------------------------------------------------------------------------------------------------------------ */
/* expressions                                                                                                         */

/* UTF-8: the grammar has already refused anything invalid, so these only translate */
static int utf8_decode(const char **pp, const char *e)
{
	const unsigned char *p = (const unsigned char *)*pp;
	int cp, n;
	if (p[0] < 0x80) { *pp += 1; return p[0]; }
	n = p[0] >= 0xF0 ? 3 : p[0] >= 0xE0 ? 2 : 1;
	cp = p[0] & (0x3F >> n);
	for (int i = 1; i <= n && *pp + i < e + 1; i++) cp = (cp << 6) | (p[i] & 0x3F);
	*pp += n + 1;
	return cp;
}
static int utf8_put(int cp, uint8_t *o)
{
	if (cp < 0x80) { o[0] = cp; return 1; }
	if (cp < 0x800) { o[0] = 0xC0 | (cp >> 6); o[1] = 0x80 | (cp & 63); return 2; }
	if (cp < 0x10000) { o[0] = 0xE0 | (cp >> 12); o[1] = 0x80 | ((cp >> 6) & 63); o[2] = 0x80 | (cp & 63); return 3; }
	o[0] = 0xF0 | (cp >> 18); o[1] = 0x80 | ((cp >> 12) & 63); o[2] = 0x80 | ((cp >> 6) & 63); o[3] = 0x80 | (cp & 63);
	return 4;
}

/* one character of a C string or character literal at *pp, with its escape if it has one.  *iscp is set when the value is
   a code point to be written as UTF-8 (\u, \U), and clear when it is a byte (\x, octal, and every plain character). */
static int c_char(const char **pp, const char *e, int *iscp)
{
	const char *p = *pp;
	int v;
	*iscp = 0;
	if (*p != '\\' || p + 1 >= e) { *pp = p + 1; return (unsigned char)*p; }
	p++;
	switch (*p) {
	case 'n': v = 10; p++; break;
	case 't': v = 9; p++; break;
	case 'r': v = 13; p++; break;
	case 'a': v = 7; p++; break;
	case 'b': v = 8; p++; break;
	case 'f': v = 12; p++; break;
	case 'v': v = 11; p++; break;
	case 'x': {
		v = 0; p++;
		for (int k = 0; k < 2 && p < e && isxdigit((unsigned char)*p); k++, p++)
			v = v * 16 + (isdigit((unsigned char)*p) ? *p - '0' : tolower((unsigned char)*p) - 'a' + 10);
		break;
	}
	case 'u': case 'U': {
		int digits = *p == 'u' ? 4 : 8;
		v = 0; p++;
		for (int k = 0; k < digits && p < e && isxdigit((unsigned char)*p); k++, p++)
			v = v * 16 + (isdigit((unsigned char)*p) ? *p - '0' : tolower((unsigned char)*p) - 'a' + 10);
		*iscp = 1;
		break;
	}
	default:
		if (*p >= '0' && *p <= '7') {
			v = 0;
			for (int k = 0; k < 3 && p < e && *p >= '0' && *p <= '7'; k++, p++) v = v * 8 + (*p - '0');
			v &= 255;
		} else { v = (unsigned char)*p; p++; }
	}
	*pp = p;
	return v;
}

struct ex { const char *p, *e; int line, bad; };

static void skipws(struct ex *x) { while (x->p < x->e && (*x->p == ' ' || *x->p == '\t')) x->p++; }
static struct val eval_expr(struct ex *x);

static int dot_sym = -1;

static struct val vconst(int64_t c) { struct val v = { c, -1, -1 }; return v; }

static struct val eval_primary(struct ex *x)
{
	skipws(x);
	if (x->p >= x->e) { x->bad = 1; return vconst(0); }
	char c = *x->p;
	if (c == '(') {
		x->p++;
		struct val v = eval_expr(x);
		skipws(x);
		if (x->p < x->e && *x->p == ')') x->p++; else x->bad = 1;
		return v;
	}
	if (c == '\'') {					/* 'c' */
		x->p++;
		int64_t v = 0; int iscp;
		if (x->p < x->e) v = (unsigned char)*x->p >= 0x80 ? utf8_decode(&x->p, x->e) : c_char(&x->p, x->e, &iscp);
		if (x->p < x->e && *x->p == '\'') x->p++;
		return vconst(v);
	}
	if (isdigit((unsigned char)c)) {
		const char *s = x->p, *q = s;
		while (q < x->e && (isalnum((unsigned char)*q) || *q == '_' || *q == '.' || *q == '$' || (unsigned char)*q >= 0x80)) q++;
		int n = (int)(q - s);
		int base = 10, first = 0, ok = 1;
		if (n > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; first = 2; }
		else if (n > 2 && s[0] == '0' && (s[1] == 'b' || s[1] == 'B')) { base = 2; first = 2; }
		else if (n > 2 && s[0] == '0' && (s[1] == 'o' || s[1] == 'O')) { base = 8; first = 2; }
		uint64_t num = 0;
		for (int i = first; i < n && ok; i++) {
			int dv = isdigit((unsigned char)s[i]) ? s[i] - '0' : isalpha((unsigned char)s[i]) ? tolower((unsigned char)s[i]) - 'a' + 10 : 99;
			if (dv >= base) ok = 0; else num = num * base + dv;
		}
		if (ok) {					/* a whole bareword that is a number */
			x->p = q;
			return vconst((int64_t)num);
		}
		if (n >= 2 && (q[-1] == 'f' || q[-1] == 'b') && all_digits(s, n - 1)) {		/* 1f, 1b: a local label */
			int num = 0;
			for (const char *d = s; d < q - 1; d++) num = num * 10 + (*d - '0');
			int fwd = q[-1] == 'f', best = -1;
			for (int i = 0; i < nlloc; i++) {
				if (lloc[i].num != num) continue;
				if (fwd ? lloc[i].stmt > cur_stmt : lloc[i].stmt <= cur_stmt)
					if (best < 0 || (fwd ? lloc[i].stmt < lloc[best].stmt : lloc[i].stmt > lloc[best].stmt)) best = i;
			}
			x->p = q;
			if (best < 0) { err(x->line, "undefined local label %.*s", n, s); x->bad = 1; return vconst(0); }
			struct val v = { 0, lloc[best].sym, -1 };
			return v;
		}
		x->p = q;					/* neither: a name that starts with a digit */
		struct val v = { 0, symget(s, n), -1 };
		return v;
	}
	if (isalpha((unsigned char)c) || c == '_' || c == '.' || (unsigned char)c >= 0x80 || c == '"') {
		const char *s = x->p;
		if (c == '"') { x->p++; while (x->p < x->e && *x->p != '"') x->p++; if (x->p < x->e) x->p++; }
		else while (x->p < x->e && (isalnum((unsigned char)*x->p) || *x->p == '_' || *x->p == '.' || *x->p == '$' || (unsigned char)*x->p >= 0x80)) x->p++;
		int n = (int)(x->p - s);
		if (n == 1 && s[0] == '.') {
			struct val v = { 0, dot_sym, -1 };
			return v;
		}
		struct val v = { 0, symget(s, n), -1 };
		return v;
	}
	x->bad = 1;
	return vconst(0);
}

/* resolve a symbol that is an assignment (an alias) or an absolute */
static struct val deref(struct val v)
{
	for (int guard = 0; guard < 8; guard++) {
		int changed = 0;
		if (v.p >= 0 && syms[v.p].sect == SC_ABS) { v.c += syms[v.p].val; v.p = -1; changed = 1; }
		if (v.m >= 0 && syms[v.m].sect == SC_ABS) { v.c -= syms[v.m].val; v.m = -1; changed = 1; }
		if (!changed) break;
	}
	if (v.p >= 0 && v.m >= 0 && syms[v.p].sect == syms[v.m].sect && syms[v.p].sect >= 0) {
		v.c += syms[v.p].val - syms[v.m].val;
		v.p = v.m = -1;
	}
	return v;
}

static struct val eval_unary(struct ex *x)
{
	skipws(x);
	if (x->p < x->e && (*x->p == '-' || *x->p == '~' || *x->p == '!')) {
		char op = *x->p++;
		struct val v = deref(eval_unary(x));
		if (!CONST(v)) {
			if (op == '-' && v.m < 0) { struct val r = { -v.c, -1, v.p }; return r; }
			if (op == '-' && v.p < 0) { struct val r = { -v.c, v.m, -1 }; return r; }
			x->bad = 1;
			return vconst(0);
		}
		return vconst(op == '-' ? -v.c : op == '~' ? ~v.c : !v.c);
	}
	return eval_primary(x);
}

static struct val eval_term(struct ex *x)
{
	struct val a = eval_unary(x);
	for (;;) {
		skipws(x);
		if (x->p >= x->e) break;
		char op = *x->p;
		int two = x->p + 1 < x->e && x->p[1] == op;
		if (!((op == '*' || op == '/' || op == '%' || op == '&') || ((op == '<' || op == '>') && two))) break;
		x->p += (op == '<' || op == '>') ? 2 : 1;
		struct val b = deref(eval_unary(x)); a = deref(a);
		if (!CONST(a) || !CONST(b)) { x->bad = 1; return vconst(0); }
		switch (op) {
		case '*': a.c *= b.c; break;
		case '/': if (b.c) a.c /= b.c; else { x->bad = 1; } break;
		case '%': if (b.c) a.c %= b.c; else { x->bad = 1; } break;
		case '&': a.c &= b.c; break;
		case '<': a.c = (int64_t)((uint64_t)a.c << (b.c & 63)); break;
		case '>': a.c = a.c >> (b.c & 63); break;
		}
	}
	return a;
}

static struct val eval_expr(struct ex *x)
{
	struct val a = eval_term(x);
	for (;;) {
		skipws(x);
		if (x->p >= x->e) break;
		char op = *x->p;
		if (op != '+' && op != '-' && op != '|' && op != '^') break;
		x->p++;
		struct val b = eval_term(x);
		a = deref(a); b = deref(b);
		if (op == '+') {
			if (a.p >= 0 && b.p >= 0) { x->bad = 1; return vconst(0); }
			if (a.m >= 0 && b.m >= 0) { x->bad = 1; return vconst(0); }
			a.c += b.c;
			if (b.p >= 0) a.p = b.p;
			if (b.m >= 0) a.m = b.m;
		} else if (op == '-') {
			if ((b.p >= 0 && a.m >= 0) || (b.m >= 0 && a.p >= 0 && 0)) { x->bad = 1; return vconst(0); }
			a.c -= b.c;
			if (b.p >= 0) { if (a.m >= 0) { x->bad = 1; return vconst(0); } a.m = b.p; }
			if (b.m >= 0) { if (a.p >= 0) { x->bad = 1; return vconst(0); } a.p = b.m; }
		} else {
			if (!CONST(a) || !CONST(b)) { x->bad = 1; return vconst(0); }
			a.c = op == '|' ? (a.c | b.c) : (a.c ^ b.c);
		}
		a = deref(a);
	}
	return a;
}

/* evaluate a slice; a bad expression is reported once, only in the final pass */
static struct val eval(struct slice s, int line)
{
	struct ex x = { s.p, s.p + s.n, line, 0 };
	struct val v = eval_expr(&x);
	skipws(&x);
	if (x.bad || x.p != x.e) {
		if (final_pass) err(line, "bad expression %.*s", s.n, s.p);
		return vconst(0);
	}
	return deref(v);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* output sections and relocations                                                                                     */

struct bytes { uint8_t *p; size_t n, cap; };
static struct bytes sec[NSEC];

struct reloc { int sect; int64_t off; int type; int sym; int64_t addend; };
static struct reloc *relocs;
static int nrelocs, caprelocs;

static void emit_bytes_n(const uint8_t *b, size_t n)
{
	struct bytes *s = &sec[cur_sec];
	if (s->n + n > s->cap) {
		s->cap = (s->n + n) * 2 + 256;
		s->p = realloc(s->p, s->cap);
	}
	memcpy(s->p + s->n, b, n);
	s->n += n;
}
static void addreloc(int sect, int64_t off, int type, int sym, int64_t addend)
{
	if (nrelocs == caprelocs) {
		caprelocs = caprelocs ? caprelocs * 2 : 64;
		relocs = realloc(relocs, caprelocs * sizeof *relocs);
	}
	relocs[nrelocs++] = (struct reloc){ sect, off, type, sym, addend };
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* instructions                                                                                                        */

static int fits(int64_t v, int bits) { return bits >= 64 || (v >= -((int64_t)1 << (bits - 1)) && v < ((int64_t)1 << (bits - 1))); }
static uint64_t mask(int bits) { return bits >= 64 ? ~(uint64_t)0 : (((uint64_t)1 << bits) - 1); }

/* ---- what the grammar says about the formats, learned by asking its generated writer ------------------------------------
 * The widths of the displacement fields, which addressing mode uses which shape, and the size of the reg and low nibbles are
 * written once, in spec/pdp64.hbnf.in.  Nothing here repeats them: the writer refuses a value that does not fit, so the
 * widths are found by encoding all-ones values until it refuses, once at startup. */
static int fieldbits[16][4];		/* [shape][len]: bits of the displacement field, 0 if the shape does not exist at that len */
static int mode_shape[16];		/* addressing mode -> shape, 0 if no shape takes it */
static int maxlen = 3;
static int regbits, lowbits;

static int try_enc(const struct fmt *f) { uint8_t b[8]; size_t n; return fmt_encode(f, b, &n) == 0; }

static void calibrate(void)
{
	static const int shapes[] = { FS_BASE, FS_INDEX, FS_DP, FS_WIDE, FS_D };
	struct fmt f;

	for (maxlen = 0; maxlen < 8; maxlen++) {
		memset(&f, 0, sizeof f); f.shape = FS_D; f.opc = MN_BRANCH_BR; f.len = maxlen + 1;
		if (!try_enc(&f)) break;
	}
	for (regbits = 0; regbits < 16; regbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_MEM0; f.opc = MN_MOV_MOVQ; f.reg = (int)mask(regbits + 1);
		if (!try_enc(&f)) break;
	}
	for (lowbits = 0; lowbits < 16; lowbits++) {
		memset(&f, 0, sizeof f); f.shape = FS_MEM0; f.opc = MN_MOV_MOVQ; f.low = (int)mask(lowbits + 1);
		if (!try_enc(&f)) break;
	}
	for (int m = 0; m < (1 << lowbits); m++)
		for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++) {
			memset(&f, 0, sizeof f); f.len = 1; f.opc = MN_MOV_MOVQ; f.low = m; f.shape = shapes[k];
			if (shapes[k] == FS_D) continue;
			if (try_enc(&f)) { mode_shape[m] = shapes[k]; break; }
		}
	for (unsigned k = 0; k < sizeof shapes / sizeof *shapes; k++)
		for (int len = 1; len <= maxlen; len++) {
			int mode = -1;
			memset(&f, 0, sizeof f); f.len = len; f.shape = shapes[k];
			if (shapes[k] == FS_D) f.opc = MN_BRANCH_BR;
			else {
				f.opc = MN_MOV_MOVQ;
				for (int m = 0; m < (1 << lowbits); m++) if (mode_shape[m] == shapes[k]) { mode = m; break; }
				if (mode < 0) continue;
				f.low = mode;
			}
			int w = 0;
			while (w < 64) {
				f.d = mask(w + 1);
				if (!try_enc(&f)) break;
				w++;
			}
			fieldbits[shapes[k]][len] = w;
		}
}

static int dispbits(int mode, int len) { return fieldbits[mode_shape[mode]][len]; }
static int branchbits(int len) { return fieldbits[FS_D][len]; }

/* the symbol whose offset is in this section and known: same-section target */
static int samesec(int s) { return s >= 0 && syms[s].sect == cur_sec; }
static int pending(int s) { return s >= 0 && syms[s].sect == SC_PENDING; }

/* one instruction in the making */
struct ins {
	struct fmt f;
	int minlen;		/* the length it needs, at least */
	int64_t dval;		/* the displacement or immediate, signed, before it is cut to the final length */
	int mode;
	int relsym, reltype;	/* a relocation on the instruction, if reltype */
	int64_t reladd;
};

/* the memory-side operand (the `rm` specifier) into f for a given len.  Returns the length it needs, or -1 (error). */
enum { MS_ANY, MS_NOREG, MS_NOIMM };	/* what the operand may be */

static int need_len(int mode, int64_t v)
{
	for (int len = 1; len <= maxlen; len++)
		if (fits(v, dispbits(mode, len)))
			return len;
	return -1;
}

static int build_rm(const struct stmt *st, const struct oper *o, int dstride, int restrict_, struct ins *in, int64_t addr)
{
	struct fmt *f = &in->f;
	int mode = -1, need = 1;
	struct val v = vconst(0);
	int64_t d = 0;

	if (o->kind == OK_REG) {
		if (restrict_ == MS_NOREG) { err(st->line, "this operand cannot be a register"); return -1; }
		f->low = o->reg;
		f->shape = FS_MEM0;
		in->minlen = 0;
		return 0;
	}
	if (o->e.n) v = eval(o->e, st->line);
	switch (o->kind) {
	case OK_IMM: case OK_ABS:
		mode = o->kind == OK_IMM ? AMODE_IMM : AMODE_ABS;
		if (mode == AMODE_IMM && restrict_ == MS_NOIMM) { err(st->line, "this operand cannot be immediate"); return -1; }
		if (CONST(v)) {
			d = v.c;
			need = need_len(mode, d);
			if (need < 0) { err(st->line, "constant %lld does not fit the widest field", (long long)d); return -1; }
		} else {
			need = maxlen;
			in->relsym = v.p; in->reladd = v.c; in->reltype = R_PDP64_INSN_ABS;
			if (v.m >= 0) { err(st->line, "cannot subtract a symbol here"); return -1; }
		}
		break;
	case OK_BARE: case OK_BASED:
		if (o->kind == OK_BASED && o->special == 0) {			/* d(Rn) */
			mode = AMODE_BASE;
			if (!CONST(v)) { err(st->line, "a displacement from a register must be a constant"); return -1; }
			d = v.c;
			need = need_len(mode, d);
			if (need < 0) { err(st->line, "displacement %lld too large", (long long)d); return -1; }
			f->rm = o->reg;
			break;
		}
		if (o->kind == OK_BASED && o->special == 2) {			/* d(DP) */
			mode = AMODE_DP;
			if (!CONST(v)) { err(st->line, "a displacement from DP must be a constant"); return -1; }
			d = v.c;
			need = need_len(mode, d);
			if (need < 0) { err(st->line, "displacement %lld too large", (long long)d); return -1; }
			break;
		}
		mode = AMODE_PCREL;						/* a symbol, or d(PC): pc-relative */
		if (o->kind == OK_BASED && o->e.n == 0) v = vconst(0);
		if (o->kind == OK_BARE || !CONST(v)) {
			if (CONST(v)) { err(st->line, "a bare number is not an address; write @n or #n"); return -1; }
			if (v.m >= 0) { err(st->line, "cannot subtract a symbol here"); return -1; }
			if (samesec(v.p) || pending(v.p)) {
				d = pending(v.p) ? 0 : syms[v.p].val + v.c - addr;
				need = need_len(mode, d);
				if (need < 0) { err(st->line, "target out of reach"); return -1; }
			} else {
				need = maxlen - 1;				/* 32 bits: a symbol of another section or an external one */
				in->relsym = v.p; in->reladd = v.c; in->reltype = R_PDP64_INSN_PC;
			}
		} else {
			d = v.c;							/* expr(pc): the displacement as written */
			need = need_len(mode, d);
			if (need < 0) { err(st->line, "displacement too large"); return -1; }
		}
		break;
	case OK_INDEXED:
		mode = AMODE_INDEX;
		if (!CONST(v)) { err(st->line, "a displacement from a register must be a constant"); return -1; }
		d = v.c;
		need = need_len(mode, d);
		if (need < 0) { err(st->line, "displacement %lld too large", (long long)d); return -1; }
		f->rm = o->reg; f->rx = o->reg2;
		f->s = o->scale == 1 ? 0 : o->scale == 2 ? 1 : o->scale == 4 ? 2 : 3;
		break;
	case OK_POSTINC: case OK_PREDEC: case OK_PREDEC2:
		mode = o->kind == OK_POSTINC ? AMODE_POSTINC : AMODE_PREDEC;
		d = dstride;
		if (o->e.n) {
			if (!CONST(v)) { err(st->line, "a stride must be a constant"); return -1; }
			d = v.c;
		}
		need = need_len(mode, d);
		if (need < 0) { err(st->line, "stride too large"); return -1; }
		f->rm = o->reg;
		break;
	default:
		err(st->line, "bad operand");
		return -1;
	}
	f->shape = mode_shape[mode];
	f->low = mode;
	in->mode = mode;
	in->minlen = need;
	in->dval = d;
	return need;
}

/* a branch target into f; returns the len needed or -1.  Displacements count in parcels from the first parcel. */
static int build_branch(const struct stmt *st, const struct oper *o, int minlen, struct ins *in, int64_t addr)
{
	struct fmt *f = &in->f;
	struct val v = vconst(0);
	int64_t d = 0;
	int need;

	if (o->kind != OK_BARE) { err(st->line, "a branch target is a label"); return -1; }
	v = eval(o->e, st->line);
	if (CONST(v) || v.m >= 0) { err(st->line, "a branch target is a label"); return -1; }
	if (samesec(v.p) || pending(v.p)) {
		int64_t t = pending(v.p) ? 0 : syms[v.p].val + v.c - addr;
		if (t & 1) { err(st->line, "branch to an odd address"); return -1; }
		d = t / 2;
		if (fits(d, regbits + lowbits)) need = 0;
		else for (need = 1; need < maxlen && !fits(d, branchbits(need)); need++) ;
	} else {
		need = maxlen - 1;
		in->relsym = v.p; in->reladd = v.c; in->reltype = R_PDP64_INSN_BR;
	}
	if (need < minlen) need = minlen;
	in->minlen = need;
	in->dval = d;
	f->shape = need == 0 ? FS_BR0 : FS_D;
	return need;
}

static int regv(const struct stmt *st, int k) { return k < st->nops && st->ops[k].kind == OK_REG ? st->ops[k].reg : -1; }

static int imm_const(const struct stmt *st, int k, int64_t *out)
{
	if (st->nops <= k || st->ops[k].kind != OK_IMM) { err(st->line, "operand %d must be an immediate", k + 1); return -1; }
	struct val v = eval(st->ops[k].e, st->line);
	if (!CONST(v)) { err(st->line, "operand %d must be a constant", k + 1); return -1; }
	*out = v.c;
	return 0;
}

/* the size in bytes a move of this mnemonic transfers: the default stride of (Rn)+ and -(Rn) */
static int mov_size(int mg, int mn)
{
	if (mg == MG_MOV)
		switch (mn) { case MN_MOV_MOVQ: return 8; case MN_MOV_MOVL: return 4; case MN_MOV_MOVW: return 2; default: return 1; }
	switch (mn) { case MN_MOVZ_MOVZL: return 4; case MN_MOVZ_MOVZW: return 2; default: return 1; }
}

/* the store opcode of a move mnemonic, from the table of stores in the grammar */
static int store_opc(int mn)
{
	switch (mn) {
	case MN_MOV_MOVQ: return MOVSTORE_MOVQ;
	case MN_MOV_MOVL: return MOVSTORE_MOVL;
	case MN_MOV_MOVW: return MOVSTORE_MOVW;
	default: return MOVSTORE_MOVB;
	}
}

/* Cut the displacement to the length chosen, and give the fields their final shape. */
static void finalize(struct ins *in, int len)
{
	struct fmt *f = &in->f;
	if (len < in->minlen) len = in->minlen;
	f->len = len;
	switch (f->shape) {
	case FS_BR0:
		if (len == 0) {
			f->reg = (int)(((uint64_t)in->dval >> lowbits) & mask(regbits)); f->low = (int)((uint64_t)in->dval & mask(lowbits));
		} else {
			f->shape = FS_D;
			f->low = 0;
			f->d = in->reltype ? 0 : ((uint64_t)in->dval & mask(branchbits(len)));
		}
		break;
	case FS_D:
		f->d = in->reltype ? 0 : ((uint64_t)in->dval & mask(branchbits(len)));
		break;
	case FS_BASE: case FS_DP: case FS_INDEX: case FS_WIDE:
		f->d = in->reltype ? 0 : ((uint64_t)in->dval & mask(dispbits(in->mode, len)));
		break;
	}
}

/* Build the instruction.  Returns 0, -1 on error; the length it needs is in->minlen. */
static int build(const struct stmt *st, int64_t addr, struct ins *in)
{
	struct fmt *f = &in->f;
	const struct oper *o = st->ops;
	int rc, mg = st->mg, mn = st->mnum;

	memset(in, 0, sizeof *in);
	in->relsym = -1;

	/* the aliases of ISA 4.15 are words of their group, numbered above its encodings: they become the instruction they stand for */
	if ((mg == MG_BRANCH && (mn == MN_BRANCH_BHIS || mn == MN_BRANCH_BLO)) || (mg == MG_ALU && mn == MN_ALU_MULU) ||
	    (mg == MG_SYS_NONE && mn == MN_SYS_NONE_WAIT) || (mg == MG_BESC && mn == MN_BESC_ROL)) {
		struct stmt a = *st;
		if (mg == MG_BRANCH) a.mnum = mn == MN_BRANCH_BHIS ? MN_BRANCH_BCC : MN_BRANCH_BCS;
		else if (mg == MG_ALU) a.mnum = MN_ALU_MUL;
		else if (mg == MG_SYS_NONE) a.mnum = MN_SYS_NONE_WFE;
		else {								/* rol rs, #n, rd -> rori rs, #(64-n), rd */
			int64_t n;
			a.mnum = MN_BESC_RORI;
			if (a.nops != 3 || imm_const(&a, 1, &n)) { err(st->line, "rol takes a register, a constant count and a register (ISA 4.15)"); return -1; }
			char *buf = malloc(24);
			snprintf(buf, 24, "%lld", (long long)((64 - n) & 63));
			a.ops[1].e.p = buf; a.ops[1].e.n = (int)strlen(buf);
		}
		return build(&a, addr, in);
	}

	switch (mg) {
	case MG_MOV: case MG_MOVZ: {
		int isst = 0;
		if (st->nops != 2) { err(st->line, "two operands"); return -1; }
		if (mg == MG_MOV && o[1].kind != OK_REG && o[0].kind == OK_REG) isst = 1;
		if (isst) {
			f->opc = store_opc(mn); f->reg = o[0].reg;
			rc = build_rm(st, &o[1], mov_size(mg, mn), MS_NOIMM, in, addr);
		} else {
			if (o[1].kind != OK_REG) { err(st->line, "the destination must be a register or the source a register"); return -1; }
			f->opc = mn; f->reg = o[1].reg;
			rc = build_rm(st, &o[0], mov_size(mg, mn), MS_ANY, in, addr);
		}
		if (rc < 0) return -1;
		break;
	}
	case MG_LEA:
		if (st->nops != 2 || o[1].kind != OK_REG) { err(st->line, "lea address, register"); return -1; }
		f->opc = OPGROUP_LEA; f->reg = o[1].reg;
		if (build_rm(st, &o[0], 8, MS_NOREG, in, addr) < 0) return -1;
		if (in->minlen < 1) in->minlen = 1;
		if (o[0].kind == OK_IMM) { err(st->line, "lea of an immediate"); return -1; }
		break;
	case MG_ALU:
		if (st->nops != 2) { err(st->line, "two operands"); return -1; }
		f->opc = mn;
		if (mn == MN_ALU_CMP) {							/* cmp rd, rm (errata 13) */
			if (o[0].kind != OK_REG) { err(st->line, "cmp: the first operand must be a register"); return -1; }
			f->reg = o[0].reg;
			rc = build_rm(st, &o[1], 8, MS_ANY, in, addr);
		} else {
			if (o[1].kind != OK_REG) { err(st->line, "the destination must be a register"); return -1; }
			f->reg = o[1].reg;
			rc = build_rm(st, &o[0], 8, MS_ANY, in, addr);
		}
		if (rc < 0) return -1;
		break;
	case MG_SOP:
		f->opc = OPGROUP_SOP; f->reg = mn;
		if (mn == MN_SOP_PUSHM || mn == MN_SOP_POPM) {				/* pushm #mask, popm #mask */
			int64_t m;
			if (st->nops != 1 || imm_const(st, 0, &m)) { err(st->line, "pushm/popm take #mask"); return -1; }
			if (m < 0 || m > 0xFFFF) { err(st->line, "register mask out of range"); return -1; }
			f->low = AMODE_IMM; f->shape = mode_shape[AMODE_IMM]; in->dval = m; in->mode = AMODE_IMM; in->minlen = 1;
			break;
		}
		if (st->nops != 1) { err(st->line, "one operand"); return -1; }
		if (build_rm(st, &o[0], 8, MS_ANY, in, addr) < 0) return -1;
		break;
	case MG_XFER:
		f->opc = OPGROUP_XFER; f->reg = mn;
		if (st->nops != 1) { err(st->line, "one operand"); return -1; }
		if (mn == MN_XFER_JTAG && o[0].kind != OK_INDEXED) { err(st->line, "jtag needs d(Rbase)(Rtagged)"); return -1; }
		if (build_rm(st, &o[0], 8, MS_NOREG, in, addr) < 0) return -1;
		if (in->minlen < 1) in->minlen = 1;
		break;
	case MG_BRANCH:
		f->opc = mn;
		if (st->nops != 1) { err(st->line, "one operand"); return -1; }
		if (build_branch(st, &o[0], 0, in, addr) < 0) return -1;
		break;
	case MG_SOB:
		f->opc = OPGROUP_SOB;
		if (st->nops != 2 || o[0].kind != OK_REG) { err(st->line, "sob register, label"); return -1; }
		if (build_branch(st, &o[1], 1, in, addr) < 0) return -1;
		f->reg = o[0].reg; f->low = 0;
		break;
	case MG_TAG: {
		int64_t tag;
		f->opc = OPGROUP_TAG;
		if (st->nops != 3 || o[0].kind != OK_REG || imm_const(st, 1, &tag) || tag < 0 || tag > 7) {
			err(st->line, "btag register, #tag, label"); return -1;
		}
		if (build_branch(st, &o[2], 1, in, addr) < 0) return -1;
		f->reg = o[0].reg; f->low = (mn << 3) | (int)tag;
		break;
	}
	case MG_SYS_NONE:
		f->opc = OPGROUP_SYS; f->reg = 0; f->low = mn; f->shape = FS_SYS0;
		if (st->nops) { err(st->line, "no operands"); return -1; }
		break;
	case MG_SYS: {
		f->opc = OPGROUP_SYS; f->reg = mn; f->shape = FS_SYS0;
		if (mn == MN_SYS_SPL || mn == MN_SYS_TRAP) {				/* spl #n, trap #n */
			int64_t n;
			if (st->nops != 1 || imm_const(st, 0, &n) || n < 0) { err(st->line, "%s #n", mn == MN_SYS_SPL ? "spl" : "trap"); return -1; }
			if (n < (1 << lowbits)) f->low = (int)n;
			else if (mn == MN_SYS_TRAP && n < 256) { f->reg = MN_SYS_TRAPL; f->low = 0; f->shape = FS_SYSN; f->n = (unsigned)n; in->minlen = 1; }
			else { err(st->line, "operand out of range"); return -1; }
		} else if (mn == MN_SYS_PROBER || mn == MN_SYS_PROBEW) {		/* prober rd, rs */
			if (st->nops != 2 || o[0].kind != OK_REG || o[1].kind != OK_REG) { err(st->line, "prober/probew rd, rs"); return -1; }
			f->low = o[1].reg; f->shape = FS_SYSRD; f->rd = o[0].reg; in->minlen = 1;
		} else {
			if (st->nops != 1 || o[0].kind != OK_REG) { err(st->line, "one register operand"); return -1; }
			f->low = o[0].reg;
		}
		break;
	}
	case MG_BESC: case MG_AESC: case MG_MBLK: {
		int64_t a, b;
		int n = st->nops;
		f->opc = mg == MG_BESC ? OPGROUP_BESC : mg == MG_AESC ? OPGROUP_AESC : OPGROUP_MBLK;
		f->sub = mn; f->shape = FS_REGESC; in->minlen = 1;
		if (mg == MG_MBLK) {							/* mcpy rd, rs, rn  mval rd, rn */
			if (mn == MN_MBLK_MVAL) { if (n != 2 || regv(st, 0) < 0 || regv(st, 1) < 0) goto bad; f->reg = o[0].reg; f->low = 0; f->t = o[1].reg; break; }
			if (n != 3 || regv(st, 0) < 0 || regv(st, 1) < 0 || regv(st, 2) < 0) goto bad;
			f->reg = o[0].reg; f->low = o[1].reg; f->t = o[2].reg;
			break;
		}
		if (mg == MG_BESC && mn == MN_BESC_RORI) {				/* rori rs, #n, rd */
			if (n != 3 || o[0].kind != OK_REG || imm_const(st, 1, &a) || o[2].kind != OK_REG || a < 0 || a > 63) goto bad;
			f->reg = o[2].reg; f->low = o[0].reg; f->shape = FS_COUNT; f->count = (unsigned)a;
			break;
		}
		if (mg == MG_BESC && mn == MN_BESC_DSHR) {				/* dshr ra, rb, #n, rd */
			if (n != 4 || o[0].kind != OK_REG || o[1].kind != OK_REG || imm_const(st, 2, &a) || o[3].kind != OK_REG || a < 0 || a > 63) goto bad;
			f->reg = o[3].reg; f->low = o[0].reg; f->t = o[1].reg; f->shape = FS_FIELD; f->pos = (unsigned)a; f->width = 0; in->minlen = 2;
			break;
		}
		if (mg == MG_BESC && (mn == MN_BESC_EXTB || mn == MN_BESC_EXTZB || mn == MN_BESC_INSB)) {	/* extb rs, #pos, #width, rd */
			if (n != 4 || o[0].kind != OK_REG || imm_const(st, 1, &a) || imm_const(st, 2, &b) || o[3].kind != OK_REG) goto bad;
			if (a < 0 || a > 63 || b < 1 || b > 64) goto bad;
			f->reg = o[3].reg; f->low = o[0].reg; f->shape = FS_FIELD; f->pos = (unsigned)a; f->width = (unsigned)(b & 255); in->minlen = 2;
			break;
		}
		if (mg == MG_BESC && (mn == MN_BESC_CLZ || mn == MN_BESC_CTZ || mn == MN_BESC_CLO || mn == MN_BESC_CTO || mn == MN_BESC_POPCNT ||
		    mn == MN_BESC_BSWAP || mn == MN_BESC_BSWAPW || mn == MN_BESC_BSWAPL || mn == MN_BESC_BITREV ||
		    mn == MN_BESC_UTF8LEN || mn == MN_BESC_UTF8DEC || mn == MN_BESC_UTF8ENC)) {		/* rs, rd */
			if (n != 2 || o[0].kind != OK_REG || o[1].kind != OK_REG) goto bad;
			f->reg = o[1].reg; f->low = o[0].reg;
			break;
		}
		if (n != 3 || o[0].kind != OK_REG || o[1].kind != OK_REG || o[2].kind != OK_REG) goto bad;	/* ra, rb, rd */
		f->reg = o[2].reg; f->low = o[0].reg; f->t = o[1].reg;
		break;
	bad:
		err(st->line, "wrong operands for this instruction");
		return -1;
	}
	default:
		err(st->line, "this instruction group is not implemented yet");
		return -1;
	}
	return 0;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* directives                                                                                                          */

static int dir_is(const struct stmt *st, const char *n) { return st->name.n == (int)strlen(n) && memcmp(st->name.p, n, st->name.n) == 0; }

/* the bytes of a "string" argument, C's escapes */
static int unescape(struct slice s, uint8_t *out)
{
	int n = 0;
	const char *p = s.p + 1, *e = s.p + s.n - 1;
	while (p < e) {
		int iscp, v = c_char(&p, e, &iscp);
		if (iscp) n += utf8_put(v, out + n);
		else out[n++] = (uint8_t)v;
	}
	return n;
}

static void put_le(int64_t v, int size)
{
	uint8_t b[8];
	for (int i = 0; i < size; i++) b[i] = (uint64_t)v >> (8 * i);
	emit_bytes_n(b, size);
}

/* The size a statement adds to its section, and (in the final pass) its bytes.  `grow` is where the current length of each
   instruction lives between passes. */
static uint8_t *grow;

/* a one-parcel SYS instruction with no operand, written by the generated encoder */
static void emit_sys0(int minor)
{
	struct fmt f;
	uint8_t b[8]; size_t n;
	memset(&f, 0, sizeof f);
	f.opc = OPGROUP_SYS; f.low = minor; f.shape = FS_SYS0;
	if (fmt_encode(&f, b, &n) < 0) { fprintf(stderr, "%s: internal error: cannot encode a SYS instruction\n", progname); exit(2); }
	uint8_t t = b[0]; b[0] = b[1]; b[1] = t;
	emit_bytes_n(b, 2);
}

static void pad_to(int64_t align)
{
	int64_t pos = cur_sec == SEC_BSS ? offs[cur_sec] : (int64_t)sec[cur_sec].n;
	int64_t padn = (align - pos % align) % align;
	if (cur_sec == SEC_BSS) { offs[cur_sec] += padn; return; }
	if (final_pass) {
		for (int64_t i = 0; i < padn; i++) {
			if (cur_sec == SEC_TEXT && padn - i >= 2 && (pos + i) % 2 == 0) { emit_sys0(MN_SYS_NONE_NOP); i++; }
			else { uint8_t z = 0; emit_bytes_n(&z, 1); }
		}
	} else offs[cur_sec] += padn;
}

static void directive(const struct stmt *st)
{
	if (dir_is(st, "text")) { cur_sec = SEC_TEXT; return; }
	if (dir_is(st, "data")) { cur_sec = SEC_DATA; return; }
	if (dir_is(st, "bss")) { cur_sec = SEC_BSS; return; }
	if (dir_is(st, "globl")) {
		for (int i = 0; i < st->nargs; i++) syms[symget(st->args[i].s.p, st->args[i].s.n)].global = 1;
		return;
	}
	if (dir_is(st, "comm")) {
		if (st->nargs != 2) { if (final_pass) err(st->line, ".comm name, size"); return; }
		int i = symget(st->args[0].s.p, st->args[0].s.n);
		struct val v = eval(st->args[1].s, st->line);
		syms[i].global = 1; syms[i].sect = SC_COMMON; syms[i].val = v.c;
		return;
	}
	int64_t unit = dir_is(st, "byte") ? 1 : dir_is(st, "word") ? 2 : dir_is(st, "long") ? 4 : dir_is(st, "quad") ? 8 : 0;
	if (unit) {
		for (int i = 0; i < st->nargs; i++) {
			if (st->args[i].isstr) {
				uint8_t buf[512];
				int n = unescape(st->args[i].s, buf);
				if (unit != 1) { if (final_pass) err(st->line, "a string only in .byte"); continue; }
				if (cur_sec == SEC_BSS) offs[cur_sec] += n;
				else if (final_pass) emit_bytes_n(buf, n); else offs[cur_sec] += n;
				continue;
			}
			if (cur_sec == SEC_BSS) { offs[cur_sec] += unit; continue; }
			if (!final_pass) { offs[cur_sec] += unit; continue; }
			struct val v = eval(st->args[i].s, st->line);
			if (CONST(v)) {
				if (unit < 8 && !fits(v.c, unit * 8) && !(v.c >= 0 && v.c < ((int64_t)1 << (unit * 8)))) err(st->line, "value %lld does not fit %d byte(s)", (long long)v.c, (int)unit);
				put_le(v.c, (int)unit);
			} else if (v.m >= 0 || (unit != 4 && unit != 8)) {
				err(st->line, "a symbol only in .long and .quad");
			} else {
				addreloc(cur_sec, (int64_t)sec[cur_sec].n, unit == 8 ? R_PDP64_D64 : R_PDP64_D32, v.p, v.c);
				put_le(0, (int)unit);
			}
		}
		if (!final_pass) { /* sizes were added above for the bss/string cases; data sizes: */ }
		return;
	}
	if (dir_is(st, "ascii")) {
		for (int i = 0; i < st->nargs; i++) {
			uint8_t buf[512];
			int n = unescape(st->args[i].s, buf);
			if (final_pass) emit_bytes_n(buf, n); else offs[cur_sec] += n;
		}
		return;
	}
	if (dir_is(st, "even")) { pad_to(2); return; }
	if (dir_is(st, "align")) {
		struct val v = st->nargs ? eval(st->args[0].s, st->line) : vconst(2);
		if (!CONST(v) || v.c < 1 || (v.c & (v.c - 1))) { if (final_pass) err(st->line, ".align takes a power of two"); return; }
		pad_to(v.c);
		return;
	}
	if (dir_is(st, "space")) {
		struct val v = st->nargs ? eval(st->args[0].s, st->line) : vconst(0);
		if (!CONST(v) || v.c < 0) { if (final_pass) err(st->line, ".space takes a constant"); return; }
		if (cur_sec == SEC_BSS || !final_pass) offs[cur_sec] += v.c;
		else { uint8_t z = 0; for (int64_t i = 0; i < v.c; i++) emit_bytes_n(&z, 1); }
		return;
	}
	if (dir_is(st, "lpad")) {
		if (final_pass) emit_sys0(MN_SYS_NONE_LPAD); else offs[cur_sec] += 2;
		return;
	}
	if (final_pass) err(st->line, ".%.*s is not implemented", st->name.n, st->name.p);
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the passes                                                                                                          */

static int run_pass(int final)
{
	int changed = 0;

	final_pass = final;
	cur_sec = SEC_TEXT;
	for (int i = 0; i < NSEC; i++) offs[i] = 0;
	if (final) for (int i = 0; i < NSEC; i++) sec[i].n = 0;
	nrelocs = final ? 0 : nrelocs;

	for (int i = 0; i < nprog; i++) {
		struct stmt *st = &prog[i];
		cur_stmt = i;
		int64_t pos = (cur_sec == SEC_BSS || !final) ? offs[cur_sec] : (int64_t)sec[cur_sec].n;
		syms[dot_sym].sect = cur_sec; syms[dot_sym].val = pos;
		switch (st->kind) {
		case S_LABEL: {
			int k = -1;
			if (all_digits(st->name.p, st->name.n)) {
				for (int j = 0; j < nlloc; j++) if (lloc[j].stmt == i) k = lloc[j].sym;
			} else k = symget(st->name.p, st->name.n);
			if (k >= 0) { syms[k].sect = cur_sec; syms[k].val = pos; }
			break;
		}
		case S_ASSIGN: {
			int k = symget(st->name.p, st->name.n);
			struct val v = eval(st->expr, st->line);
			if (CONST(v)) { syms[k].sect = SC_ABS; syms[k].val = v.c; }
			else if (v.p >= 0 && v.m < 0 && syms[v.p].sect >= 0) { syms[k].sect = syms[v.p].sect; syms[k].val = syms[v.p].val + v.c; }
			else if (final) err(st->line, "assignment of a non-constant expression");
			break;
		}
		case S_DIR:
			directive(st);
			break;
		case S_INSN: {
			struct ins in;
			int len = grow[i];
			if (build(st, pos, &in) < 0) { in.minlen = 0; in.f.shape = FS_SYS0; len = 0; if (!final) { offs[cur_sec] += 2; break; } }
			if (in.minlen > len) { len = in.minlen; if (len != grow[i]) { grow[i] = len; changed = 1; } }
			if (!final) { offs[cur_sec] += 2 * (len + 1); break; }
			finalize(&in, len);
			if (errors) break;
			if (cur_sec == SEC_BSS) { err(st->line, "an instruction in .bss"); break; }
			uint8_t b[8]; size_t n;
			if (fmt_encode(&in.f, b, &n) < 0) { err(st->line, "internal error: cannot encode"); break; }
			/* parcels are little-endian in memory; the writer produced them big-endian */
			for (size_t k = 0; k + 1 < n; k += 2) { uint8_t t = b[k]; b[k] = b[k + 1]; b[k + 1] = t; }
			if (in.reltype) addreloc(cur_sec, (int64_t)sec[cur_sec].n, in.reltype, in.relsym, in.reladd);
			emit_bytes_n(b, n);
			break;
		}
		}
	}
	return changed;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the object file: ELF64 relocatable                                                                                  */

struct buf { uint8_t *p; size_t n, cap; };
static void bput(struct buf *b, const void *d, size_t n)
{
	if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 256; b->p = realloc(b->p, b->cap); }
	memcpy(b->p + b->n, d, n);
	b->n += n;
}
static void balign(struct buf *b, size_t a) { static const uint8_t z[8]; while (b->n % a) bput(b, z, 1); }

static void rec(elfrec_t *r, struct buf *out)
{
	uint8_t tmp[128]; size_t n; char e[160];
	if (!emit_bytes(r, tmp, sizeof tmp, &n, e, sizeof e)) { fprintf(stderr, "%s: internal error writing a record: %s\n", progname, e); exit(2); }
	bput(out, tmp + 1, n - 1);					/* drop the selector byte */
}
static size_t strtab_add(struct buf *t, const char *s)
{
	size_t at = t->n;
	bput(t, s, strlen(s) + 1);
	return at;
}

static int write_object(const char *path)
{
	struct buf file = { 0 }, strtab = { 0 }, symtab = { 0 }, rela[2] = { { 0 }, { 0 } }, shstr = { 0 };
	elfrec_t r;
	int nout;

	bput(&strtab, "", 1);
	bput(&shstr, "", 1);
	/* symbols: null, three section symbols, then the locals, then the globals */
	nout = 4;
	for (int pass = 0; pass < 2; pass++)
		for (int i = 0; i < nsyms; i++) {
			struct sym *s = &syms[i];
			int isglobal = s->global || s->sect == SC_UNDEF || s->sect == SC_COMMON;
			if (s->islocal || i == dot_sym || isglobal != pass) continue;
			if (s->sect == SC_PENDING) continue;
			if (!isglobal && !(s->sect >= 0 || s->sect == SC_ABS)) continue;
			s->outidx = nout++;
		}
	int firstglobal = 4;
	for (int i = 0; i < nsyms; i++)
		if (syms[i].outidx >= 4 && !(syms[i].global || syms[i].sect == SC_UNDEF || syms[i].sect == SC_COMMON) && syms[i].outidx + 1 > firstglobal)
			firstglobal = syms[i].outidx + 1;
	/* emit in index order */
	{
		memset(&r, 0, sizeof r); r.kind = 3; r.body.kind = 3;
		rec(&r, &symtab);						/* null symbol */
		for (int k = 1; k <= 3; k++) {
			memset(&r, 0, sizeof r); r.kind = 3; r.body.kind = 3;
			r.body.u.a3.y.info = 3; r.body.u.a3.y.shndx = k;
			rec(&r, &symtab);
		}
		for (int idx = 4; idx < nout; idx++)
			for (int i = 0; i < nsyms; i++) {
				struct sym *s = &syms[i];
				if (s->outidx != idx) continue;
				int isglobal = s->global || s->sect == SC_UNDEF || s->sect == SC_COMMON;
				memset(&r, 0, sizeof r); r.kind = 3; r.body.kind = 3;
				r.body.u.a3.y.name = (uint32_t)strtab_add(&strtab, s->name);
				r.body.u.a3.y.info = (uint8_t)((isglobal ? 1 : 0) << 4);
				r.body.u.a3.y.shndx = s->sect >= 0 && s->sect < NSEC ? s->sect + 1 : s->sect == SC_ABS ? SHN_ABS : s->sect == SC_COMMON ? SHN_COMMON : 0;
				r.body.u.a3.y.value = s->sect == SC_COMMON ? 8 : (uint64_t)s->val;
				r.body.u.a3.y.size = s->sect == SC_COMMON ? (uint64_t)s->val : 0;
				rec(&r, &symtab);
			}
	}
	/* relocations: by section symbol for anything defined here and not global, by symbol otherwise */
	for (int i = 0; i < nrelocs; i++) {
		struct reloc *rl = &relocs[i];
		struct sym *s = &syms[rl->sym];
		int64_t add = rl->addend;
		int idx;
		if (s->sect >= 0 && s->sect < NSEC && !s->global) { idx = 1 + s->sect; add += s->val; }
		else if (s->outidx >= 0) idx = s->outidx;
		else { fprintf(stderr, "%s: internal error: relocation against %s\n", progname, s->name); return -1; }
		memset(&r, 0, sizeof r); r.kind = 4; r.body.kind = 4;
		r.body.u.a4.r.offset = (uint64_t)rl->off; r.body.u.a4.r.type = rl->type; r.body.u.a4.r.symidx = idx; r.body.u.a4.r.addend = add;
		rec(&r, &rela[rl->sect == SEC_TEXT ? 0 : 1]);
	}

	/* section name table */
	size_t nm_text = strtab_add(&shstr, ".text"), nm_data = strtab_add(&shstr, ".data"), nm_bss = strtab_add(&shstr, ".bss"),
	    nm_sym = strtab_add(&shstr, ".symtab"), nm_str = strtab_add(&shstr, ".strtab"), nm_rt = strtab_add(&shstr, ".rela.text"),
	    nm_rd = strtab_add(&shstr, ".rela.data"), nm_shs = strtab_add(&shstr, ".shstrtab");

	/* layout: ehdr, text, data, symtab, strtab, rela.text, rela.data, shstrtab, section headers */
	uint8_t zero[64] = { 0 };
	bput(&file, zero, 64);
	size_t off_text = file.n; bput(&file, sec[SEC_TEXT].p, sec[SEC_TEXT].n); balign(&file, 8);
	size_t off_data = file.n; bput(&file, sec[SEC_DATA].p, sec[SEC_DATA].n); balign(&file, 8);
	size_t off_sym = file.n; bput(&file, symtab.p, symtab.n);
	size_t off_str = file.n; bput(&file, strtab.p, strtab.n); balign(&file, 8);
	size_t off_rt = file.n; bput(&file, rela[0].p, rela[0].n);
	size_t off_rd = file.n; bput(&file, rela[1].p, rela[1].n);
	size_t off_shs = file.n; bput(&file, shstr.p, shstr.n); balign(&file, 8);
	size_t off_sh = file.n;

	struct { uint32_t name, type; uint64_t flags, addr, off, size; uint32_t link, info; uint64_t align, entsize; } sh[9] = {
		{ 0 },
		{ (uint32_t)nm_text, 1, 6, 0, off_text, sec[SEC_TEXT].n, 0, 0, 2, 0 },
		{ (uint32_t)nm_data, 1, 3, 0, off_data, sec[SEC_DATA].n, 0, 0, 8, 0 },
		{ (uint32_t)nm_bss, 8, 3, 0, off_data, (uint64_t)offs[SEC_BSS], 0, 0, 8, 0 },
		{ (uint32_t)nm_sym, 2, 0, 0, off_sym, symtab.n, 5, (uint32_t)firstglobal, 8, 24 },
		{ (uint32_t)nm_str, 3, 0, 0, off_str, strtab.n, 0, 0, 1, 0 },
		{ (uint32_t)nm_rt, 4, 0x40, 0, off_rt, rela[0].n, 4, 1, 8, 24 },
		{ (uint32_t)nm_rd, 4, 0x40, 0, off_rd, rela[1].n, 4, 2, 8, 24 },
		{ (uint32_t)nm_shs, 3, 0, 0, off_shs, shstr.n, 0, 0, 1, 0 },
	};
	for (int i = 0; i < 9; i++) {
		memset(&r, 0, sizeof r); r.kind = 2; r.body.kind = 2;
		shdr_t *h = &r.body.u.a2.s;
		h->name = sh[i].name; h->type = sh[i].type; h->flags = sh[i].flags; h->addr = sh[i].addr; h->offset = sh[i].off;
		h->size = sh[i].size; h->link = sh[i].link; h->info = sh[i].info; h->addralign = sh[i].align; h->entsize = sh[i].entsize;
		rec(&r, &file);
	}
	{
		static const uint8_t ident[16] = { 0x7f, 'E', 'L', 'F', 2, 1, 1, 0 };
		struct buf head = { 0 };
		memset(&r, 0, sizeof r); r.kind = 1; r.body.kind = 1;
		ehdr_t *e = &r.body.u.a1.e;
		e->ident.ptr = ident; e->ident.len = 16;
		e->type = 1; e->machine = EM_PDP64; e->version = 1; e->shoff = off_sh; e->ehsize = 64; e->shentsize = 64; e->shnum = 9; e->shstrndx = 8;
		rec(&r, &head);
		memcpy(file.p, head.p, head.n);
	}
	FILE *f = fopen(path, "wb");
	if (!f || fwrite(file.p, 1, file.n, f) != file.n || fclose(f)) { fprintf(stderr, "%s: cannot write %s: %s\n", progname, path, strerror(errno)); return -1; }
	return 0;
}

/* ------------------------------------------------------------------------------------------------------------------ */

static char *slurp(const char *path, size_t *len)
{
	FILE *f = strcmp(path, "-") ? fopen(path, "rb") : stdin;
	size_t n = 0, cap = 1 << 16;
	char *b = malloc(cap);
	if (!f) { fprintf(stderr, "%s: %s: %s\n", progname, path, strerror(errno)); exit(1); }
	for (;;) {
		size_t k = fread(b + n, 1, cap - n - 1, f);
		n += k;
		if (k == 0) break;
		if (n + 1 >= cap) { cap *= 2; b = realloc(b, cap); }
	}
	b[n] = 0;
	*len = n;
	if (f != stdin) fclose(f);
	return b;
}

int main(int argc, char **argv)
{
	const char *out = "a.out", *in = NULL;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-o") && i + 1 < argc) out = argv[++i];
		else if (argv[i][0] == '-' && argv[i][1]) { fprintf(stderr, "usage: %s [-o object] file.s\n", progname); return 2; }
		else in = argv[i];
	}
	if (!in) { fprintf(stderr, "usage: %s [-o object] file.s\n", progname); return 2; }
	srcname = in;
	size_t flen;
	char *text = slurp(in, &flen);
	if (strlen(text) != flen) { fprintf(stderr, "%s: %s: contains a NUL byte\n", progname, in); return 1; }
	char em[300]; int el;
	if (asm_parse(text, &prog, &nprog, em, sizeof em, &el)) {
		fprintf(stderr, "%s:%d: %s\n", in, el, em);
		return 1;
	}
	calibrate();
	if (getenv("AS64_FORMATS")) {		/* what the grammar says, as measured */
		printf("maxlen %d regbits %d lowbits %d\n", maxlen, regbits, lowbits);
		for (int m = 0; m < (1 << lowbits); m++) printf("mode %d shape %d\n", m, mode_shape[m]);
		for (int k = 1; k < 16; k++) for (int l = 1; l <= maxlen; l++) if (fieldbits[k][l]) printf("shape %d len %d bits %d\n", k, l, fieldbits[k][l]);
	}
	dot_sym = symadd(".", 1);
	syms[dot_sym].islocal = 1;
	/* every label is known before the first pass, so a forward reference to it is not taken for an external symbol */
	for (int i = 0; i < nprog; i++) {
		struct stmt *st = &prog[i];
		if (st->kind != S_LABEL) continue;
		if (all_digits(st->name.p, st->name.n)) {
			if (nlloc == caplloc) { caplloc = caplloc ? caplloc * 2 : 64; lloc = realloc(lloc, caplloc * sizeof *lloc); }
			int s = symadd(st->name.p, st->name.n);
			syms[s].islocal = 1; syms[s].sect = SC_PENDING;
			lloc[nlloc++] = (struct lloc){ atoi(st->name.p), i, s };
		} else {
			int s = symget(st->name.p, st->name.n);
			if (syms[s].sect == SC_PENDING) { final_pass = 1; err(st->line, "%.*s is defined twice", st->name.n, st->name.p); }
			syms[s].sect = SC_PENDING;
		}
	}
	grow = calloc(nprog + 1, 1);
	for (int it = 0; it < 200; it++)
		if (!run_pass(0) && it >= 1) break;
	run_pass(1);
	if (errors) { fprintf(stderr, "%s: %d error%s\n", progname, errors, errors == 1 ? "" : "s"); return 1; }
	return write_object(out) ? 1 : 0;
}
