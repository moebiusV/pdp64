/* as64: the pdp64 assembler.
 *
 * The grammar does the reading (asmp.c: spec/pdp64-asm.hbnf) and of the object file records (elf.hbnf, included below); the bits of an instruction come from the
 * table codec (common/pdp64enc.c, with the tables generated from spec/pdp64/pdp64.hbnf; asmenc.c, included below).  What is left, and is here, is what no
 * grammar says: symbols and expressions, the directives, the literal pool, the passes and the object file.
 *
 * Addresses, lengths and relocations (docs/errata.md 3, docs/elf-pdp64.md):
 *   - a PC-relative displacement, and a branch displacement, count from the first parcel of the instruction;
 *   - branches count in 2-byte parcels, `d(PC)` in bytes;
 *   - an instruction grows until its displacement or immediate fits; it never shrinks, so the loop ends;
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
static void enc_sys0(const char *name);
static void set_sym_val(int k, int sect, int64_t val);
static void commit_syms(void);
static int relax_set;		/* --relax or --no-relax given */
static int relax_on;		/* --relax: a RELAX object (relocs.h): every address of a symbol in .text instructions has a relocation, paddings are R_PDP64_ALIGN */
static int text_poison;		/* something in .text depends on a distance and is not a relocation: the object is marked NOADJ_TEXT */
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
		if (syms[v.p].sect == SEC_TEXT) text_poison = 1;	/* a distance inside .text becomes a number: the linker cannot adjust it */
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


/* the symbol whose offset is in this section and known: same-section target */
static int samesec(int s) { return s >= 0 && syms[s].sect == cur_sec; }
static int pending(int s) { return s >= 0 && syms[s].sect == SC_PENDING; }

/* The literal pool.  An operand written `=K` is a literal-pool load: K, a 64-bit constant, is stored once in the pool (8 bytes, aligned to 8) and the
   operand is that entry, a pc-relative memory operand.  It is the programmer's explicit choice (an `#imm` that does not fit is an error).  A pool is
   emitted into .text at a `.pool` directive and at the end of the text; a value is stored once per pool, the entries in the order of first use. */
static int64_t *poolv; static int *pools, *poolseg, npool, cappool;
static int pool_seg;			/* the pool being filled: the number of `.pool` directives seen so far in this pass */
static int pool_get(int64_t v)
{
	for (int i = 0; i < npool; i++) if (poolv[i] == v && poolseg[i] == pool_seg) return pools[i];
	if (npool == cappool) { cappool = cappool ? cappool * 2 : 16; poolv = realloc(poolv, cappool * sizeof *poolv); pools = realloc(pools, cappool * sizeof *pools); poolseg = realloc(poolseg, cappool * sizeof *poolseg); }
	poolseg[npool] = pool_seg;
	char nm[32]; snprintf(nm, sizeof nm, ".LC%d", npool);
	int s = symadd(nm, (int)strlen(nm));
	syms[s].islocal = 1; syms[s].sect = SC_PENDING;
	poolv[npool] = v; pools[npool++] = s;
	return s;
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

/* a one-parcel SYS instruction with no operand, written by the codec */
static void emit_sys0(int minor)
{
	enc_sys0(minor == MN_SYS_NONE_NOP ? "nop" : "lpad");
}

static int64_t secalign[3];		/* the largest .align seen in each section; the linker places the section's contribution on it */

static void pad_to(int64_t align)
{
	if (align > secalign[cur_sec]) secalign[cur_sec] = align;
	int64_t pos = (cur_sec == SEC_BSS || !final_pass) ? offs[cur_sec] : (int64_t)sec[cur_sec].n;
	int64_t padn = (align - pos % align) % align;
	if (cur_sec == SEC_BSS) { offs[cur_sec] += padn; return; }
	if (final_pass && relax_on && cur_sec == SEC_TEXT && (padn || align > 2))
		addreloc(SEC_TEXT, pos, R_PDP64_ALIGN, -1, (padn << 32) | align);	/* the linker works the padding out again */
	if (final_pass) {
		for (int64_t i = 0; i < padn; i++) {
			if (cur_sec == SEC_TEXT && padn - i >= 2 && (pos + i) % 2 == 0) { emit_sys0(MN_SYS_NONE_NOP); i++; }
			else { uint8_t z = 0; emit_bytes_n(&z, 1); }
		}
	} else offs[cur_sec] += padn;
}

/* emit the pool being filled into .text (aligned to 8; nothing if it is empty) and start the next one */
static void flush_pool(int final)
{
	int any = 0;
	for (int i = 0; i < npool; i++) if (poolseg[i] == pool_seg) any = 1;
	if (any) {
		cur_sec = SEC_TEXT;
		pad_to(8);
		for (int i = 0; i < npool; i++) {
			if (poolseg[i] != pool_seg) continue;
			int64_t pos = final ? (int64_t)sec[SEC_TEXT].n : offs[SEC_TEXT];
			set_sym_val(pools[i], SEC_TEXT, pos);
			if (final) put_le(poolv[i], 8); else offs[SEC_TEXT] += 8;
		}
	}
	pool_seg++;
}

static void directive(const struct stmt *st)
{
	if (dir_is(st, "pool")) {
		if (cur_sec != SEC_TEXT) { if (final_pass) err(st->line, ".pool is for .text"); return; }
		flush_pool(final_pass);
		return;
	}
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
			if (st->args[i].isstr && unit == 1) {			/* a "string" in .byte; elsewhere a quoted name is a symbol */
				uint8_t buf[512];
				int n = unescape(st->args[i].s, buf);
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

#include "asmenc.c"

/* ------------------------------------------------------------------------------------------------------------------ */
/* the passes                                                                                                          */

static int run_pass(int final)
{
	int changed = 0;

	final_pass = final;
	pool_seg = 0;
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
			if (k >= 0) set_sym_val(k, cur_sec, pos);
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
			int ch = 0, sz = enc_insn(i, pos, final, &ch);
			if (ch) changed = 1;
			if (!final) offs[cur_sec] += sz;
			break;
		}
		}
	}
	cur_sec = SEC_TEXT;
	flush_pool(final);							/* the literal pool at the end of .text */
	commit_syms();
	return changed;
}

/* ------------------------------------------------------------------------------------------------------------------ */
/* the object file: ELF64 relocatable                                                                                  */

struct buf { uint8_t *p; size_t n, cap; };
static void bput(struct buf *b, const void *d, size_t n)
{
	if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 256; b->p = realloc(b->p, b->cap); }
	if (n) memcpy(b->p + b->n, d, n);					/* d is NULL for an empty section */
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
		struct sym *s = &syms[rl->sym < 0 ? 0 : rl->sym];
		int64_t add = rl->addend;
		int idx;
		if (rl->sym < 0) idx = 0;
		else if (s->sect >= 0 && s->sect < NSEC && !s->global) { idx = 1 + s->sect; add += s->val; }
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
		{ (uint32_t)nm_text, 1, 6, 0, off_text, sec[SEC_TEXT].n, 0, 0, secalign[SEC_TEXT] > 2 ? (uint64_t)secalign[SEC_TEXT] : 2, 0 },
		{ (uint32_t)nm_data, 1, 3, 0, off_data, sec[SEC_DATA].n, 0, 0, secalign[SEC_DATA] > 8 ? (uint64_t)secalign[SEC_DATA] : 8, 0 },
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
		e->type = 1; e->machine = EM_PDP64; e->version = 1; e->flags = EF_PDP64_ISA | (uint32_t)(relax_on ? EF_PDP64_RELAX : 0) | (relax_on && text_poison ? EF_PDP64_NOADJ_TEXT : 0); e->shoff = off_sh; e->ehsize = 64; e->shentsize = 64; e->shnum = 9; e->shstrndx = 8;
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

#define USAGE "usage: %s [-m pdp64] [--no-relax] [-o object] file.s\n(the assembler makes relaxation objects by default, docs/relaxation.md: every address of a symbol in an instruction gets a relocation and every padding is re-computed by ld64, which then chooses the shortest form of each; --no-relax makes the plain object)\n(an operand =K is a literal-pool load: the 64-bit constant K goes to the pool, emitted at .pool and at the end of .text;\n -m pdp64 is accepted and ignored, for the driver convention of pcc: there is one target; the fused mnemonics movcall, popmret, popret and mov2 are ordinary instructions; nothing is ever fused by the assembler)\n"

int main(int argc, char **argv)
{
	const char *out = "a.out", *in = NULL;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-m") && i + 1 < argc) {			/* the old pcc driver convention: -m pdp64, the only target */
			if (strcmp(argv[++i], "pdp64")) { fprintf(stderr, "%s: -m %s: the only target is pdp64\n", progname, argv[i]); return 2; }
			continue;
		}
		if (!strcmp(argv[i], "--stats")) { enc_stats = 1; continue; }
		if (!strcmp(argv[i], "--relax")) { relax_on = 1; relax_set = 1; continue; }
		if (!strcmp(argv[i], "--no-relax")) { relax_on = 0; relax_set = 1; continue; }
		if (!strcmp(argv[i], "--dump-lens") && i + 1 < argc) { enc_lens_path = argv[++i]; continue; }
		if (!strcmp(argv[i], "-o") && i + 1 < argc) out = argv[++i];
		else if (argv[i][0] == '-' && argv[i][1]) { fprintf(stderr, USAGE, progname); return 2; }
		else in = argv[i];
	}
	if (!in) { fprintf(stderr, USAGE, progname); return 2; }
	if (!relax_set) relax_on = 1;					/* the default: relaxation objects */
	enc_setup();
	if (enc_lens_path && !(enc_lens = fopen(enc_lens_path, "w"))) { fprintf(stderr, "%s: %s: %s\n", progname, enc_lens_path, strerror(errno)); return 1; }
	srcname = in;
	size_t flen;
	char *text = slurp(in, &flen);
	if (strlen(text) != flen) { fprintf(stderr, "%s: %s: contains a NUL byte\n", progname, in); return 1; }
	char em[300]; int el;
	if (asm_parse(text, &prog, &nprog, em, sizeof em, &el)) {
		fprintf(stderr, "%s:%d: %s\n", in, el, em);
		return 1;
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
	if (enc_lens) fclose(enc_lens);
	if (enc_stats && !errors) fprintf(stderr, "%s: %ld instructions, %ld bytes (%ld cbCC expanded to cmp + bCC)\n", progname, enc_ninsn, enc_nbytes, enc_nexpanded);
	if (errors) { fprintf(stderr, "%s: %d error%s\n", progname, errors, errors == 1 ? "" : "s"); return 1; }
	return write_object(out) ? 1 : 0;
}
