; System v1 console: transmit a string by polling TXCS READY.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	mov	=MAP_CONSOLE, r13
	lea	msg, r1
1:	mov.s8	(r1)+, r2
	cbeq r2, $0, 3f
2:	mov	CONSOLE_REG_TXCS(r13), r3
	and	$(1<<CONSOLE_CSR_READY), r3
	cbeq	r3, $0, 2b
	mov	r2, CONSOLE_REG_TXDB(r13)
	br	1b
3:	mov	$0, r0
	halt
	.data
msg:	.ascii	"Hello, pdp64 console\n\0"
