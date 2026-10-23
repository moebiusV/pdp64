; System v1 console: transmit a string by polling TXCS READY.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	movq	=MAP_CONSOLE, r13
	lea	msg, r1
1:	movb	(r1)+, r2
	cmp	r2, #0
	beq	3f
2:	movq	CONSOLE_REG_TXCS(r13), r3
	and	#(1<<CONSOLE_CSR_READY), r3
	beq	2b
	movq	r2, CONSOLE_REG_TXDB(r13)
	br	1b
3:	movq	#0, r0
	halt
	.data
msg:	.ascii	"Hello, pdp64 console\n\0"
