/* asmp.c: the generated assembly parser (spec/pdp64-asm.hbnf, hbnf --ast --spans) and the walk that turns its tree into
   struct stmt.  The grammar decides what a line is; this file only reads the answer: which alternative matched, and where. */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <stdarg.h>
#include "pdp64-marks.h"
#include "pdp64-asm-parser.c"
#include "pdp64-consts.h"
#include "asmir.h"
#include "fpconv.c"

static int line_of(const char *text, size_t pos)
{
	int l = 1;
	for (size_t i = 0; i < pos; i++)
		if (text[i] == '\n')
			l++;
	return l;
}

static struct slice sl(const char *text, size_t a, size_t b)
{
	struct slice s = { text + a, (int)(b - a) };
	/* the span of a node also covers what the parser skipped after it, a comment among it: cut at the first ; outside quotes */
	{
		int q = 0;
		for (int i = 0; i < s.n; i++) {
			char c = s.p[i];
			if (q) { if (c == '\\') i++; else if (c == q) q = 0; }
			else if (c == '"' || c == '\'') q = c;
			else if (c == ';' || (c == '/' && i + 1 < s.n && s.p[i + 1] == '/')) { s.n = i; break; }
		}
	}
	while (s.n > 0 && (s.p[0] == ' ' || s.p[0] == '\t')) { s.p++; s.n--; }
	while (s.n > 0 && (s.p[s.n - 1] == ' ' || s.p[s.n - 1] == '\t')) s.n--;
	return s;
}

/* the length of the symbol that begins a slice: a quoted name to its closing quote, a plain one to a space, a tab or `=` */
static int name_len(struct slice s)
{
	int i = 0;
	if (s.n > 0 && s.p[0] == '"') {
		for (i = 1; i < s.n && s.p[i] != '"'; i++)
			;
		return i < s.n ? i + 1 : s.n;
	}
	while (i < s.n && s.p[i] != ' ' && s.p[i] != '\t' && s.p[i] != '=') i++;
	return i;
}

/* the official forms of fcvt, the source first, and the three short forms: for the messages */
void fcvt_forms(char *out, size_t sz)
{
	size_t n = snprintf(out, sz, "the forms are");
	for (const struct markrow *r = mark_rows; r->word && n < sz; r++)
		n += snprintf(out + n, sz - n, "%s fcvt r1.%s, r2.%s", r == mark_rows ? "" : ";", r->src, r->dst);
	if (n < sz) snprintf(out + n, sz - n, "; and the three short forms fcvt.s64 Rs, Rd, fcvt.u64 Rs, Rd and fcvt.s32 Rs, Rd (an integer to a float of the same width)");
}

/* a register is its enumerator in the tree: the numbers (r10 is 10, sp is 14) are the grammar's */
/* The message for a line that does not parse and starts with a mnemonic of the older notations (`movb`) or with a known word and a suffix that it does not have (`mov.s9`, `aadd.u32`,
   `fadd.f8`).  The parser says only that it expected something at the operand; here the word is looked up in the rows of spec/grammars.d/61-asm-suffixes.hbnf (build/x/pdp64-marks.h) and the message says
   what the word takes.  Returns 1 and the message in `err`, or 0 for a line that is none of these. */
static int has_row(const char *base, size_t bn, const char *tail)
{
	for (const struct surfrow *r = surface_rows; r->spell; r++)
		if (!strncmp(r->spell, base, bn) && r->spell[bn] == '.' && (!tail || !strcmp(r->spell + bn + 1, tail))) return 1;
	return 0;
}
static void list_tails(char *out, size_t sz, const char *base, size_t bn, int full)
{
	size_t n = 0;
	out[0] = 0;
	for (const struct surfrow *r = surface_rows; r->spell; r++)
		if (!strncmp(r->spell, base, bn) && r->spell[bn] == '.' && n + strlen(r->spell) + 3 < sz) n += snprintf(out + n, sz - n, "%s%s%s", n ? " " : "", full ? r->spell : ".", full ? "" : r->spell + bn + 1);
}
static int suffix_diag(const char *line, char *err, size_t errsz)
{
	const char *p = line;
	char tok[64];
	size_t n;
	for (;;) {									/* skip the labels */
		while (*p == ' ' || *p == '\t') p++;
		for (n = 0; (isalnum((unsigned char)p[n]) || p[n] == '_' || p[n] == '.' || p[n] == '$') && n < sizeof tok - 1; n++) tok[n] = p[n];
		tok[n] = 0;
		const char *q = p + n;
		while (*q == ' ' || *q == '\t') q++;
		if (n && *q == ':') { p = q + 1; continue; }
		break;
	}
	if (!n) return 0;
	for (const char *const *w = surface_withdrawn; *w; w++)
		if (!strcmp(*w, tok)) { snprintf(err, errsz, "`%s`: unknown mnemonic", tok); return 1; }
	char *dot = strchr(tok, '.');
	if (!dot) {
		return 0;
	}
	size_t bn = dot - tok;
	const char *tail = dot + 1;
	if (!has_row(tok, bn, NULL)) {
		for (const char *const *w = surface_plain; *w; w++)
			if (strlen(*w) == bn && !strncmp(*w, tok, bn)) {
				snprintf(err, errsz, "%.*s takes no width or kind suffix: it has no sibling of another width (%s is not a word)", (int)bn, tok, tok);
				return 1;
			}
		return 0;
	}
	for (const struct surfrow *r = surface_rows; r->spell; r++) if (!strcmp(r->spell, tok)) return 0;		/* an accepted word: the error is elsewhere */
	char base[40], list[1200];
	snprintf(base, sizeof base, "%.*s", (int)bn, tok);
	list_tails(list, sizeof list, tok, bn, !strncmp(tok, "fcvt.", 5));
	int isfloat = has_row(tok, bn, "f64");
	int atomic = !strcmp(base, "cas") || !strcmp(base, "swap") || !strcmp(base, "aadd") || !strcmp(base, "aand") || !strcmp(base, "abis") || !strcmp(base, "axor") || !strcmp(base, "ll") || !strcmp(base, "sc") || !strcmp(base, "amax") || !strcmp(base, "amin");
	if (!strcmp(base, "fcvt") && strchr(tail, '.')) {			/* fcvt.s32.f16: the words with two suffixes are withdrawn */
		snprintf(err, errsz, "`%s`: unknown mnemonic", tok);
		return 1;
	}
	if (!strcmp(base, "fcvt")) {
		char forms[900];
		fcvt_forms(forms, sizeof forms);
		snprintf(err, errsz, "%s: fcvt has no such suffix: a suffix is only the short form of an integer converted to a float of the same width (fcvt.s64, fcvt.u64, fcvt.s32); every other conversion names the format of each operand, directly after the register, the source first (`fcvt r1.f16, r2.f32`); %s", tok, forms);
		return 1;
	}
	if (!strcmp(tail, "f8")) snprintf(err, errsz, "%s: .f8 is no such format: there is no 8-bit floating-point format (the formats are .f16, .f32 and .f64)", tok);
	else if (isfloat && !strcmp(tail, "f16")) snprintf(err, errsz, "%s: no half-precision arithmetic: .f16 is a storage format, and only fcvt takes it (widen to .f32, operate, narrow)", tok);
	else if (isfloat && !strcmp(tail, "f32")) snprintf(err, errsz, "%s: no single-precision form: %s takes .f64 (the default) only", tok, base);
	else if (isfloat && (tail[0] == 's' || tail[0] == 'u')) snprintf(err, errsz, "%s: a floating-point word takes a floating-point format, .f32 or .f64, not the integer kind .%s", tok, tail);
	else if (!isfloat && tail[0] == 'f') snprintf(err, errsz, "%s: %s works on integers: it takes the kinds .s and .u with a width (%s), not the floating-point format .%s", tok, base, list, tail);
	else if (atomic && (!strcmp(tail, "u32") || !strcmp(tail, "s16") || !strcmp(tail, "u16") || !strcmp(tail, "s8") || !strcmp(tail, "u8")) && has_row(tok, bn, "s32")) {
		if (!strcmp(tail, "u32")) snprintf(err, errsz, "%s: the old value of a 4-byte atomic comes back sign-extended in the register, so only .s32 is true (write %s.s32, and mov.u32 Rd, Rd after it if you want it zero-extended)", tok, base);
		else snprintf(err, errsz, "%s: there is no 8-bit or 16-bit atomic: an atomic works on 4 bytes (.s32) or 8 (.s64, the default)", tok);
	} else if (!strcmp(base, "ror") && !strcmp(tail, "u32")) snprintf(err, errsz, "%s: the 32-bit rotate leaves its result sign-extended in the register, so only ror.s32 is true (mov.u32 Rd, Rd after it zero-extends)", tok);
	else if ((!strcmp(base, "div") || !strcmp(base, "mod") || !strcmp(base, "mulh")) && strstr(tail, "32")) snprintf(err, errsz, "%s: there is no 32-bit %s: convert with mov.s32 or mov.u32 first and use the 64-bit word", tok, base);
	else snprintf(err, errsz, "%s: %s has no suffix .%s; it takes %s (a bare %s is 64 bits)", tok, base, tail, list, base);
	return 1;
}

/* The message for a line that does not parse and has a sigil where it does not belong: a register after `$` or `#`, a `%` before a register, a `$` that is not the marker of an immediate (the old
   `$` for the location counter, `$$`, a `$` in an expression or in data).  Returns 1 and the message in `err`, or 0 for a line that is none of these. */
static int idch(int c) { return isalnum(c) || c == '_' || c == '.' || c == '$' || c >= 0x80; }
static int regtok_at(const char *p)
{
	int n;
	if ((p[0] == 's' || p[0] == 'f') && p[1] == 'p') n = 2;
	else if (p[0] == 'r' && isdigit((unsigned char)p[1])) {
		for (n = 1; isdigit((unsigned char)p[n]); n++) ;
		if (atoi(p + 1) > 31) return 0;
	} else return 0;
	return idch((unsigned char)p[n]) ? 0 : n;
}
static int sigil_diag(const char *line, char *err, size_t errsz)
{
	size_t len = strlen(line), i = 0, ms, me;
	int q = 0;
	for (;;) {									/* the mnemonic: the first word after the labels */
		while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
		ms = i;
		while (i < len && line[i] != ' ' && line[i] != '\t') i++;
		me = i;
		if (me > ms && line[me - 1] == ':') continue;
		break;
	}
	for (i = 0; i < len; i++) {
		char c = line[i];
		if (q) { if (c == q) q = 0; else if (c == '\\' && q != '\'') i++; continue; }
		if (c == '"' || c == '\'' || c == '`') { q = c; continue; }
		if (c == ';' || (c == '/' && line[i + 1] == '/')) break;
		if (c != '$' && c != '#' && c != '%') continue;
		if (i > 0 && (idch((unsigned char)line[i - 1]) || (c == '$' && line[i - 1] == '$'))) continue;	/* inside a name; the second of `$$` is reported with the first */
		size_t k = i + 1;
		while (k < len && (line[k] == ' ' || line[k] == '\t') && c != '%') k++;
		int rn = regtok_at(line + k);
		if (rn) {
			if (c == '%' && i > 0 && line[i - 1] == ')') continue;
			snprintf(err, errsz, "a register is written without a sigil: write %.*s, not %c%.*s", rn, line + k, c, (int)(k - i - 1) + rn, line + i + 1);
			return 1;
		}
		if (c != '$') continue;
		if (line[i + 1] == '$') {
			snprintf(err, errsz, "`$$` is not a symbol: the start of a section is a label (`$` marks an immediate: `$5`, `$name`)");
			return 1;
		}
		char nx = line[k];
		if (!(isalnum((unsigned char)nx) || nx == '_' || nx == '.' || nx == '(' || nx == '[' || nx == '\'' || nx == '"' || nx == '`' || nx == '-' || nx == '~' || nx == '!' || nx == '<' || nx == '>' || (unsigned char)nx >= 0x80)) {
			snprintf(err, errsz, "a `$` alone is not the location counter, which is `.`: `$` marks an immediate (`$5`, `$name`)");
			return 1;
		}
		size_t p = i;
		while (p > 0 && (line[p - 1] == ' ' || line[p - 1] == '\t')) p--;
		if (!(p > 0 && (line[p - 1] == ',' || (p == me && me > ms)))) {
			snprintf(err, errsz, "a `$` marks an immediate and stands at the start of an operand; it is no operator and no part of an expression (a name may contain `$` after its first character, and a name that begins with one is written in double quotes)");
			return 1;
		}
		if (line[ms] == '.' || !strncmp(line + ms, "db", 2) || !strncmp(line + ms, "dw", 2) || !strncmp(line + ms, "dd", 2) || !strncmp(line + ms, "dq", 2) || !strncmp(line + ms, "times", 5)
		    || !strncmp(line + ms, "DB", 2) || !strncmp(line + ms, "DW", 2) || !strncmp(line + ms, "DD", 2) || !strncmp(line + ms, "DQ", 2) || !strncmp(line + ms, "TIMES", 5)) {
			snprintf(err, errsz, "a `$` marks the immediate operand of an instruction: it has no place in data (write the expression itself)");
			return 1;
		}
	}
	return 0;
}

static const char *cur_text;				/* the line being read: a register is read from its characters */
static int reg_of(const reg_t *r)
{
	const char *p = cur_text + r->_pos;
	while (*p == ' ' || *p == '\t') p++;
	if ((*p | 0x20) == 's') return 14;			/* sp */
	if ((*p | 0x20) == 'f') return 13;			/* fp */
	return atoi(p + 1);					/* r0..r31 */
}


/* ---- the expression tree: struct xnode from the grammar's expr, term, unary and primary ---- */

static struct xnode *xn(int op, struct xnode *a, struct xnode *b)
{
	struct xnode *x = calloc(1, sizeof *x);
	x->op = op; x->a = a; x->b = b;
	return x;
}

static struct xnode *xtok(int op, int base, struct slice t)
{
	struct xnode *x = xn(op, NULL, NULL);
	x->base = base; x->tok = t;
	return x;
}

static struct xnode *xroot(struct xnode *a, struct slice src)
{
	struct xnode *x = xn(XN_EXPR, a, NULL);
	x->tok = src;
	return x;
}

static struct xnode *build_expr(const char *text, const expr_t *e, int neg);
static void lex_fail(const char *fmt, ...);

/* `$sp` and `$fp` parse as the immediate of a symbol of that name (`$r1` does not parse at all: sigil_diag); a register is no constant */
static void reg_in_imm(const struct xnode *x)
{
	if (!x) return;
	if (x->op == XN_NAME && x->tok.n == 2 && ((x->tok.p[0] == 's' && x->tok.p[1] == 'p') || (x->tok.p[0] == 'f' && x->tok.p[1] == 'p')))
		lex_fail("a register is written without a sigil: write %.2s, not $%.2s (a register is not a constant)", x->tok.p, x->tok.p);
	reg_in_imm(x->a); reg_in_imm(x->b);
}

/* The grammar's `!idchar` after a number skips blanks first, so in `times 5 db 0` it sees the `d` of `db` and the 5 falls through to `symbol`.  (The
   `5 h` the same skipping lets into a suffix is refused in build_primary.)  A name that is all digits for some base is that number: the one place
   the tree is read twice, until the grammar can say "adjacent".  digits() is whether every character of s[a..b) is a digit of the base. */
static int digits(const char *s, int a, int b, int base)
{
	if (a >= b) return 0;
	for (int i = a; i < b; i++) {
		int c = (unsigned char)s[i], d = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : 99;
		if (d >= base) return 0;
	}
	return 1;
}

/* a lexical error with its own message (the walk of the tree has no way to return one): the line is refused with it */
static const char *lex_err;
static char lex_msg[400];
static void lex_fail(const char *fmt, ...)
{
	va_list ap;
	if (lex_err) return;						/* the first one is the one reported */
	va_start(ap, fmt);
	vsnprintf(lex_msg, sizeof lex_msg, fmt, ap);
	va_end(ap);
	lex_err = lex_msg;
}

/* A value mark ends a name or a number: `.s8 .u8 .s16 .u16 .s32 .u32 .s64 .u64` and `.f8 .f16 .f32 .f64`, behind something (`limit.u16`, `0xff.s8`).  Returns the length of the mark with its dot, or 0.
   The grammar has no rule for it: a name may contain dots and digits, so the mark is cut off here, and a name that ends in one is reserved (check_reserved). */
static int vmark_at(struct slice t)
{
	for (int len = 3; len <= 4; len++) {
		if (t.n <= len || t.p[t.n - len] != '.') continue;
		char k = t.p[t.n - len + 1];
		if (k != 's' && k != 'u' && k != 'f') continue;
		const char *w = t.p + t.n - len + 2;
		if (len == 3 ? !strncmp(w, "8", 1) : (!strncmp(w, "16", 2) || !strncmp(w, "32", 2) || !strncmp(w, "64", 2))) return len;
	}
	return 0;
}

/* the name of a label, an assignment, a procedure or a global: a name that ends in a value mark cannot be defined (a quoted name can) */
static void check_reserved(struct slice n)
{
	int m;
	if (n.n > 0 && n.p[0] == '"') return;
	if (n.n == 3 && n.p[0] == 'f' && (!memcmp(n.p + 1, "16", 2) || !memcmp(n.p + 1, "32", 2) || !memcmp(n.p + 1, "64", 2)))
		lex_fail("`%.*s` cannot be a name: it is the functional form of a floating-point constant, `%.*s(1.5)` (write another name, or put it in double quotes)", n.n, n.p, n.n, n.p);
	else if ((m = vmark_at(n)) != 0)
		lex_fail("`%.*s` cannot be a name: a name that ends in a value mark (%.*s) is reserved, because `%.*s%.*s` is the value of %.*s read as %.*s bits (write another name, or put it in double quotes)",
			n.n, n.p, m, n.p + n.n - m, n.n - m, n.p, m, n.p + n.n - m, n.n - m, n.p, m - 2, n.p + n.n - m + 2);
}

static struct xnode *digit_name(struct slice t)
{
	int n = t.n;
	char c = n > 0 ? t.p[n - 1] : 0, l = c | 0x20;
	struct slice d = t, e = t;
	d.p += 2; d.n -= 2; e.n--;
	if (digits(t.p, 0, n, 10)) {
		if (n > 1 && t.p[0] == '0') lex_fail("a number with a leading zero: write 0o for octal (%.*s is written 0o%.*s, or %.*s without the zero for a decimal number)", n, t.p, n - 1, t.p + 1, n - 1, t.p + 1);
		return xtok(XN_NUM, 10, t);
	}
	if (n > 2 && t.p[0] == '0') {
		char p = t.p[1];
		int b = p == 'x' ? 16 : p == 'b' ? 2 : p == 'o' ? 8 : 0, B = p == 'X' ? 16 : p == 'B' ? 2 : p == 'O' ? 8 : 0;
		if (b && digits(t.p, 2, n, b)) return xtok(XN_NUM, b, d);
		if (B && digits(t.p, 2, n, B)) lex_fail("an uppercase number prefix: write 0%c%.*s", p | 0x20, n - 2, t.p + 2);
	}
	if (n < 2) return NULL;
	if ((c == 'f' || c == 'b') && digits(t.p, 0, n - 1, 10)) return xtok(c == 'f' ? XN_LFWD : XN_LBACK, 10, e);	/* 1f, 1b, 10b: a local label */
	if (l == 'h' && digits(t.p, 0, n - 1, 16)) {
		int z = 0;
		while (z < n - 2 && t.p[z] == '0') z++;				/* 0FFh: the 0 only keeps the word from being a name */
		lex_fail("a number with a suffix: write 0x%.*s", n - 1 - z, t.p + z);
	}
	else if (c == 'B' && digits(t.p, 0, n - 1, 2)) lex_fail("a number with a suffix: write 0b%.*s", n - 1, t.p);
	else if ((l == 'q' || l == 'o') && digits(t.p, 0, n - 1, 8)) lex_fail("a number with a suffix: write 0o%.*s", n - 1, t.p);
	else if ((l == 'd' || l == 't') && digits(t.p, 0, n - 1, 10)) lex_fail("a number with a suffix: write %.*s (a decimal number has none)", n - 1, t.p);
	return NULL;
}

/* a symbol's token, or the word of a number the grammar did not take whole: a number, a local label, or a name */
static struct xnode *word_x(struct slice t)
{
	if (t.n == 1 && t.p[0] == '.') return xn(XN_DOT, NULL, NULL);
	if (t.p[0] >= '0' && t.p[0] <= '9') { struct xnode *x = digit_name(t); if (x) return x; }
	return xtok(XN_NAME, 0, t);
}

static struct xnode *build_primary(const char *text, const primary_t *p)
{
	struct slice t = sl(text, p->_pos, p->_end), d = t;
	if ((p->_alt <= 3) && (memchr(t.p, ' ', t.n) || memchr(t.p, '\t', t.n))) return xn(XN_BAD, NULL, NULL);	/* a number with a blank in it: `5 h` */
	switch (p->_alt) {
	case 1: {							/* 0x.. 0b.. 0o..: the digits after the prefix */
		static const int pb[] = { 0, 16, 2, 8 };
		d.p += 2; d.n -= 2;
		return xtok(XN_NUM, pb[p->prefixnum._alt], d);
	}
	case 2:							/* 1f, 1b */
		d.n--;
		return xtok(t.p[t.n - 1] == 'f' ? XN_LFWD : XN_LBACK, 10, d);
	case 3:
		if (t.n > 1 && t.p[0] == '0') lex_fail("a number with a leading zero: write 0o for octal (%.*s is written 0o%.*s, or %.*s without the zero for a decimal number)", t.n, t.p, t.n - 1, t.p + 1, t.n - 1, t.p + 1);
		return xtok(XN_NUM, 10, t);
	case 4: case 5:						/* 'c', 'abcd': the text between the quotes */
		d.p++; d.n -= 2;
		return xtok(p->_alt == 4 ? XN_CHAR : XN_MCHAR, 0, d);
	case 6: {							/* f16(x), f32(x), f64(x), and a value mark after it */
		const char *lp = memchr(t.p, '(', t.n), *rp = lp;
		for (int dep = 0; rp < t.p + t.n; rp++) { if (*rp == '(') dep++; else if (*rp == ')' && --dep == 0) break; }
		int w = (t.p[1] - '0') * 10 + (t.p[2] - '0');
		uint64_t bits = 0;
		const char *why = NULL;
		if (lp != t.p + 3) lex_fail("f%d is followed by its parenthesis with no blank: write f%d(1.5)", w, w);
		else if (fp_const(w, lp + 1, rp - lp - 1, &bits, &why)) lex_fail("f%d(%.*s): %s", w, (int)(rp - lp - 1), lp + 1, why);
		struct xnode *x = xn(XN_CONST, NULL, NULL);
		x->c = bits;
		if (rp + 1 < t.p + t.n) {
			struct slice mk = { rp + 1, (int)(t.p + t.n - rp - 1) };
			if (mk.p[0] != '.') { lex_fail("a blank between f%d(...) and its value mark: write f%d(1.5).s64", w, w); return x; }
			struct xnode *m = xn(XN_MARK, x, NULL);
			m->tok = mk; m->base = atoi(mk.p + 2);
			return m;
		}
		return x;
	}
	case 7: {							/* a symbol; or a word that starts with a digit and is a number the grammar did not take whole; either may end in a value mark */
		int m = t.p[0] == '"' ? 0 : vmark_at(t);
		if (m) {
			struct slice b = t;
			b.n -= m;
			struct xnode *x = xn(XN_MARK, word_x(b), NULL);
			x->tok.p = t.p + t.n - m; x->tok.n = m; x->base = atoi(x->tok.p + 2);
			return x;
		}
		return word_x(t);
	}
	case 8: return xn(XN_DOT, NULL, NULL);
	default: return build_expr(text, &p->expr, 0);		/* ( expr ) and [ expr ] group */
	}
}

/* neg: the expression is written after a minus the operand text carried (`sp-4`): it applies to the first unary operand, as `-4+x` reads */
static struct xnode *build_unary(const char *text, const unary_t *u, int neg)
{
	static const int uop[] = { XN_NEG, XN_NOT, XN_LNOT, XN_LOW, XN_HIGH };
	const struct unary_1_s *ops[64];
	int n = 0;
	for (const struct unary_1_s *o = u->unary_1.head; o && n < 64; o = o->_link) ops[n++] = o;
	struct xnode *x = build_primary(text, &u->primary), *mark = NULL;
	if (x->op == XN_MARK && (n > 0 || neg)) { mark = x; x = x->a; }	/* `-1.u8`: the mark is of the number with its sign, 255 */
	while (n > 0) x = xn(uop[(int)ops[--n]->kind - UNARY_1_OP1], x, NULL);
	if (neg) x = xn(XN_NEG, x, NULL);
	if (mark) { mark->a = x; x = mark; }
	return x;
}

static struct xnode *build_term(const char *text, const term_t *t, int neg)
{
	static const int mop[] = { XN_MUL, XN_DIV, XN_MOD, XN_AND, XN_SHL, XN_SHR };
	struct xnode *x = build_unary(text, &t->unary, neg);
	for (const struct term_1_s *i = t->term_1.head; i; i = i->_link)
		x = xn(mop[(int)i->mulop - MULOP_OP1], x, build_unary(text, &i->unary, 0));
	return x;
}

static struct xnode *build_expr(const char *text, const expr_t *e, int neg)
{
	static const int aop[] = { XN_ADD, XN_SUB, XN_OR, XN_XOR, XN_ORNOT };
	struct xnode *x = build_term(text, e->term, neg);
	for (const struct expr_1_s *i = e->expr_1.head; i; i = i->_link)
		x = xn(aop[(int)i->addop - ADDOP_OP1], x, build_term(text, &i->term, 0));
	return x;
}

static struct xnode *expr_x(const char *text, const expr_t *e)
{
	return xroot(build_expr(text, e, 0), sl(text, e->_pos, e->_end));
}

/* a directive's argument as an expression: where a string is written, a "quoted name" is a symbol, 'ab' a character constant and `ab` nothing */
static struct xnode *darg_x(const char *text, const darg_t *a)
{
	struct slice t = sl(text, a->_pos, a->_end);
	switch (a->_alt) {
	case 1: return xroot(xtok(XN_NAME, 0, t), t);
	case 2: return xroot(xn(XN_BAD, NULL, NULL), t);
	case 3: { struct slice d = { t.p + 1, t.n - 2 }; return xroot(xtok(XN_MCHAR, 0, d), t); }
	default: return expr_x(text, a->expr);
	}
}

static void put_darg(const char *text, struct stmt *st, const darg_t *a)
{
	if ((st->nargs & (st->nargs - 1)) == 0 && (st->nargs == 0 || st->nargs >= 4)) st->args = realloc(st->args, (st->nargs ? 2 * st->nargs : 4) * sizeof *st->args);	/* room for 4, then doubling */
	st->args[st->nargs].s = sl(text, a->_pos, a->_end);
	st->args[st->nargs].isstr = a->_alt >= 1 && a->_alt <= 3;		/* "text", `text` and 'text' (two or more characters) are strings */
	st->args[st->nargs].x = darg_x(text, a);
	{								/* the names a directive declares cannot end in a value mark either */
		static const char *const decl[] = { "globl", "global", "extern", "comm" };
		for (int k = 0; k < 4; k++)
			if (st->name.n == (int)strlen(decl[k]) && !memcmp(st->name.p, decl[k], st->name.n) && (k < 3 || st->nargs == 0)) check_reserved(st->args[st->nargs].s);
	}
	st->nargs++;
}

/* The expression text of an operand, and its registers, from the text the grammar matched as that operand. */
static void operand(const char *text, const operand_t *oo, struct oper *r)
{
	const opbody_t *o = oo;
	struct slice t = sl(text, o->_pos, o->_end);
	const char *p = t.p;
	int n = t.n;
	memset(r, 0, sizeof *r);
	r->kind = o->_alt;
	switch (o->_alt) {
	case OK_MARKED: {						/* r1.f32: a register and the mark of its format (a token of the grammar: not a name that merely looks like it) */
		static const char *const fm[] = { "s8", "u8", "s16", "u16", "s32", "u32", "s64", "u64", "f16", "f32", "f64" };
		const char *dot = memchr(p, '.', n);
		r->kind = OK_REG;
		{
			const char *q = p;
			r->reg = (*q | 0x20) == 's' ? 14 : (*q | 0x20) == 'f' ? 13 : atoi(q + 1);
		}
		r->marktext.p = dot;
		r->marktext.n = (int)(p + n - dot);
		r->mark = -1;
		for (int k = 0; k < 11; k++)
			if ((int)strlen(fm[k]) == r->marktext.n - 1 && !memcmp(fm[k], dot + 1, r->marktext.n - 1)) r->mark = k + 1;
		break;
	}
	case OK_IMM:
		r->x = expr_x(text, o->immop.expr);
		reg_in_imm(r->x);
		break;
	case OK_ABS:
		r->x = expr_x(text, o->absop.expr);
		break;
	case OK_POOL:
		r->x = expr_x(text, o->poolop.expr);
		break;
	case OK_REG:
		r->reg = reg_of(&o->regop);
		break;
	case OK_BARE:
		r->x = expr_x(text, o->bare);
		break;
	case OK_POSTINC: case OK_PREDEC: case OK_PREDEC2: {		/* (r)+[expr]   -(r)   (r)-expr */
		r->reg = reg_of(o->_alt == OK_POSTINC ? &o->postinc.reg : o->_alt == OK_PREDEC ? &o->predec.reg : &o->predec2.reg);
		if (o->_alt == OK_POSTINC && o->postinc.postinc_1.head) r->x = expr_x(text, &o->postinc.postinc_1.head->expr);
		else if (o->_alt == OK_PREDEC2) r->x = expr_x(text, o->predec2.expr);
		break;
	}
	case OK_BASED: {						/* [expr](base) */
		const basereg_t *br = &o->based.basereg;
		if (br->_alt == 1) r->reg = reg_of(&br->reg); else r->special = (int)br->basespec;
		if (o->based._alt == 2) r->x = expr_x(text, o->based.expr);
		break;
	}
	case OK_ATINDEXED: {						/* AT&T: [expr](base,index[,scale]) */
		const char *a = p + n - 1, *cl;
		while (a > p && *a != '(') a--;
		cl = memchr(a, ')', p + n - a);
		const char *c1 = memchr(a, ',', cl - a), *c2 = c1 ? memchr(c1 + 1, ',', cl - c1 - 1) : NULL;
		r->kind = OK_INDEXED;
		r->reg = reg_of(&o->atindexed.reg);
		r->reg2 = reg_of(o->atindexed._alt == 1 ? (const reg_t *)&o->atindexed.reg_4 : (const reg_t *)&o->atindexed.reg_5);
		r->scale = c2 ? atoi(c2 + 1) : 1;
		if (o->atindexed._alt == 2) r->x = expr_x(text, o->atindexed.expr);
		break;
	}
	case OK_BASED2: {						/* base+expr, base-expr: refused; the only spelling of a displacement is expr(base) */
		int k = 0;
		while (k < n && p[k] != '+' && p[k] != '-') k++;
		if (k < n) {
			const char *rest = p + k + 1;
			int rn = n - k - 1, bk = k;
			while (rn > 0 && (*rest == ' ' || *rest == '\t')) { rest++; rn--; }
			while (bk > 0 && (p[bk - 1] == ' ' || p[bk - 1] == '\t')) bk--;
			int special = bk == 2 && (!memcmp(p, "pc", 2) || !memcmp(p, "dp", 2));
			if (special) lex_fail("`%.*s` is not accepted: the only spelling of a displacement is expr(base), here `%s%.*s(%.*s)`", n, p, p[k] == '-' ? "-" : "", rn, rest, bk, p);
			else lex_fail("`%.*s` is not accepted: the only spelling of a displacement is expr(base), here `%s%.*s(%.*s)`; (%.*s)%c%.*s is a different operand, which changes the register",
				n, p, p[k] == '-' ? "-" : "", rn, rest, bk, p, bk, p, p[k], rn, rest);
		}
		r->kind = OK_BASED;
		r->reg = 0;
		r->x = NULL;
		break;
	}
	case OK_INDEXED: {						/* [expr](base)(index[*scale]) */
		const char *a = memchr(p, '(', n), *b = memchr(a, ')', p + n - a);
		const char *c = memchr(b, '(', p + n - b), *d = memchr(c, ')', p + n - c);
		const char *star = memchr(c, '*', d - c);
		r->reg = reg_of(&o->indexed.reg);
		if (o->indexed._alt == 2) r->x = expr_x(text, o->indexed.expr);
		r->reg2 = o->indexed._alt == 1 ? reg_of(&o->indexed.reg_2) : reg_of(&o->indexed.reg_3);	/* the two alternatives name their second register differently */
		r->scale = star ? atoi(star + 1) : 1;
		break;
	}
	}
}

/* An operand of a vector instruction: a vector register, or any operand there is */
static void voperand(const char *text, const voperand_t *o, struct oper *r)
{
	switch (o->_alt) {
	case 1: memset(r, 0, sizeof *r); r->kind = OK_VREG; r->reg = (int)o->vregop; break;			/* v0..v15 */
	default: operand(text, &o->operand, r);
	}
}

#define NEWSTMT() (st = grow(&v, &cnt, &cap))

static struct stmt *grow(struct stmt **v, int *cnt, int *cap)
{
	if (*cnt == *cap) {
		*cap = *cap ? *cap * 2 : 256;
		*v = realloc(*v, *cap * sizeof **v);
	}
	memset(&(*v)[*cnt], 0, sizeof **v);
	return &(*v)[(*cnt)++];
}

static void fill_stmt(const char *text, stmt_t *s, struct stmt *st)
{
	st->line = line_of(text, s->_pos);
	switch (s->_alt) {
	case 5:
		st->kind = S_ASSIGN;
		{
			struct slice a = sl(text, s->assign._pos, s->assign._end);	/* name = expression, name equ expression */
			st->name = a;
			st->name.n = name_len(a);
			check_reserved(st->name);
		}
		st->expr = sl(text, s->assign.expr->_pos, s->assign.expr->_end);
		st->x = expr_x(text, s->assign.expr);
		break;
	case 6: {							/* db, dw: .byte and .word under the other assemblers' names */
		st->kind = S_DIR;
		st->name.p = ((int)s->dbdir.dbname % 4) == 0 ? "byte" : ((int)s->dbdir.dbname % 4) == 1 ? "word" : ((int)s->dbdir.dbname % 4) == 2 ? "long" : "quad";	/* db dw dd dq, in either case */
		st->name.n = (int)strlen(st->name.p);
		for (struct dbdir_1_s *d = s->dbdir.dbdir_1.head; d; d = d->_link) {
			darg_t *a = &d->dargs.darg;
			struct dargs_1_s *m = d->dargs.dargs_1.head;
			for (;;) {
				put_darg(text, st, a);
				if (!m) break;
				a = &m->darg;
				m = m->_link;
			}
		}
		break;
	}
	case 7:								/* name proc: the label name */
		st->kind = S_LABEL;
		st->name = sl(text, s->procdir._pos, s->procdir._end);
		st->name.n = name_len(st->name);
		check_reserved(st->name);
		break;
	case 8:								/* name endp: nothing */
		st->kind = S_DIR;
		st->name.p = "endp";
		st->name.n = 4;
		break;
	case 1: {
		st->kind = S_DIR;
		{
			struct slice d = sl(text, s->directive._pos, s->directive._end);	/* ".name args" */
			int k = 1;
			while (k < d.n && d.p[k] != ' ' && d.p[k] != '\t') k++;
			st->name.p = d.p + 1;
			st->name.n = k - 1;
		}
		for (struct directive_1_s *d = s->directive.directive_1.head; d; d = d->_link) {
			darg_t *a = &d->dargs.darg;
			struct dargs_1_s *m = d->dargs.dargs_1.head;
			for (;;) {
				put_darg(text, st, a);
				if (!m) break;
				a = &m->darg;
				m = m->_link;
			}
		}
		break;
	}
	case 9: {							/* NASM's global, extern, bits, default, cpu, align, alignb, resb..resq: the directive without the dot */
		st->kind = S_DIR;
		{
			static const char *const nn[] = { "global", "extern", "bits", "default", "cpu", "align", "alignb", "resb", "resw", "resd", "resq" };
			st->name.p = nn[(int)s->nasmdir.nname % 11];			/* the word in either case (the upper-case spellings are the second half of the enumeration) */
			st->name.n = (int)strlen(st->name.p);
		}
		for (struct nasmdir_1_s *d = s->nasmdir.nasmdir_1.head; d; d = d->_link) {
			darg_t *a = &d->dargs.darg;
			struct dargs_1_s *m = d->dargs.dargs_1.head;
			for (;;) {
				put_darg(text, st, a);
				if (!m) break;
				a = &m->darg;
				m = m->_link;
			}
		}
		break;
	}
	case 10: {							/* section .text | segment .data: the section's name is the one argument (options after it are ignored) */
		struct slice d = sl(text, s->secdir._pos, s->secdir._end);
		int k = 0;
		while (k < d.n && d.p[k] != ' ' && d.p[k] != '\t') k++;
		while (k < d.n && (d.p[k] == ' ' || d.p[k] == '\t')) k++;
		int e = k;
		while (e < d.n && d.p[e] != ' ' && d.p[e] != '\t') e++;
		st->kind = S_DIR;
		st->name.p = "section"; st->name.n = 7;
		st->args = malloc(4 * sizeof *st->args);
		st->args[0].s.p = d.p + k; st->args[0].s.n = e - k; st->args[0].isstr = 0; st->args[0].x = NULL;
		st->nargs = 1;
		break;
	}
	case 11: {							/* times n db|dw|dd|dq v: .fill n, size, v */
		static const char *const sz[] = { "1", "2", "4", "8" };
		st->kind = S_DIR;
		st->name.p = "fill"; st->name.n = 4;
		st->args = malloc(4 * sizeof *st->args);
		st->args[0].s = sl(text, s->timesdir.expr->_pos, s->timesdir.expr->_end); st->args[0].isstr = 0;
		st->args[0].x = expr_x(text, s->timesdir.expr);
		st->args[1].s.p = sz[(int)s->timesdir.tdata % 4]; st->args[1].s.n = 1; st->args[1].isstr = 0;
		st->args[1].x = xroot(xtok(XN_NUM, 10, st->args[1].s), st->args[1].s);
		st->args[2].s = sl(text, s->timesdir.darg._pos, s->timesdir.darg._end); st->args[2].isstr = 0;
		st->args[2].x = darg_x(text, &s->timesdir.darg);
		st->nargs = 3;
		break;
	}
	case 2: {							/* a vector instruction: it may name v0..v15, t0..t7 and `(base)[vI]` */
		st->kind = S_INSN;
		mnemonic_t *m = &s->vecinsn.mnemonic;
		st->mg = m->_alt;
		MNEMONIC_NUMBER(m, st->mnum);
		for (struct vecinsn_1_s *i = s->vecinsn.vecinsn_1.head; i; i = i->_link) {
			voperand(text, &i->voperand, &st->ops[st->nops++]);
			for (struct vecinsn_1_1_s *j = i->vecinsn_1_1.head; j && st->nops < MAXOPS; j = j->_link)
				voperand(text, &j->voperand, &st->ops[st->nops++]);
		}
		break;
	}
	case 4: {							/* mfsr rd, name; mtsr name, rs */
		srinsn_t *si = &s->srinsn;
		st->kind = S_INSN;
		st->mg = MG_SYSREG;
		st->mnum = (int)si->mn_sysreg;
		st->srpos = -1;
		if (si->srinsn_1._alt == 1) {
			st->srnum = (int)si->srinsn_1.sysregw; st->srpos = 0;
			st->nops = 1;					/* ops[0] is the name's place and stays empty */
			operand(text, &si->srinsn_1.operand, &st->ops[st->nops++]);
		} else if (si->srinsn_1._alt == 2) {
			st->srnum = (int)si->srinsn_1.sysregw; st->srpos = 1;
			operand(text, &si->srinsn_1.operand, &st->ops[st->nops++]);
			st->nops = 2;
		} else {
			operand(text, &si->srinsn_1.operand, &st->ops[st->nops++]);
			for (struct srinsn_1_1_s *j = si->srinsn_1.srinsn_1_1.head; j && st->nops < MAXOPS; j = j->_link)
				operand(text, &j->operand, &st->ops[st->nops++]);
		}
		break;
	}
	case 3: {							/* an ordinary instruction */
		st->kind = S_INSN;
		mnemonic_t *m = &s->instruction.mnemonic;
		st->mg = m->_alt;
		MNEMONIC_NUMBER(m, st->mnum);
		for (struct instruction_1_s *i = s->instruction.instruction_1.head; i; i = i->_link) {
			operand(text, &i->operand, &st->ops[st->nops++]);
			for (struct instruction_1_1_s *j = i->instruction_1_1.head; j && st->nops < MAXOPS; j = j->_link)
				operand(text, &j->operand, &st->ops[st->nops++]);
		}
		break;
	}
	}
}

/* One line at a time: the generated spans count from the start of the statement being parsed, so each line is parsed
   from its own start.  The text is copied once with every newline made a NUL, and the slices point into that copy. */
int asm_parse(const char *src, struct stmt **out, int *n, char *err, size_t errsz, int *errline)
{
	size_t len = strlen(src);
	char *text = malloc(len + 2);
	struct stmt *v = NULL, *st;
	int cnt = 0, cap = 0, lineno = 0;

	memcpy(text, src, len + 1);
	for (char *ls = text; ls <= text + len; ) {
		char *le = memchr(ls, '\n', text + len - ls + 1);
		asm_t a;				/* the root is one line: asm_t is line_t */
		size_t el = 0, ec = 0;
		char *line = ls, *nl;
		int first = cnt;

		if (le) { *le = '\0'; nl = le + 1; } else nl = text + len + 1;
		lineno++;
		cur_text = line;
		lex_err = NULL;
		if (!parse_text(line, &a, err, errsz, &el, &ec)) {
			if (!sigil_diag(line, err, errsz)) suffix_diag(line, err, errsz);
			*errline = lineno;
			return -1;
		}
		{
			line_t *ln = &a;
			for (struct line_1_s *lb = ln->line_1.head; lb; lb = lb->_link) {
				NEWSTMT();
				st->kind = S_LABEL;
				st->name = sl(line, lb->_pos, lb->_end);
				while (st->name.n > 0 && st->name.p[st->name.n - 1] == ':') st->name.n--;
				check_reserved(st->name);
			}
			for (struct line_2_s *s2 = ln->line_2.head; s2; s2 = s2->_link) {
				NEWSTMT();
				fill_stmt(line, &s2->stmt, st);
			}
		}
		if (lex_err) { snprintf(err, errsz, "%s", lex_err); *errline = lineno; return -1; }
		for (int i = first; i < cnt; i++)
			v[i].line = lineno;
		ls = nl;
	}
	*out = v;
	*n = cnt;
	return 0;
}
