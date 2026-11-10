/* The instruction as the executor runs it: an opcode group and sub-opcode of the numbering of spec/pdp64-mnemonics.hbnf, and the register and
   immediate fields those groups use.  The executor builds one from the decoded instruction of the table codec (common/pdp64exec_enc.inc,
   step_enc) and runs it in exec_fmt (common/pdp64exec.c); the memory-side operand is not in it (eoperand builds it from the codec's instruction). */
#ifndef FMT_H
#define FMT_H
#include <stdint.h>

enum fmt_shape {
	FS_NONE = 0,
	FS_SYSX		/* SYSX (SYS class 0 minor 15): sub (pushx 0, popx 1, isync, hint) */
};

struct fmt {
	int len, opc, reg, low;
	int shape;
	unsigned rm, rx, s, sub, t, x, count, pos, width, rd, n, imm;
	uint64_t d;
};
#endif
