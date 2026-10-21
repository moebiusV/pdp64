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
	while (s.n > 0 && (s.p[0] == ' ' || s.p[0] == '\t')) { s.p++; s.n--; }
	while (s.n > 0 && (s.p[s.n - 1] == ' ' || s.p[s.n - 1] == '\t')) s.n--;
	return s;
}

static int regnum(const char *p, int n, int *special)
{
	*special = 0;
	if (n == 2 && p[0] == 's' && p[1] == 'p') return 14;
	if (n == 2 && p[0] == 'f' && p[1] == 'p') return 13;
	if (n == 2 && p[0] == 'p' && p[1] == 'c') { *special = 1; return 0; }
	if (n == 2 && p[0] == 'd' && p[1] == 'p') { *special = 2; return 0; }
	if (n >= 2 && n <= 3 && p[0] == 'r') {
		int v = 0;
		for (int i = 1; i < n; i++)
			v = v * 10 + (p[i] - '0');
		return v;
	}
	return 0;
}

/* The expression text of an operand, and its registers, from the text the grammar matched as that operand. */
static void operand(const char *text, const operand_t *o, struct oper *r)
{
	struct slice t = sl(text, o->_pos, o->_end);
	const char *p = t.p;
	int n = t.n, sp;
	memset(r, 0, sizeof *r);
	r->kind = o->_alt;
	switch (o->_alt) {
	case OK_IMM: case OK_ABS:
		r->e.p = p + 1; r->e.n = n - 1;
		break;
	case OK_REG:
		r->reg = regnum(p, n, &sp);
		break;
	case OK_BARE:
		r->e = t;
		break;
	case OK_POSTINC: case OK_PREDEC: case OK_PREDEC2: {		/* (r)+[expr]   -(r)   (r)-expr */
		const char *a = memchr(p, '(', n), *b = memchr(p, ')', n);
		r->reg = regnum(a + 1, (int)(b - a - 1), &sp);
		if (o->_alt != OK_PREDEC && (b + 1) < p + n) { r->e.p = b + 2; r->e.n = (int)(p + n - b - 2); }
		break;
	}
	case OK_BASED: {						/* [expr](base) */
		const char *a = memchr(p, '(', n), *b = memchr(p, ')', n);
		r->reg = regnum(a + 1, (int)(b - a - 1), &r->special);
		r->e.p = p; r->e.n = (int)(a - p);
		break;
	}
	case OK_INDEXED: {						/* [expr](base)(index[*scale]) */
		const char *a = memchr(p, '(', n), *b = memchr(a, ')', p + n - a);
		const char *c = memchr(b, '(', p + n - b), *d = memchr(c, ')', p + n - c);
		const char *star = memchr(c, '*', d - c);
		r->reg = regnum(a + 1, (int)(b - a - 1), &sp);
		r->e.p = p; r->e.n = (int)(a - p);
		r->reg2 = regnum(c + 1, (int)((star ? star : d) - c - 1), &sp);
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
	case 1:
		st->kind = S_ASSIGN;
		st->name = sl(text, s->assign.symbol._pos, s->assign.symbol._end);
		st->expr = sl(text, s->assign.expr->_pos, s->assign.expr->_end);
		break;
	case 2: {
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
				if (st->nargs < MAXARGS) {
					st->args[st->nargs].isstr = a->_alt == 1;
					st->args[st->nargs].s = sl(text, a->_pos, a->_end);
					st->nargs++;
				}
				if (!m) break;
				a = &m->darg;
				m = m->_link;
			}
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
		struct asm_list l;
		size_t el = 0, ec = 0;
		char *line = ls, *nl;
		int first = cnt;

		if (le) { *le = '\0'; nl = le + 1; } else nl = text + len + 1;
		lineno++;
		if (!parse_text(line, &l, err, errsz, &el, &ec)) {
			*errline = lineno;
			return -1;
		}
		for (struct asm_s *a = l.head; a; a = a->_link) {
			line_t *ln = &a->line;
			for (struct line_1_s *lb = ln->line_1.head; lb; lb = lb->_link) {
				NEWSTMT();
				st->kind = S_LABEL;
				st->name = sl(line, lb->label.symbol._pos, lb->label.symbol._end);
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
