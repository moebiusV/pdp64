; The end of a system call: the result and the callee-saved registers are kept, everything else is cleared by the return itself.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
sysret:	movq	r5, 0(r14)			; (the kernel may leave anything in r1 to r7 here)
	rti	#RTIMASK_SYSCALL		; r0 and r8..r11, r13, r15, r24..r31 are kept; the rest read as zero
	; a return that keeps one more register, r2 (it holds an argument the user still wants):
	rti	#(RTIMASK_SYSCALL | (1<<2))
