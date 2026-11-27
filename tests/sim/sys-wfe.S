; System v1: wfe sleeps until an interrupt is taken; the EPC is the instruction after the wfe. A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	$0, r10
	spl	$0
	wfe
afterw:
	nop
	cbne r10, $(1), F1 ; check 1
	lea	afterw, r11
	cbne r6, r11, F2 ; check 2
	cbne r8, $(44), F3 ; check 3
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F4 ; check 4
	cbne r7, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI)), F5 ; check 5
	mov	$0, r0
	halt
F1:	mov	$1, r0
	halt
F2:	mov	$2, r0
	halt
F3:	mov	$3, r0
	halt
F4:	mov	$4, r0
	halt
F5:	mov	$5, r0
	halt
h_irq:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	$1, r10
	rti	$RTIMASK_ALL
	.data
	.align	8
vtab:
	.space	352
	.quad	h_irq
	.space	3736

