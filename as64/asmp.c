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
static int reg_of(const reg_t *r)
{
	switch (r->_alt) {
	case 1: return (int)r->rnum;
	case 2: return (int)r->ralias;
	case 3: return (int)r->pctnum.rnum;		/* %r1: the percent sign means nothing */
	default: return (int)r->pctalias.ralias;
	}
}

/* The expression text of an operand, and its registers, from the text the grammar matched as that operand. */
static void operand(const char *text, const operand_t *o, struct oper *r)
{
	struct slice t = sl(text, o->_pos, o->_end);
	const char *p = t.p;
	int n = t.n;
	memset(r, 0, sizeof *r);
	r->kind = o->_alt;
	switch (o->_alt) {
	case OK_IMM: case OK_ABS: case OK_POOL:
		r->e.p = p + 1; r->e.n = n - 1;
		break;
	case OK_REG:
		r->reg = reg_of(&o->regop);
		break;
	case OK_VREG:							/* v0..v15 */
		r->reg = (int)o->vregop;
		break;
	case OK_TREG:							/* t0..t7 */
		r->reg = (int)o->tregop;
		break;
	case OK_GATHER:						/* (base)[vI]: the base register, and the index vector in reg2 */
		r->reg = reg_of(&o->gatherop.reg);
		r->reg2 = (int)o->gatherop.vnum;
		break;
	case OK_BARE:
		r->e = t;
		break;
	case OK_POSTINC: case OK_PREDEC: case OK_PREDEC2: {		/* (r)+[expr]   -(r)   (r)-expr */
		const char *b = memchr(p, ')', n);
		r->reg = reg_of(o->_alt == OK_POSTINC ? &o->postinc.reg : o->_alt == OK_PREDEC ? &o->predec.reg : &o->predec2.reg);
		if (o->_alt != OK_PREDEC && (b + 1) < p + n) { r->e.p = b + 2; r->e.n = (int)(p + n - b - 2); }
		break;
	}
	case OK_BASED: {						/* [expr](base) */
		const char *a = memchr(p, '(', n);
		const basereg_t *br = &o->based.basereg;
		if (br->_alt == 1) r->reg = reg_of(&br->reg); else r->special = (int)br->basespec;
		r->e.p = p; r->e.n = (int)(a - p);
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
		r->e.p = p; r->e.n = (int)(a - p);
		break;
	}
	case OK_BASED2: {						/* base+expr, base-expr: the same as expr(base) */
		const basereg_t *br = &o->based2.basereg;
		int k = 0;
		while (k < n && p[k] != '+' && p[k] != '-') k++;
		r->kind = OK_BASED;
		if (br->_alt == 1) r->reg = reg_of(&br->reg); else r->special = (int)br->basespec;
		r->e.p = p[k] == '+' ? p + k + 1 : p + k;
		r->e.n = n - (int)(r->e.p - p);
		break;
	}
	case OK_INDEXED: {						/* [expr](base)(index[*scale]) */
		const char *a = memchr(p, '(', n), *b = memchr(a, ')', p + n - a);
		const char *c = memchr(b, '(', p + n - b), *d = memchr(c, ')', p + n - c);
		const char *star = memchr(c, '*', d - c);
		r->reg = reg_of(&o->indexed.reg);
		r->e.p = p; r->e.n = (int)(a - p);
		r->reg2 = o->indexed._alt == 1 ? reg_of(&o->indexed.reg_2) : reg_of(&o->indexed.reg_3);	/* the two alternatives name their second register differently */
		r->scale = star ? atoi(star + 1) : 1;
		break;
	}
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
		break;
	case 6: {							/* db, dw: .byte and .word under the other assemblers' names */
		st->kind = S_DIR;
		st->name.p = s->dbdir.dbname == DBNAME_DB ? "byte" : "word";
		st->name.n = (int)strlen(st->name.p);
		for (struct dbdir_1_s *d = s->dbdir.dbdir_1.head; d; d = d->_link) {
			darg_t *a = &d->dargs.darg;
			struct dargs_1_s *m = d->dargs.dargs_1.head;
			for (;;) {
				if ((st->nargs & (st->nargs - 1)) == 0 && (st->nargs == 0 || st->nargs >= 4)) st->args = realloc(st->args, (st->nargs ? 2 * st->nargs : 4) * sizeof *st->args);
				st->args[st->nargs].s = sl(text, a->_pos, a->_end);
				st->args[st->nargs].isstr = st->args[st->nargs].s.n > 0 && st->args[st->nargs].s.p[0] == '"';
				st->nargs++;
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
				if ((st->nargs & (st->nargs - 1)) == 0 && (st->nargs == 0 || st->nargs >= 4)) st->args = realloc(st->args, (st->nargs ? 2 * st->nargs : 4) * sizeof *st->args);	/* room for 4, then doubling */
				st->args[st->nargs].s = sl(text, a->_pos, a->_end);
				st->args[st->nargs].isstr = st->args[st->nargs].s.n > 0 && st->args[st->nargs].s.p[0] == '"';
				st->nargs++;
				if (!m) break;
				a = &m->darg;
				m = m->_link;
			}
		}
		break;
	}
	case 3: {							/* an instruction that takes a condition: `set eq, r1` */
		condinsn_t *ci = &s->condinsn;
		st->kind = S_INSN;
		st->mg = MG_COND;
		st->cc = ci->ccw._alt == 1 ? (int)ci->ccw.cc : (int)ci->ccw.ccalias;
		operand(text, &ci->operand, &st->ops[st->nops++]);
		for (struct condinsn_1_s *j = ci->condinsn_1.head; j && st->nops < MAXOPS; j = j->_link)
			operand(text, &j->operand, &st->ops[st->nops++]);
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
	default: {
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
		if (!parse_text(line, &a, err, errsz, &el, &ec)) {
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
