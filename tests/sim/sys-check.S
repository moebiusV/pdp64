; the check trap (errata 152, 159), System v1 in kernel mode: a failing compare-and-trap and a failing chk2 enter vector 16 (check) with EPC and EVA the address of the
; instruction and ECAUSE the vector number; the handler skips the instruction by setting EPC past it (the program does the arithmetic with the label of the next instruction).
; A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r6
	movq	#0, r8
	movq	#9, r2
	lea	next1, r10
c1:	ctcc	r2, #5			; 9 >= 5 unsigned: trap
next1:
	cbne r8, #(VECTOR_CHECK), F1
	lea	c1, r11
	cbne r6, r11, F2
	movq	#0, r6
	movq	#0, r8
	movq	#0, r3
	movq	#10, r4
	lea	next2, r10
c2:	chk2	r2, r3, r2		; 9 < 0..9 fails: trap
next2:
	cbne r8, #(VECTOR_CHECK), F3
	lea	c2, r11
	cbne r6, r11, F4
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
	.even
check_handler:
	mfsr	r6, epc
	mfsr	r8, ecause
	mtsr	epc, r10
	rti	#RTIMASK_ALL
	.data
	.even
vtab:
	.space	VECTOR_CHECK * 8
	.quad	check_handler
	.space	(512 - VECTOR_CHECK - 1) * 8
