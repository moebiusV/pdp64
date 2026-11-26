/* asmp.c: the generated assembly parser (spec/pdp64-asm.hbnf, hbnf --ast --spans) and the walk that turns its tree into
   struct stmt.  The grammar decides what a line is; this file only reads the answer: which alternative matched, and where. */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "pdp64-asm-parser.c"
#include "pdp64-consts.h"
#include "asmir.h"

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

/* a register is its enumerator in the tree: the numbers (r10 is 10, sp is 14) are the grammar's */
/* The lexer layer in front of the generated parser: a width mark is a dot, glued to the operand before it, then `8 16 32 64`, with `u` or `s` before the number, and then no
   name character.  Its dot becomes MARKCH, which no name contains: names, numbers and registers end before it and the grammar (`mark` in 60-asm-syntax.hbnf) takes it as the mark.  A dot inside quotes, inside a
   comment, or after a blank (the `.` of a directive, a label, a name that starts with a dot) stays a dot, and so does a dot that is not followed by exactly a mark. */
#define MARKCH '\001'
static int idc_byte(int c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '$' || c >= 0x80; }
static void mark_prescan(char *l)
{
	int q = 0;
	for (char *p = l; *p; p++) {
		if (q) { if (*p == '\\' && p[1]) p++; else if (*p == q) q = 0; continue; }
		if (*p == '"' || *p == '\'' || *p == '`') { q = *p; continue; }
		if (*p == ';' || (*p == '/' && p[1] == '/')) break;
		if (*p != '.' || p == l || p[-1] == ' ' || p[-1] == '\t') continue;
		const char *k = p + 1;
		if (*k == 'u' || *k == 's') k++;
		if (!strncmp(k, "16", 2) || !strncmp(k, "32", 2) || !strncmp(k, "64", 2)) k += 2;
		else if (*k == '8') k++;
		else continue;
		if (idc_byte((unsigned char)*k)) continue;
		*p = MARKCH;
	}
}

static const char *cur_text;				/* the line being read: a register is read from its characters */
static int reg_of(const reg_t *r)
{
	const char *p = cur_text + r->_pos;
	while (*p == '%' || *p == ' ' || *p == '\t') p++;		/* %r1: the percent sign means nothing */
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

static struct xnode *digit_name(struct slice t)
{
	int n = t.n;
	char c = n > 0 ? t.p[n - 1] : 0, l = c | 0x20;
	struct slice d = t, e = t;
	d.p += 2; d.n -= 2; e.n--;
	if (digits(t.p, 0, n, 10)) return xtok(XN_NUM, 10, t);
	if (n > 2 && t.p[0] == '0') {
		int b = (t.p[1] | 0x20) == 'x' ? 16 : (t.p[1] | 0x20) == 'b' ? 2 : (t.p[1] | 0x20) == 'o' ? 8 : 0;
		if (b && digits(t.p, 2, n, b)) return xtok(XN_NUM, b, d);
	}
	if (n < 2) return NULL;
	if (l == 'h' && digits(t.p, 0, n - 1, 16)) return xtok(XN_NUM, 16, e);
	if (c == 'b' && digits(t.p, 0, n - 1, 2)) return xtok(XN_BINLBL, 2, e);
	if (c == 'B' && digits(t.p, 0, n - 1, 2)) return xtok(XN_NUM, 2, e);
	if ((l == 'q' || l == 'o') && digits(t.p, 0, n - 1, 8)) return xtok(XN_NUM, 8, e);
	if ((l == 'd' || l == 't') && digits(t.p, 0, n - 1, 10)) return xtok(XN_NUM, 10, e);
	if ((c == 'f' || c == 'b') && digits(t.p, 0, n - 1, 10)) return xtok(c == 'f' ? XN_LFWD : XN_LBACK, 10, e);
	return NULL;
}

static struct xnode *build_primary(const char *text, const primary_t *p)
{
	struct slice t = sl(text, p->_pos, p->_end), d = t;
	if (p->_alt <= 4 && (memchr(t.p, ' ', t.n) || memchr(t.p, '\t', t.n))) return xn(XN_BAD, NULL, NULL);	/* a number with a blank in it: `5 h` */
	switch (p->_alt) {
	case 1: {							/* 0x.. 0b.. 0o..: the digits after the prefix */
		static const int pb[] = { 0, 16, 2, 8 };
		d.p += 2; d.n -= 2;
		return xtok(XN_NUM, pb[p->prefixnum._alt], d);
	}
	case 2: {							/* a number with a suffix: h b q o d t */
		static const int sb[] = { 0, 16, 2, 8, 10 };
		d.n--;
		if (p->suffnum._alt == 2 && t.p[t.n - 1] == 'b') return xtok(XN_BINLBL, 2, d);
		return xtok(XN_NUM, sb[p->suffnum._alt], d);
	}
	case 3:							/* 1f, 1b */
		d.n--;
		return xtok(t.p[t.n - 1] == 'f' ? XN_LFWD : XN_LBACK, 10, d);
	case 4: return xtok(XN_NUM, 10, t);
	case 5: case 6:						/* 'c', 'abcd': the text between the quotes */
		d.p++; d.n -= 2;
		return xtok(p->_alt == 5 ? XN_CHAR : XN_MCHAR, 0, d);
	case 7: return xn(t.n == 2 ? XN_SECT : XN_DOT, NULL, NULL);
	case 8:
		if (t.n == 1 && t.p[0] == '.') return xn(XN_DOT, NULL, NULL);
		if (t.p[0] >= '0' && t.p[0] <= '9') { struct xnode *x = digit_name(t); if (x) return x; }
		return xtok(XN_NAME, 0, t);
	case 9: return xn(XN_DOT, NULL, NULL);
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
	struct xnode *x = build_primary(text, &u->primary);
	while (n > 0) x = xn(uop[(int)ops[--n]->kind - UNARY_1_OP1], x, NULL);
	return neg ? xn(XN_NEG, x, NULL) : x;
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
	st->nargs++;
}

/* The expression text of an operand, and its registers, from the text the grammar matched as that operand. */
static void operand(const char *text, const operand_t *oo, struct oper *r)
{
	const opbody_t *o = &oo->opbody;
	struct slice t = sl(text, o->_pos, o->_end);
	const char *p = t.p;
	int n = t.n;
	memset(r, 0, sizeof *r);
	r->kind = o->_alt;
	/* the width mark, glued to the end of the body: `.8 .16 .32 .64 .u8 .u16 .u32 .s8 .s16 .s32` (the grammar has accepted it; which instruction takes which is as64's table) */
	{
		struct slice m = sl(text, o->_end, oo->_end);
		if (m.n > 1 && m.p[0] == MARKCH) {
			const char *q = m.p + 1;
			r->mark = 1;
			if (*q == 'u' || *q == 's') r->msign = *q++;
			r->mwidth = atoi(q);
		}
	}
	switch (o->_alt) {
	case OK_IMM:
		r->x = expr_x(text, o->immop.expr);
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
	case OK_BASED2: {						/* base+expr, base-expr: the same as expr(base) */
		const basereg_t *br = &o->based2.basereg;
		int k = 0;
		while (k < n && p[k] != '+' && p[k] != '-') k++;
		r->kind = OK_BASED;
		if (br->_alt == 1) r->reg = reg_of(&br->reg); else r->special = (int)br->basespec;
		/* `sp-4+x` is `-4+x` after the base: the minus belongs to the first operand (and to the text of an error message) */
		r->x = xroot(build_expr(text, o->based2.expr, p[k] == '-'), (struct slice){ p[k] == '+' ? p + k + 1 : p + k, n - k - (p[k] == '+') });
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
		mark_prescan(line);
		if (!parse_text(line, &a, err, errsz, &el, &ec)) {
			for (char *c = err; *c; c++) if (*c == MARKCH) *c = '.';
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
			}
			for (struct line_2_s *s2 = ln->line_2.head; s2; s2 = s2->_link) {
				NEWSTMT();
				fill_stmt(line, &s2->stmt, st);
			}
		}
		for (int i = first; i < cnt; i++)
			v[i].line = lineno;
		ls = nl;
	}
	*out = v;
	*n = cnt;
	return 0;
}
