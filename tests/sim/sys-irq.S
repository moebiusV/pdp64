; System v1 interrupts (sim64 -K -i ...): a request is taken between instructions when its level is above the priority; the handler runs at that level; rti restores the priority; the higher level first. Generated; a failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r10
	movq	#0, r15
	movq	#0, r6
	movq	#0, r7
	movq	#0, r12
	nop
	nop
	cmp	r10, #(0)
	bne	F1	; check 1
	spl	#6
	nop
	nop
	cmp	r10, #(0)
	bne	F2	; check 2
	spl	#5
after5:
	nop
	cmp	r10, #(1)
	bne	F3	; check 3
	cmp	r15, #(41)
	bne	F4	; check 4
	lea	after5, r11
	cmp	r6, r11
	bne	F5	; check 5
	bic	#15, r7
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|5<<PSW_PRI))
	bne	F6	; check 6
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F7	; check 7
	cmp	r8, #(VECTOR_TIMER+9)
	bne	F8	; check 8
	mfps	r1
	bic	#15, r1
	cmp	r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|5<<PSW_PRI))
	bne	F9	; check 9
	spl	#4
after4:
	nop
	cmp	r10, #(2)
	bne	F10	; check 10
	cmp	r15, #(4140)
	bne	F11	; check 11
	lea	after4, r11
	cmp	r6, r11
	bne	F12	; check 12
	bic	#15, r7
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|4<<PSW_PRI))
	bne	F13	; check 13
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F14	; check 14
	spl	#0
	nop
	nop
	nop
	cmp	r10, #(4)
	bne	F15	; check 15
	cmp	r15, #(41404243)
	bne	F16	; check 16
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F17	; check 17
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
F10:	movq	#10, r0
	halt
F11:	movq	#11, r0
	halt
F12:	movq	#12, r0
	halt
F13:	movq	#13, r0
	halt
F14:	movq	#14, r0
	halt
F15:	movq	#15, r0
	halt
F16:	movq	#16, r0
	halt
F17:	movq	#17, r0
	halt
h_irq:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	#1, r10
	mul	#100, r15
	add	r8, r15
	rti
	.data
	.align	8
vtab:
	.space	320
	.quad	h_irq
	.quad	h_irq
	.quad	h_irq
	.quad	h_irq
	.space	3744

