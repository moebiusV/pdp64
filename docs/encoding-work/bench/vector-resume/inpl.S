#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0x800ff0, r1
	movq	r1, r3
	add	#32, r3
	vec	r1, r3
HIDDEN	vclr.l	v4, #1
	vld.l	v0, 0(r1)
	vadd.l	v1, v0, #1
HIDDEN	vadd.l	v4, v4, v1
	vst.l	v1, (r1)+
	vend
	; r0 = number of lanes (of 8) that differ from 1
	movq	#0x800ff0, r1
	movq	#8, r3
	movq	#0, r0
1:	movl	(r1)+, r4
	cbeq	r4, #1, 2f
	add	#1, r0
2:	sob	r3, 1b
	halt
h_f:	rti
h_bad:	movq	#99, r0
	halt
	.data
	.align	8
vtab:
	.space	56
	.quad	h_f
	.quad	h_f
	.space	3900
