; page: user mode, 1000 times: a load from a kernel-kept read-only page  (sim64 -K --timing=...)
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	ustack_top, r1
	mtsr	usp, r1
	lea	user, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti
user:
	movq	#1000, r10
	lea	page, r12
loop:
	movq	0(r12), r1
	sub	#1, r10
	bne	loop
	trap	#0
h_sys:	mfsr	r1, cpuid
	rti
	.data
	.align	8
page:	.quad	12345
	.space	4088
vtab:
	.space	2064
	.quad	h_sys
	.space	2024
	.space	256
ustack_top:
