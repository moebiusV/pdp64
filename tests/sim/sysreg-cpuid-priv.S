; mfsr cpuid in user mode under the kernel-mode machine (sim64 -K): vector 3 (privileged), EPC the address of the instruction, the destination register unchanged;
; the kernel reads the number with it.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mfsr	r5, cpuid		; kernel mode: allowed
	mfsr	r6, cpuid
	cbne r5, r6, F1
	lea	ustack_top, r1
	mtsr	usp, r1
	lea	user, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	movq	#0, r10
	rti	#RTIMASK_ALL
user:
	movq	#0x5a5a, r1
	lea	pi0, r4
pi0:
	mfsr	r1, cpuid
pr0:
	cbne r10, #1, F2
	cbne r8, #(VECTOR_PRIVILEGED), F3
	lea	pi0, r11
	cbne r6, r11, F4
	cbne r1, #0x5a5a, F5
	trap	#0			; done: vector 256 exits with 0
F1:	movq	#1, r0
	trap	#1
F2:	movq	#2, r0
	trap	#1
F3:	movq	#3, r0
	trap	#1
F4:	movq	#4, r0
	trap	#1
F5:	movq	#5, r0
	trap	#1
h_gen:	mfsr	r6, epc
	mfsr	r8, ecause
	add	#1, r10
	lea	pr0, r4
	mtsr	epc, r4
	rti	#RTIMASK_ALL
h_ok:	movq	#0, r0
h_fail:	halt
	.data
	.align	8
vtab:
	.space	24
	.quad	h_gen
	.space	2016
	.quad	h_ok
	.quad	h_fail
	.align	8
ustack:	.space	256
ustack_top:
