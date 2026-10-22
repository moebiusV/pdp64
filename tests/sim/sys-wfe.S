; System v1: wfe sleeps until an interrupt is taken; the EPC is the instruction after the wfe. Generated; a failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r10
	spl	#0
	wfe
afterw:
	nop
	cmp	r10, #(1)
	bne	F1	; check 1
	lea	afterw, r11
	cmp	r6, r11
	bne	F2	; check 2
	cmp	r8, #(44)
	bne	F3	; check 3
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F4	; check 4
	bic	#15, r7
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI))
	bne	F5	; check 5
	movq	#0, r0
	halt
F1:	movq	#1, r0
	halt
F2:	movq	#2, r0
	halt
F3:	movq	#3, r0
	halt
F4:	movq	#4, r0
	halt
F5:	movq	#5, r0
	halt
h_irq:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	#1, r10
	rti
	.data
	.align	8
vtab:
	.space	352
	.quad	h_irq
	.space	3736

