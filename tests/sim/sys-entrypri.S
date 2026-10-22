; System v1 (errata 40): exception and interrupt entry sets the priority to 7.  A level-6 request that becomes pending as the first instruction of a trap handler (entered from priority 0)
; starts is not taken until the handler lowers the priority, and EPC and EPSW are intact; after RTI the old priority is back.  A level-4 interrupt is entered; a level-6 request
; pending in its handler is masked by priority 7 and by spl #6 and taken after spl #3.  (sim64 -K -i: the request counts are in the .flags file.)  Generated.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#0, r10
	movq	#0, r8
	movq	#0, r15
	movq	#0, r5
	movq	#0, r4
	movq	#0, r13
	movq	#0, r12
	movq	#0, r9
	movq	#0, r3
	spl	#0
	nop
	nop
	nop
	trap	#3
after_trap:
	mfps	r1
	bic	#15, r1
	cmp	r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI))
	bne	F1	; check 1
	cmp	r10, #(1)
	bne	F2	; check 2
	cmp	r5, #(0)
	bne	F3	; check 3
	cmp	r4, #(1)
	bne	F4	; check 4
	lea	after_trap, r11
	cmp	r6, r11
	bne	F5	; check 5
	lea	after_trap, r11
	cmp	r8, r11
	bne	F6	; check 6
	bic	#15, r7
	bic	#15, r9
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI))
	bne	F7	; check 7
	cmp	r9, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI))
	bne	F8	; check 8
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F9	; check 9
	cmp	r15, #(40)
	bne	F10	; check 10
	movq	#0, r10
	movq	#0, r5
	movq	#0, r4
	movq	#0, r8
	movq	#0, r12
	movq	#0, r13
	movq	#0, r9
	.globl	nops2
nops2:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mfps	r1
	bic	#15, r1
	cmp	r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI))
	bne	F11	; check 11
	cmp	r8, #(1)
	bne	F12	; check 12
	cmp	r13, #(0)
	bne	F13	; check 13
	cmp	r12, #(0)
	bne	F14	; check 14
	cmp	r9, #(1)
	bne	F15	; check 15
	cmp	r10, #(1)
	bne	F16	; check 16
	cmp	r3, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI))
	bne	F17	; check 17
	cmp	r15, #(404142)
	bne	F18	; check 18
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
F18:	movq	#18, r0
	halt
	.globl	h_trap
h_trap:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	movq	r10, r5
	nop
	nop
	mfsr	r8, epc
	mfsr	r9, epsw
	spl	#0
	nop
	movq	r10, r4
	mtsr	epc, r6
	mtsr	epsw, r7
	rti
h_irq:	add	#1, r10
	mfsr	r2, ecause
	mul	#100, r15
	add	r2, r15
	rti
h_41:	mfsr	r6, epc
	mfsr	r7, epsw
	mfps	r3
	bic	#15, r3
	add	#1, r8
	mfsr	r2, ecause
	mul	#100, r15
	add	r2, r15
	movq	r10, r13
	spl	#6
	nop
	nop
	movq	r10, r12
	spl	#3
	nop
	movq	r10, r9
	mtsr	epc, r6
	mtsr	epsw, r7
	rti
	.data
	.align	8
vtab:
	.space	320
	.quad	h_irq
	.quad	h_41
	.quad	h_irq
	.space	1728
	.quad	h_trap
	.space	2016

