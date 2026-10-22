/* The statements of an assembly source, as plain C: what the generated parser (asmp.c) hands to the assembler (as64.c).
   Text is by pointer and length into the source, which outlives the statements. */
#ifndef ASMIR_H
#define ASMIR_H
#include <stddef.h>

enum stmt_kind { S_LABEL = 1, S_ASSIGN, S_DIR, S_INSN };

/* operand classes, in the order of the alternatives of `operand` in spec/pdp64-asm.hbnf */
enum oper_kind { OK_IMM = 1, OK_ABS, OK_POSTINC, OK_PREDEC, OK_PREDEC2, OK_INDEXED, OK_BASED, OK_REG, OK_BARE, OK_POOL };

#include "pdp64-groups.h"	/* enum mn_group: the mnemonic groups, in the order the generator puts them in `mnemonic` */

struct slice { const char *p; int n; };

struct oper {
	int kind;
	int reg, reg2;		/* register numbers 0..15; reg2 is the index register of OK_INDEXED */
	int special;		/* OK_BASED: 0 an ordinary register, 1 pc, 2 dp */
	int scale;		/* OK_INDEXED: 1, 2, 4, 8 */
	struct slice e;		/* the expression: displacement, immediate, address; n == 0 if there is none */
};

struct darg { int isstr; struct slice s; };

#define MAXOPS 6
#define MAXARGS 128
struct stmt {
	int kind, line;
	struct slice name;			/* S_LABEL, S_ASSIGN: the symbol (a local label is digits); S_DIR: the directive */
	struct slice expr;			/* S_ASSIGN */
	int mg, mnum;				/* S_INSN: mnemonic group and the number inside it (its encoding) */
	int cc;					/* MG_COND: the condition word */
	int srnum, srpos;			/* MG_SYSREG: the system register's number, and which operand it was (0 or 1; -1: no register name was written) */
	int nops;
	struct oper ops[MAXOPS];
	int nargs;				/* S_DIR */
	struct darg args[MAXARGS];
};

/* Parse text into *out (malloc'd, *n entries).  Returns 0, or -1 with a message in err and the line in *errline. */
int asm_parse(const char *text, struct stmt **out, int *n, char *err, size_t errsz, int *errline);
#endif
