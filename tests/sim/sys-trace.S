; System v1: the T bit.  After an instruction that began with T set the trace trap is taken (vector 15, EPC the next instruction); rti loads T from EPSW, rtt sets it after the return. Generated; a failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r10
	movq	#0, r2
	movq	#0, r3
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	lea	tgt, r1
	mtsr	epc, r1
	movq	#((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)|1<<PSW_T), r1
	mtsr	epsw, r1
	rti
tgt:
	add	#1, r2
t2:
	add	#1, r2
t3:
	add	#1, r2
t4:
	add	#1, r2
	cmp	r10, #(3)
	bne	F1	; check 1
	cmp	r2, #(4)
	bne	F2	; check 2
	lea	t2, r11
	cmp	r8, r11
	bne	F3	; check 3
	lea	t3, r11
	cmp	r7, r11
	bne	F4	; check 4
	lea	t4, r11
	cmp	r6, r11
	bne	F5	; check 5
	mfps	r1
	bic	#15, r1
	cmp	r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F6	; check 6
	movq	#2, r10
	lea	tgt2, r1
	mtsr	epc, r1
	movq	#((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), r1
	mtsr	epsw, r1
	rtt
tgt2:
	add	#1, r3
t22:
	add	#1, r3
	add	#1, r3
	cmp	r10, #(3)
	bne	F7	; check 7
	cmp	r3, #(3)
	bne	F8	; check 8
	lea	t22, r11
	cmp	r6, r11
	bne	F9	; check 9
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
F6:	movq	#6, r0
	halt
F7:	movq	#7, r0
	halt
F8:	movq	#8, r0
	halt
F9:	movq	#9, r0
	halt
h_trace:	movq	r7, r8
	movq	r6, r7
	mfsr	r6, epc
	add	#1, r10
	cmp	r10, #3
	blt	1f
	mfsr	r9, epsw
	bic	#(1<<PSW_T), r9
	mtsr	epsw, r9
1:	rti
	.data
	.align	8
vtab:
	.space	120
	.quad	h_trace
	.space	3968

