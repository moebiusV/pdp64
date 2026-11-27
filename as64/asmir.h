/* The statements of an assembly source, as plain C: what the generated parser (asmp.c) hands to the assembler (as64.c).
   Text is by pointer and length into the source, which outlives the statements. */
#ifndef ASMIR_H
#define ASMIR_H
#include <stddef.h>

enum stmt_kind { S_LABEL = 1, S_ASSIGN, S_DIR, S_INSN };

/* operand classes, in the order of the alternatives of `operand` in spec/pdp64-asm.hbnf */
enum oper_kind { OK_MARKED = 1, OK_IMM, OK_ABS, OK_POSTINC, OK_PREDEC, OK_PREDEC2, OK_INDEXED, OK_BASED, OK_ATINDEXED, OK_BASED2, OK_REG, OK_BARE, OK_POOL,
	OK_VREG };	/* the last is the alternative of `voperand`, not of `operand` */

#include "pdp64-groups.h"	/* enum mn_group: the mnemonic groups, in the order the generator puts them in `mnemonic` */

struct slice { const char *p; int n; };

/* An expression, as the grammar built it (asmp.c); as64.c evaluates it.  The text in tok is a slice of the source. */
enum xop {
	XN_EXPR = 1,		/* the root of an expression: a is the tree, tok the whole text (for the error message) */
	XN_NUM,			/* tok: the digits (no prefix), base 2, 8, 10 or 16 */
	XN_LBACK, XN_LFWD,	/* `Nb`, `Nf`: the numeric local label N before / after this statement; tok the digits */
	XN_CHAR, XN_MCHAR,	/* a character constant, a multi-character one: tok the text between the quotes (escapes undecoded) */
	XN_NAME,		/* a symbol: tok its text (a quoted name with its quotes) */
	XN_DOT,			/* `.`: the location counter */
	XN_MARK,		/* a value mark on a number or a symbol (`0xff.s8`, `limit.u16`): a is the value, tok the mark with its dot, base its width in bits */
	XN_BAD,			/* not an expression (`text` in backquotes where a number is wanted) */
	XN_NEG, XN_NOT, XN_LNOT, XN_LOW, XN_HIGH,		/* unary - ~ ! < >: a is the operand */
	XN_ADD, XN_SUB, XN_OR, XN_XOR, XN_ORNOT,		/* a + - | ^ ! b */
	XN_MUL, XN_DIV, XN_MOD, XN_AND, XN_SHL, XN_SHR		/* a * / % & << >> b */
};

struct xnode { int op; int base; struct slice tok; struct xnode *a, *b; };

struct oper {
	int kind;
	int reg, reg2;		/* register numbers 0..15; reg2 is the index register of OK_INDEXED */
	int mark;		/* OK_REG, from a marked operand (`r1.f32`): the format, 1 s8 .. 11 f64 (marks[] of asmp.c), -1 a mark that is no format; 0 none */
	struct slice marktext;	/* the mark as written, with its dot */
	int special;		/* OK_BASED: 0 an ordinary register, 1 pc, 2 dp */
	int scale;		/* OK_INDEXED: 1, 2, 4, 8 */
	struct xnode *x;	/* the expression: displacement, immediate, address; NULL if there is none */
};

struct darg { int isstr; struct slice s; struct xnode *x; };	/* x: the argument as an expression (NULL where it is not one: the section name) */

#define MAXOPS 6
struct stmt {
	int kind, line;
	struct slice name;			/* S_LABEL, S_ASSIGN: the symbol (a local label is digits); S_DIR: the directive */
	struct slice expr;			/* S_ASSIGN: the text */
	struct xnode *x;			/* S_ASSIGN: the expression */
	int mg, mnum;				/* S_INSN: mnemonic group and the number inside it (its encoding) */
	int srnum, srpos;			/* MG_SYSREG: the system register's number, and which operand it was (0 or 1; -1: no register name was written) */
	int nops;
	struct oper ops[MAXOPS];
	int nargs;				/* S_DIR */
	struct darg *args;			/* S_DIR: nargs of them (malloc'd; a statement used to carry room for 128, 3 KB, and a 284,000-line file needed 1.5 GB) */
};

/* Parse text into *out (malloc'd, *n entries).  Returns 0, or -1 with a message in err and the line in *errline. */
int asm_parse(const char *text, struct stmt **out, int *n, char *err, size_t errsz, int *errline);
/* the official forms of fcvt and its aliases, as a sentence for a message (asmp.c, from the rows of map-marks) */
void fcvt_forms(char *out, size_t sz);
#endif
