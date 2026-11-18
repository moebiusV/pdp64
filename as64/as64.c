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

enum { SEC_TEXT, SEC_DATA, SEC_BSS, SEC_BUG, NSEC };	/* SEC_BUG: the table of check sites, `__bug_table` (errata 152) */
enum { SC_UNDEF = -1, SC_PENDING = -2, SC_ABS = 16, SC_COMMON = 17 };	/* sym.sect besides 0..NSEC-1 */

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

static int dot_sym = -1;
static int sect_sym[8];			/* NASM's $$: a symbol at the start of each section */

static struct val vconst(int64_t c) { struct val v = { c, -1, -1 }; return v; }

/* The evaluator walks the tree asmp.c built from the grammar (struct xnode, asmir.h): the grammar has already said what is a number, a name, a
   character, an operator.  What it cannot say, because it needs the symbol table, is settled here: `1b` is the nearest numeric label 1 when one is
   defined before the use, else the binary number; `1f` is the forward label. */
static int xbad, xline;

static uint64_t xdigits(struct slice t, int base)
{
	uint64_t n = 0;
	for (int i = 0; i < t.n; i++) {
		int c = (unsigned char)t.p[i];
		n = n * base + (isdigit(c) ? c - '0' : tolower(c) - 'a' + 10);
	}
	return n;
}

/* the nearest numeric label for `N` before (back) or after (not back) the current statement, or -1 */
static int lloc_find(int num, int back)
{
	int best = -1;
	for (int i = 0; i < nlloc; i++) {
		if (lloc[i].num != num) continue;
		if (back ? lloc[i].stmt <= cur_stmt : lloc[i].stmt > cur_stmt)
			if (best < 0 || (back ? lloc[i].stmt > lloc[best].stmt : lloc[i].stmt < lloc[best].stmt)) best = i;
	}
	return best;
}

static int lloc_num(struct slice t)
{
	int n = 0;
	for (int i = 0; i < t.n && n < 100000000; i++) n = n * 10 + (t.p[i] - '0');
	return n;
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

static struct val ev(const struct xnode *x);

static struct val ev_lref(const struct xnode *x, int back)
{
	int best = lloc_find(lloc_num(x->tok), back);
	if (best < 0) { err(xline, "undefined local label %.*s%c", x->tok.n, x->tok.p, back ? 'b' : 'f'); xbad = 1; return vconst(0); }
	struct val v = { 0, lloc[best].sym, -1 };
	return v;
}

static struct val ev_unary(const struct xnode *x)
{
	struct val v = deref(ev(x->a));
	if (xbad) return vconst(0);
	if (!CONST(v)) {
		if (x->op == XN_NEG && v.m < 0) { struct val r = { -v.c, -1, v.p }; return r; }
		if (x->op == XN_NEG && v.p < 0) { struct val r = { -v.c, v.m, -1 }; return r; }
		xbad = 1;
		return vconst(0);
	}
	/* `<x` is the low byte of x and `>x` the high byte: the 6502 assemblers' operators */
	switch (x->op) {
	case XN_NEG: return vconst(-v.c);
	case XN_NOT: return vconst(~v.c);
	case XN_LOW: return vconst(v.c & 0xff);
	case XN_HIGH: return vconst((v.c >> 8) & 0xff);
	}
	return vconst(!v.c);
}

static struct val ev_binary(const struct xnode *x)
{
	struct val a = ev(x->a);
	if (xbad) return vconst(0);
	struct val b = ev(x->b);
	if (xbad) return vconst(0);
	a = deref(a); b = deref(b);
	switch (x->op) {
	case XN_ADD:
		if (a.p >= 0 && b.p >= 0) { xbad = 1; return vconst(0); }
		if (a.m >= 0 && b.m >= 0) { xbad = 1; return vconst(0); }
		a.c += b.c;
		if (b.p >= 0) a.p = b.p;
		if (b.m >= 0) a.m = b.m;
		return deref(a);
	case XN_SUB:
		if (b.p >= 0 && a.m >= 0) { xbad = 1; return vconst(0); }
		a.c -= b.c;
		if (b.p >= 0) a.m = b.p;
		if (b.m >= 0) { if (a.p >= 0) { xbad = 1; return vconst(0); } a.p = b.m; }
		return deref(a);
	case XN_OR: case XN_XOR: case XN_ORNOT:
		if (!CONST(a) || !CONST(b)) { xbad = 1; return vconst(0); }
		a.c = x->op == XN_OR ? (a.c | b.c) : x->op == XN_ORNOT ? (a.c | ~b.c) : (a.c ^ b.c);		/* a ! b: or-not, the early Unix assembler's */
		return deref(a);
	}
	if (!CONST(a) || !CONST(b)) { xbad = 1; return vconst(0); }
	switch (x->op) {
	case XN_MUL: a.c *= b.c; break;
	case XN_DIV: if (b.c) a.c /= b.c; else xbad = 1; break;
	case XN_MOD: if (b.c) a.c %= b.c; else xbad = 1; break;
	case XN_AND: a.c &= b.c; break;
	case XN_SHL: a.c = (int64_t)((uint64_t)a.c << (b.c & 63)); break;
	case XN_SHR: a.c = a.c >> (b.c & 63); break;
	}
	return a;
}

static struct val ev(const struct xnode *x)
{
	switch (x->op) {
	case XN_NUM:
		return vconst((int64_t)xdigits(x->tok, x->base));
	case XN_BINLBL:						/* `Nb`: the label N if one is defined before this statement, else the binary number */
		if (lloc_find(lloc_num(x->tok), 1) >= 0) return ev_lref(x, 1);
		return vconst((int64_t)xdigits(x->tok, 2));
	case XN_LBACK: return ev_lref(x, 1);
	case XN_LFWD: return ev_lref(x, 0);
	case XN_CHAR: case XN_MCHAR: {				/* 'c', and (NASM) 'abcd': up to eight characters, the first the lowest byte */
		const char *p = x->tok.p, *e = p + x->tok.n;
		uint64_t v = 0; int iscp, k = 0;
		while (p < e && k < 8) {
			int64_t ch = (unsigned char)*p >= 0x80 ? utf8_decode(&p, e) : c_char(&p, e, &iscp);
			v |= (uint64_t)ch << (8 * k);
			k++;
		}
		if (p < e) { xbad = 1; return vconst(0); }
		return vconst((int64_t)v);
	}
	case XN_NAME: { struct val v = { 0, symget(x->tok.p, x->tok.n), -1 }; return v; }
	case XN_DOT: { struct val v = { 0, dot_sym, -1 }; return v; }
	case XN_SECT: { struct val v = { 0, sect_sym[cur_sec], -1 }; return v; }
	case XN_NEG: case XN_NOT: case XN_LNOT: case XN_LOW: case XN_HIGH:
		return ev_unary(x);
	case XN_ADD: case XN_SUB: case XN_OR: case XN_XOR: case XN_ORNOT:
	case XN_MUL: case XN_DIV: case XN_MOD: case XN_AND: case XN_SHL: case XN_SHR:
		return ev_binary(x);
	}
	xbad = 1;						/* XN_BAD: not an expression */
	return vconst(0);
}

/* evaluate an expression (the root XN_EXPR); a bad expression is reported once, only in the final pass */
static struct val eval(const struct xnode *r, int line)
{
	xbad = 0; xline = line;
	struct val v = ev(r->a);
	if (xbad) {
		if (final_pass) err(line, "bad expression %.*s", r->tok.n, r->tok.p);
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

static int64_t secalign[NSEC];		/* the largest .align seen in each section; the linker places the section's contribution on it */
static void put_le(int64_t v, int size);
static void addreloc(int sect, int64_t off, int type, int sym, int64_t addend);
static struct val eval(const struct xnode *r, int line);
static void dir_bugrec(const struct stmt *st);
static int dir_is(const struct stmt *st, const char *n) { return st->name.n == (int)strlen(n) && memcmp(st->name.p, n, st->name.n) == 0; }

/* the bytes of a "string" argument, C's escapes */
static int unescape(struct slice s, uint8_t *out)
{
	int n = 0;
	const char *p = s.p + 1, *e = s.p + s.n - 1;
	if (s.p[0] == '\'') { memcpy(out, p, (size_t)(e - p)); return (int)(e - p); }		/* NASM's 'text': no escapes */
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

/* `.bugrec SITE, FILE, LINE, FLAGS`: one record of the table of check sites (errata 152), 12 bytes in the section `__bug_table`, whichever section the assembler
   is in.  The layout is Linux's `struct bug_entry` with relative pointers (include/asm-generic/bug.h): the address of the instruction at SITE and of the string
   at FILE, each as a 32-bit distance from its own field (a relocation R_PDP64_D32_PC: S + A - P), then the line and the flags, 16 bits each.  The
   assembler writes it itself for every check instruction (chk_site); a hand-written program may write one too. */
static void bugrec_emit(int site, int64_t sitec, int file, int64_t filec, int64_t line, int64_t flags)
{
	int save = cur_sec;
	cur_sec = SEC_BUG;
	if (secalign[SEC_BUG] < 4) secalign[SEC_BUG] = 4;
	if (!final_pass) { offs[SEC_BUG] += 12; cur_sec = save; return; }
	int64_t at = (int64_t)sec[SEC_BUG].n;
	addreloc(SEC_BUG, at, R_PDP64_D32_PC, site, sitec);
	put_le(0, 4);
	addreloc(SEC_BUG, at + 4, R_PDP64_D32_PC, file, filec);
	put_le(0, 4);
	put_le(line & 0xffff, 2);
	put_le(flags & 0xffff, 2);
	cur_sec = save;
}

static void dir_bugrec(const struct stmt *st)
{
	if (st->nargs != 4) { if (final_pass) err(st->line, ".bugrec site, file, line, flags"); return; }
	if (!final_pass) { bugrec_emit(0, 0, 0, 0, 0, 0); return; }
	struct val site = eval(st->args[0].x, st->line), file = eval(st->args[1].x, st->line);
	struct val line = eval(st->args[2].x, st->line), flags = eval(st->args[3].x, st->line);
	if (site.p < 0 || site.m >= 0 || file.p < 0 || file.m >= 0 || !CONST(line) || !CONST(flags)) {
		err(st->line, ".bugrec: the site and the file are symbols, the line and the flags constants");
		return;
	}
	bugrec_emit(site.p, site.c, file.p, file.c, line.c, flags.c);
}

/* `.chk KIND, "file", LINE` names the place of the next check instruction (ct<cc>, cteq, ctne, chk2) for the table of check sites; KIND 1 bounds, 2 null,
   3 range, 4 assertion.  Every check instruction then makes its record itself (chk_site): a label at the instruction, the file name in .data (once for each
   name), and the 12 bytes of .bugrec.  Without a .chk the record has kind 0, the source file and the line of the instruction. */
static struct { int have, kind, line; char file[1024]; } chk_pend;
static int nbugsite, nchkfile;
static char *chkfiles[256];

static void dir_chk(const struct stmt *st)
{
	if (st->nargs != 3 || !st->args[1].isstr) { if (final_pass) err(st->line, ".chk KIND, \"file\", LINE"); return; }
	struct val k = eval(st->args[0].x, st->line), l = eval(st->args[2].x, st->line);
	if (!CONST(k) || !CONST(l) || k.c < 0 || k.c > 7 || l.c < 0 || l.c > 65535) { if (final_pass) err(st->line, ".chk: the kind is 0 to 7 and the line 0 to 65535"); return; }
	uint8_t buf[512];
	int n = unescape(st->args[1].s, buf);
	if (n >= (int)sizeof chk_pend.file) n = (int)sizeof chk_pend.file - 1;
	memcpy(chk_pend.file, buf, (size_t)n); chk_pend.file[n] = 0;
	chk_pend.have = 1; chk_pend.kind = (int)k.c; chk_pend.line = (int)l.c;
}

static int is_check(const struct stmt *st);
static void chk_site(const struct stmt *st, int64_t pos)
{
	char nm[40];
	const char *file = chk_pend.have ? chk_pend.file : srcname;
	int kind = chk_pend.have ? chk_pend.kind : 0, line = chk_pend.have ? chk_pend.line : st->line;
	chk_pend.have = 0;
	snprintf(nm, sizeof nm, ".Lbug%d", ++nbugsite);
	int site = symget(nm, (int)strlen(nm));
	set_sym_val(site, cur_sec, pos);
	int k;
	for (k = 0; k < nchkfile; k++) if (!strcmp(chkfiles[k], file)) break;
	snprintf(nm, sizeof nm, ".Lchkf%d", k);
	int fsym = symget(nm, (int)strlen(nm));
	if (k == nchkfile) {							/* the first check of this file name in this pass: its string, in .data */
		if (nchkfile == 256) { if (final_pass) err(st->line, "more than 256 file names in the table of check sites"); return; }
		chkfiles[nchkfile++] = strdup(file);
		int save = cur_sec;
		cur_sec = SEC_DATA;
		int64_t at = final_pass ? (int64_t)sec[SEC_DATA].n : offs[SEC_DATA];
		set_sym_val(fsym, SEC_DATA, at);
		size_t n = strlen(file) + 1;
		if (final_pass) emit_bytes_n((const uint8_t *)file, (int)n); else offs[SEC_DATA] += (int64_t)n;
		cur_sec = save;
	}
	bugrec_emit(site, 0, fsym, 0, line, (int64_t)kind << 5);
}

/* The size a statement adds to its section, and (in the final pass) its bytes.  `grow` is where the current length of each
   instruction lives between passes. */
static uint8_t *grow;

/* a one-parcel SYS instruction with no operand, written by the codec */
static void emit_sys0(int minor)
{
	enc_sys0(minor == MN_SYS_NONE_NOP ? "nop" : "lpad");
}


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
	if (dir_is(st, "endp")) return;				/* `name endp`: the end of a procedure, nothing to do */
	if (dir_is(st, "bugrec")) { dir_bugrec(st); return; }
	if (dir_is(st, "chk")) { dir_chk(st); return; }
	if (dir_is(st, "text")) { cur_sec = SEC_TEXT; return; }
	if (dir_is(st, "data")) { cur_sec = SEC_DATA; return; }
	if (dir_is(st, "bss")) { cur_sec = SEC_BSS; return; }
	if (dir_is(st, "section")) {					/* NASM's section .text|.data|.bss (.rodata and .rdata are .data: there is no read-only section yet) */
		struct slice n = st->args[0].s;
		if (n.n == 5 && !memcmp(n.p, ".text", 5)) cur_sec = SEC_TEXT;
		else if (n.n == 5 && !memcmp(n.p, ".code", 5)) cur_sec = SEC_TEXT;
		else if (n.n == 5 && !memcmp(n.p, ".data", 5)) cur_sec = SEC_DATA;
		else if ((n.n == 7 && !memcmp(n.p, ".rodata", 7)) || (n.n == 6 && !memcmp(n.p, ".rdata", 6))) cur_sec = SEC_DATA;
		else if (n.n == 4 && !memcmp(n.p, ".bss", 4)) cur_sec = SEC_BSS;
		else if (final_pass) err(st->line, "section %.*s: as64 has .text, .data and .bss (.rodata and .rdata are .data)", n.n, n.p);
		return;
	}
	if (dir_is(st, "extern") || dir_is(st, "default") || dir_is(st, "cpu")) return;		/* NASM: a symbol that is not defined is external anyway; the others are for x86 */
	if (dir_is(st, "bits")) {
		struct val v = st->nargs ? eval(st->args[0].x, st->line) : vconst(0);
		if (final_pass && (!CONST(v) || v.c != 64)) err(st->line, "bits: the pdp64 has 64 bits");
		return;
	}
	if (dir_is(st, "resb") || dir_is(st, "resw") || dir_is(st, "resd") || dir_is(st, "resq")) {	/* NASM: reserve n bytes, words, doublewords, quadwords */
		int unit = st->name.p[3] == 'b' ? 1 : st->name.p[3] == 'w' ? 2 : st->name.p[3] == 'd' ? 4 : 8;
		struct val v = st->nargs ? eval(st->args[0].x, st->line) : vconst(-1);
		if (!CONST(v) || v.c < 0) { if (final_pass) err(st->line, "%.*s takes a constant count", st->name.n, st->name.p); return; }
		if (cur_sec == SEC_BSS || !final_pass) offs[cur_sec] += v.c * unit;
		else { uint8_t z = 0; for (int64_t i = 0; i < v.c * unit; i++) emit_bytes_n(&z, 1); }
		return;
	}
	if (dir_is(st, "globl") || dir_is(st, "global")) {
		for (int i = 0; i < st->nargs; i++) syms[symget(st->args[i].s.p, st->args[i].s.n)].global = 1;
		return;
	}
	if (dir_is(st, "comm")) {
		if (st->nargs != 2) { if (final_pass) err(st->line, ".comm name, size"); return; }
		int i = symget(st->args[0].s.p, st->args[0].s.n);
		struct val v = eval(st->args[1].x, st->line);
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
			struct val v = eval(st->args[i].x, st->line);
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
	if (dir_is(st, "align") || dir_is(st, "alignb")) {
		struct val v = st->nargs ? eval(st->args[0].x, st->line) : vconst(2);
		if (!CONST(v) || v.c < 1 || (v.c & (v.c - 1))) { if (final_pass) err(st->line, ".align takes a power of two"); return; }
		pad_to(v.c);
		return;
	}
	if (dir_is(st, "space")) {
		struct val v = st->nargs ? eval(st->args[0].x, st->line) : vconst(0);
		if (!CONST(v) || v.c < 0) { if (final_pass) err(st->line, ".space takes a constant"); return; }
		if (cur_sec == SEC_BSS || !final_pass) offs[cur_sec] += v.c;
		else { uint8_t z = 0; for (int64_t i = 0; i < v.c; i++) emit_bytes_n(&z, 1); }
		return;
	}
	if (dir_is(st, "fill")) {					/* .fill count [, size [, value]]: count units of size bytes (1, 2, 4 or 8) holding value (NASM's times n db v) */
		struct val c = st->nargs >= 1 ? eval(st->args[0].x, st->line) : vconst(-1);
		struct val z = st->nargs >= 2 ? eval(st->args[1].x, st->line) : vconst(1);
		if (st->nargs < 1 || st->nargs > 3 || !CONST(c) || c.c < 0 || !CONST(z) || (z.c != 1 && z.c != 2 && z.c != 4 && z.c != 8)) {
			if (final_pass) err(st->line, ".fill count [, size [, value]]: a constant count, size 1, 2, 4 or 8");
			return;
		}
		if (cur_sec == SEC_BSS || !final_pass) { offs[cur_sec] += c.c * z.c; return; }
		struct val v = st->nargs == 3 ? eval(st->args[2].x, st->line) : vconst(0);
		if (!CONST(v)) { err(st->line, ".fill takes a constant value"); return; }
		for (int64_t i = 0; i < c.c; i++) put_le(v.c, (int)z.c);
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


/* ---- the types of the vector registers inside a block (errata 168) ------------------------------------------------------------------------------------
   A vector register has no type in the machine, but a program that reads a register as other lanes than the ones it wrote (a vacc.l over the 16-bit lanes
   that vld.bu.w made) sums the wrong thing without a word.  The assembler therefore follows, between `vec` and `vend`, the lane size and kind (integer or
   floating point) that the last instruction wrote into each of v0..v15, and refuses an instruction that reads the register as another.  A register not yet
   written in the block (an accumulator from before it) is not checked; signedness is not checked. */
static int vlane[16];
static int vwide, vpend_sz, vpend_line;		/* the widest lane (bytes) of the block so far; a floating-point sum waiting for the end of the block (the size of its source lane, the line), errata 173 */
static char vpend_name[40];
static int vlane_code(const char *t)				/* the lane of a suffix: size, +0x100 for floating point; -1 if it is none */
{
	if (!t || !t[0]) return -1;
	switch (t[0]) {
	case 'b': return 1;
	case 'w': return 2;
	case 'l': return 4;
	case 'q': return 8;
	case 'f': return 4 | 0x100;
	case 'd': return 8 | 0x100;
	}
	return -1;
}
static void vec_typecheck(const struct stmt *st)
{
	const char *w = stmt_canon(st);
	if (!w || w[0] != 'v') return;
	char b[40], *tok[3] = { 0, 0, 0 };
	int nt = 0;
	if (strlen(w) >= sizeof b) return;
	strcpy(b, w);
	char *dot = strchr(b, '.');
	if (dot) { *dot++ = 0; for (char *p = dot; p && nt < 3; ) { tok[nt++] = p; p = strchr(p, '.'); if (p) *p++ = 0; } }
	if (!strcmp(b, "vec") || !strcmp(b, "vend")) {
		/* a floating-point sum is in the canonical order (chunks of 16 bytes of its source lanes: vec-isa.md section 8) only if a strip is a whole number of chunks, that is, if no lane of the block is wider than its source */
		if (vpend_line && vwide > vpend_sz && final_pass)
			err(vpend_line, "%s: the block has %d-byte lanes, so its strip (a whole number of %d-byte lanes) would not be a whole number of the 16-byte chunks that fix the order of a floating-point sum; keep every lane of the block at most %d bytes", vpend_name, vwide, vpend_sz, vpend_sz);
		for (int i = 0; i < 16; i++) vlane[i] = -1;
		vwide = 0; vpend_line = 0;
		return;
	}
	if (!strcmp(b, "vfin")) return;
	{							/* the widest lane of the block (the executor's lanemax): the lane of each instruction */
		int lw = -1;
		if (!strcmp(b, "vld") || !strcmp(b, "vldt") || !strncmp(b, "vlseg", 5)) lw = vlane_code(nt > 1 ? tok[1] : tok[0]);
		else if (!strcmp(b, "vcvt")) lw = 4;
		else if (strcmp(b, "vbsl")) lw = vlane_code(tok[0]);
		if (lw > 0 && (lw & 0xff) > vwide) vwide = lw & 0xff;
		if (!strcmp(b, "vacc") && tok[0] && (tok[0][0] == 'f' || tok[0][0] == 'd') && !tok[0][1] && (!vpend_line || (tok[0][0] == 'f' ? 4 : 8) < vpend_sz)) {
			vpend_line = st->line; vpend_sz = tok[0][0] == 'f' ? 4 : 8; snprintf(vpend_name, sizeof vpend_name, "%s", w);
		}
	}
	const struct oper *o = st->ops;
	int dst = -1, nseg = 1, wlane = -1, rlane = -1, rd[3] = { -1, -1, -1 }, nrd = 0;
	int firstv = st->nops > 0 && o[0].kind == OK_VREG;
	#define RD(k) do { if ((k) < st->nops && o[k].kind == OK_VREG && nrd < 3) rd[nrd++] = o[k].reg; } while (0)
	if (!strcmp(b, "vld") || !strcmp(b, "vldt") || !strncmp(b, "vlseg", 5)) {		/* .m[.lane]: the register gets the lane (the memory type's own when none) */
		wlane = vlane_code(nt > 1 ? tok[1] : tok[0]);
		dst = firstv ? o[0].reg : -1;
		if (!strncmp(b, "vlseg", 5)) nseg = b[5] - '0';
	} else if (!strcmp(b, "vst") || !strcmp(b, "vstt") || !strcmp(b, "vsts") || !strncmp(b, "vsseg", 5)) {	/* .lane[.m]: the register is read as the lane */
		rlane = vlane_code(tok[0]);
		if (!strncmp(b, "vsseg", 5)) nseg = b[5] - '0';
		if (firstv) for (int k = 0; k < nseg && nrd < 3; k++) rd[nrd++] = (o[0].reg + k) & 15;
	} else if (!strcmp(b, "vdot") || !strcmp(b, "vdotu") || !strcmp(b, "vdotsu")) {	/* bytes (vdot.w: 16-bit lanes) in, 32-bit lanes out */
		rlane = vlane_code(tok[0]); RD(1); RD(2);
		wlane = 4; dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vdacc") || !strcmp(b, "vsad")) {			/* vdacc.<b|bu|bsu|w> Rd, vA, vB; vsad.bu Rd, vA, vB: both registers are read as the source lanes, the result is a scalar */
		rlane = vlane_code(tok[0]); RD(1); RD(2);
	} else if (!strcmp(b, "vceq") || !strcmp(b, "vcgt") || !strcmp(b, "vcgtu")) {		/* wave 2: the operands are read as lanes of the suffix; the mask is an integer lane of the same size (also for .f) */
		rlane = vlane_code(tok[0]); RD(1); RD(2);
		wlane = rlane >= 0 ? (rlane & 0xff) : -1; dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vcvt")) {							/* vcvt.<from>.<to>: 32-bit lanes of the source kind in, of the other kind out */
		int ff = tok[0] && !strcmp(tok[0], "f");
		rlane = ff ? (4 | 0x100) : 4; wlane = ff ? 4 : (4 | 0x100); RD(1); dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vbsl")) {							/* vbsl vD, vM, vA, vB: the mask and both operands have the same lane size (the kind is not checked: it is bitwise) */
		int sz = -1, rdl = -1;
		for (int k = 1; k <= 3 && k < st->nops; k++) {
			if (o[k].kind != OK_VREG || vlane[o[k].reg & 15] < 0) continue;
			int l = vlane[o[k].reg & 15];
			if (sz >= 0 && (l & 0xff) != sz && final_pass)
				err(st->line, "vbsl: the mask and the operands must have the same lane size (v%d holds %d-byte lanes, but another operand holds %d-byte lanes)", o[k].reg, l & 0xff, sz);
			if (sz < 0) sz = l & 0xff;
			if (k >= 2 && rdl < 0) rdl = l;
		}
		if (firstv && rdl >= 0) vlane[o[0].reg & 15] = rdl;
		else if (firstv && sz >= 0) vlane[o[0].reg & 15] = sz;
		return;
	} else if (!strcmp(b, "vtbl")) {						/* vtbl.b vD, (Ra), vI: bytes in (the index), bytes out (there is no register form: errata 173) */
		rlane = wlane = 1; RD(2); dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vacc") || !strcmp(b, "vmaxacc") || !strcmp(b, "vminacc")) {	/* .src[.acc]: the register is read as the source lanes */
		rlane = vlane_code(tok[0]); RD(1);
	} else if (!strcmp(b, "vclr")) {
		int lane = vlane_code(tok[0]);
		struct val n = st->nops > 1 && o[1].x ? eval(o[1].x, st->line) : vconst(0);
		if (firstv && CONST(n) && lane >= 0) for (int k = 0; k < n.c && k < 16; k++) vlane[(o[0].reg + k) & 15] = lane;
		return;
	} else if (!strcmp(b, "vfmab") || !strcmp(b, "vfir")) {
		rlane = wlane = vlane_code(tok[0]); RD(1); dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vmov") || !strcmp(b, "vneg")) {
		rlane = wlane = vlane_code(tok[0]); RD(1); dst = firstv ? o[0].reg : -1;
	} else if (!strcmp(b, "vadd") || !strcmp(b, "vsub") || !strcmp(b, "vsubr") || !strcmp(b, "vmul") || !strcmp(b, "vmin") || !strcmp(b, "vmax") ||
	    !strcmp(b, "vminu") || !strcmp(b, "vmaxu") || !strcmp(b, "vabd") || !strcmp(b, "vabdu") || !strcmp(b, "vand") || !strcmp(b, "vor") || !strcmp(b, "vxor") ||
	    !strcmp(b, "vshl") || !strcmp(b, "vshr") || !strcmp(b, "vsar") || !strcmp(b, "vadds") || !strcmp(b, "vsubs") || !strcmp(b, "vaddsu") || !strcmp(b, "vsubsu") ||
	    !strcmp(b, "vmla") || !strcmp(b, "vfma") || !strcmp(b, "vfnma") || !strcmp(b, "vavg") || !strcmp(b, "vavgu") || !strcmp(b, "vmulh") || !strcmp(b, "vmulhu") ||
	    !strcmp(b, "vmulhr") || !strcmp(b, "vsarr") || !strcmp(b, "vshrr")) {
		rlane = wlane = vlane_code(tok[0]); RD(1); RD(2); dst = firstv ? o[0].reg : -1;
	} else return;
	#undef RD
	for (int k = 0; k < nrd; k++)
		if (rlane >= 0 && vlane[rd[k] & 15] >= 0 && vlane[rd[k] & 15] != rlane && final_pass)
			err(st->line, "%s reads v%d as %d-byte %s lanes, but the last write in this block made it %d-byte %s lanes", w, rd[k], rlane & 0xff, rlane & 0x100 ? "floating-point" : "integer",
			    vlane[rd[k] & 15] & 0xff, vlane[rd[k] & 15] & 0x100 ? "floating-point" : "integer");
	if (dst >= 0 && wlane >= 0) for (int k = 0; k < nseg; k++) vlane[(dst + k) & 15] = wlane;
}

static int run_pass(int final)
{
	int changed = 0;

	final_pass = final;
	pool_seg = 0;
	cur_sec = SEC_TEXT;
	chk_pend.have = 0; nbugsite = 0;
	for (int i = 0; i < 16; i++) vlane[i] = -1;
	vwide = 0; vpend_line = 0;
	for (int k = 0; k < nchkfile; k++) free(chkfiles[k]);
	nchkfile = 0;
	for (int i = 0; i < NSEC; i++) offs[i] = 0;
	if (final) for (int i = 0; i < NSEC; i++) sec[i].n = 0;
	nrelocs = final ? 0 : nrelocs;

	int cdepth = 0, active[64], taken[64], on = 1;	/* .if / .else / .endif: nesting, whether this level is assembled, whether one arm was */
	for (int i = 0; i < nprog; i++) {
		struct stmt *st = &prog[i];
		cur_stmt = i;
		if (st->kind == S_DIR && (dir_is(st, "if") || dir_is(st, "else") || dir_is(st, "endif"))) {
			if (dir_is(st, "if")) {
				int c = 0;
				if (cdepth == 64) { if (final) err(st->line, ".if nested too deep"); continue; }
				if (on) {
					struct val v = st->nargs == 1 ? eval(st->args[0].x, st->line) : vconst(0);
					if (st->nargs != 1 || !CONST(v)) { if (final) err(st->line, ".if takes one constant expression"); }
					else c = v.c != 0;
				}
				active[cdepth] = on; taken[cdepth] = c; cdepth++;
				on = on && c;
			} else if (dir_is(st, "else")) {
				if (!cdepth) { if (final) err(st->line, ".else without .if"); continue; }
				on = active[cdepth - 1] && !taken[cdepth - 1];
				taken[cdepth - 1] = 1;
			} else {
				if (!cdepth) { if (final) err(st->line, ".endif without .if"); continue; }
				cdepth--;
				on = active[cdepth];
			}
			continue;
		}
		if (!on) continue;						/* in the arm of an .if that is not assembled */
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
			struct val v = eval(st->x, st->line);
			if (CONST(v)) { syms[k].sect = SC_ABS; syms[k].val = v.c; }
			else if (v.p >= 0 && v.m < 0 && syms[v.p].sect >= 0) { syms[k].sect = syms[v.p].sect; syms[k].val = syms[v.p].val + v.c; }
			else if (final) err(st->line, "assignment of a non-constant expression");
			break;
		}
		case S_DIR:
			directive(st);
			break;
		case S_INSN: {
			if (is_check(st)) chk_site(st, pos);					/* the table of check sites: a record for each check instruction */
			vec_typecheck(st);							/* the lane types of the vector registers in a block */
			int ch = 0, sz = enc_insn(i, pos, final, &ch);
			if (ch) changed = 1;
			if (!final) offs[cur_sec] += sz;
			break;
		}
		}
	}
	if (cdepth && final) err(nprog ? prog[nprog - 1].line : 0, ".if without .endif");
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
	struct buf file = { 0 }, strtab = { 0 }, symtab = { 0 }, rela[3] = { { 0 }, { 0 }, { 0 } }, shstr = { 0 };
	elfrec_t r;
	int nout;

	bput(&strtab, "", 1);
	bput(&shstr, "", 1);
	/* symbols: null, a section symbol for each section (the table's only if it has records: an object without it is as it always was), then the locals, then the globals */
	const int hasbug = sec[SEC_BUG].n > 0, nss = hasbug ? NSEC : NSEC - 1;
	nout = 1 + nss;
	for (int pass = 0; pass < 2; pass++)
		for (int i = 0; i < nsyms; i++) {
			struct sym *s = &syms[i];
			int isglobal = s->global || s->sect == SC_UNDEF || s->sect == SC_COMMON;
			if (s->islocal || i == dot_sym || isglobal != pass) continue;
			if (s->sect == SC_PENDING) continue;
			if (!isglobal && !(s->sect >= 0 || s->sect == SC_ABS)) continue;
			s->outidx = nout++;
		}
	int firstglobal = 1 + nss;
	for (int i = 0; i < nsyms; i++)
		if (syms[i].outidx >= 1 + nss && !(syms[i].global || syms[i].sect == SC_UNDEF || syms[i].sect == SC_COMMON) && syms[i].outidx + 1 > firstglobal)
			firstglobal = syms[i].outidx + 1;
	/* emit in index order */
	{
		memset(&r, 0, sizeof r); r.kind = 3; r.body.kind = 3;
		rec(&r, &symtab);						/* null symbol */
		for (int k = 1; k <= nss; k++) {
			memset(&r, 0, sizeof r); r.kind = 3; r.body.kind = 3;
			r.body.u.a3.y.info = 3; r.body.u.a3.y.shndx = k;
			rec(&r, &symtab);
		}
		for (int idx = 1 + nss; idx < nout; idx++)
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
		rec(&r, &rela[rl->sect == SEC_TEXT ? 0 : rl->sect == SEC_DATA ? 1 : 2]);
	}

	/* section name table */
	size_t nm_text = strtab_add(&shstr, ".text"), nm_data = strtab_add(&shstr, ".data"), nm_bss = strtab_add(&shstr, ".bss"),
	    nm_bug = hasbug ? strtab_add(&shstr, "__bug_table") : 0, nm_rb = hasbug ? strtab_add(&shstr, ".rela__bug_table") : 0,
	    nm_sym = strtab_add(&shstr, ".symtab"), nm_str = strtab_add(&shstr, ".strtab"), nm_rt = strtab_add(&shstr, ".rela.text"),
	    nm_rd = strtab_add(&shstr, ".rela.data"), nm_shs = strtab_add(&shstr, ".shstrtab");

	/* layout: ehdr, text, data, the table, symtab, strtab, rela.text, rela.data, rela of the table, shstrtab, section headers */
	uint8_t zero[64] = { 0 };
	bput(&file, zero, 64);
	size_t off_text = file.n; bput(&file, sec[SEC_TEXT].p, sec[SEC_TEXT].n); balign(&file, 8);
	size_t off_data = file.n; bput(&file, sec[SEC_DATA].p, sec[SEC_DATA].n); balign(&file, 8);
	size_t off_bug = file.n; bput(&file, sec[SEC_BUG].p, sec[SEC_BUG].n); balign(&file, 8);
	size_t off_sym = file.n; bput(&file, symtab.p, symtab.n);
	size_t off_str = file.n; bput(&file, strtab.p, strtab.n); balign(&file, 8);
	size_t off_rt = file.n; bput(&file, rela[0].p, rela[0].n);
	size_t off_rd = file.n; bput(&file, rela[1].p, rela[1].n);
	size_t off_rb = file.n; bput(&file, rela[2].p, rela[2].n);
	size_t off_shs = file.n; bput(&file, shstr.p, shstr.n); balign(&file, 8);
	size_t off_sh = file.n;

	/* the section headers: null, .text, .data, .bss, [__bug_table], .symtab, .strtab, .rela.text, .rela.data, [.rela__bug_table], .shstrtab */
	typedef struct { uint32_t name, type; uint64_t flags, addr, off, size; uint32_t link, info; uint64_t align, entsize; } shent;
	const int ix_sym = hasbug ? 5 : 4, ix_str = ix_sym + 1;
	shent sh[11]; int nsh = 0;
	sh[nsh++] = (shent){ 0 };
	sh[nsh++] = (shent){ (uint32_t)nm_text, 1, 6, 0, off_text, sec[SEC_TEXT].n, 0, 0, secalign[SEC_TEXT] > 2 ? (uint64_t)secalign[SEC_TEXT] : 2, 0 };
	sh[nsh++] = (shent){ (uint32_t)nm_data, 1, 3, 0, off_data, sec[SEC_DATA].n, 0, 0, secalign[SEC_DATA] > 8 ? (uint64_t)secalign[SEC_DATA] : 8, 0 };
	sh[nsh++] = (shent){ (uint32_t)nm_bss, 8, 3, 0, off_data, (uint64_t)offs[SEC_BSS], 0, 0, 8, 0 };
	if (hasbug) sh[nsh++] = (shent){ (uint32_t)nm_bug, 1, 2, 0, off_bug, sec[SEC_BUG].n, 0, 0, 4, 0 };		/* PROGBITS, ALLOC, read only */
	sh[nsh++] = (shent){ (uint32_t)nm_sym, 2, 0, 0, off_sym, symtab.n, (uint32_t)ix_str, (uint32_t)firstglobal, 8, 24 };
	sh[nsh++] = (shent){ (uint32_t)nm_str, 3, 0, 0, off_str, strtab.n, 0, 0, 1, 0 };
	sh[nsh++] = (shent){ (uint32_t)nm_rt, 4, 0x40, 0, off_rt, rela[0].n, (uint32_t)ix_sym, 1, 8, 24 };
	sh[nsh++] = (shent){ (uint32_t)nm_rd, 4, 0x40, 0, off_rd, rela[1].n, (uint32_t)ix_sym, 2, 8, 24 };
	if (hasbug) sh[nsh++] = (shent){ (uint32_t)nm_rb, 4, 0x40, 0, off_rb, rela[2].n, (uint32_t)ix_sym, 4, 8, 24 };
	sh[nsh++] = (shent){ (uint32_t)nm_shs, 3, 0, 0, off_shs, shstr.n, 0, 0, 1, 0 };
	for (int i = 0; i < nsh; i++) {
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
		e->type = 1; e->machine = EM_PDP64; e->version = 1; e->flags = EF_PDP64_ISA | (uint32_t)(relax_on ? EF_PDP64_RELAX : 0) | (relax_on && text_poison ? EF_PDP64_NOADJ_TEXT : 0); e->shoff = off_sh; e->ehsize = 64; e->shentsize = 64; e->shnum = (uint16_t)nsh; e->shstrndx = (uint16_t)(nsh - 1);
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
	for (int i = 0; i < NSEC && i < 8; i++) {
		char nm[16];
		snprintf(nm, sizeof nm, ".$$%d", i);
		sect_sym[i] = symadd(nm, (int)strlen(nm));
		syms[sect_sym[i]].islocal = 1; syms[sect_sym[i]].sect = i; syms[sect_sym[i]].val = 0;
	}
	/* every label is known before the first pass, so a forward reference to it is not taken for an external symbol; so are the names an assignment or a
	   .globl, global, extern or .comm gives (an extern name is in the object whether or not it is used) */
	for (int i = 0; i < nprog; i++) {
		struct stmt *st = &prog[i];
		if (st->kind == S_ASSIGN && st->name.n > 0 && st->name.p[0] != '"') symget(st->name.p, st->name.n);
		if (st->kind == S_DIR && (dir_is(st, "globl") || dir_is(st, "global") || dir_is(st, "extern") || dir_is(st, "comm")))
			for (int k = 0; k < st->nargs && (k == 0 || !dir_is(st, "comm")); k++)
				if (st->args[k].s.n > 0 && st->args[k].s.p[0] != '"' && !st->args[k].isstr) symget(st->args[k].s.p, st->args[k].s.n);
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
