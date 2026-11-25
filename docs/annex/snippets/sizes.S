#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	add	r1, r2				; the common register form
	movq	(r3), r4			; a load through a register
	movq	8(r3), r4			; a load with a displacement
	cbeq	r1, r2, 1f			; compare and branch
1:	movq	=0x123456789abcdef0, r5		; a 64-bit constant from the pool
	rti	#RTIMASK_ALL
