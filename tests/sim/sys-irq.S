; System v1 interrupts (sim64 -K -i ...): a request is taken between instructions when its level is above the priority; the handler runs at that level; rti restores the priority; the higher level first. A failed check n halts with status n.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	#0, r10
	mov	#0, r15
	mov	#0, r6
	mov	#0, r7
	mov	#0, r12
	nop
	nop
	cbne r10, #(0), F1 ; check 1
	spl	#6
	nop
	nop
	cbne r10, #(0), F2 ; check 2
	spl	#5
after5:
	nop
	cbne r10, #(1), F3 ; check 3
	cbne r15, #(41), F4 ; check 4
	lea	after5, r11
	cbne r6, r11, F5 ; check 5
	cbne r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|5<<PSW_PRI)), F6 ; check 6
	cbne r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F7 ; check 7
	cbne r8, #(VECTOR_TIMER+9), F8 ; check 8
	mfps	r1
	cbne r1, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|5<<PSW_PRI)), F9 ; check 9
	spl	#4
after4:
	nop
	cbne r10, #(2), F10 ; check 10
	cbne r15, #(4140), F11 ; check 11
	lea	after4, r11
	cbne r6, r11, F12 ; check 12
	cbne r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|4<<PSW_PRI)), F13 ; check 13
	cbne r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F14 ; check 14
	spl	#0
	nop
	nop
	nop
	cbne r10, #(4), F15 ; check 15
	mov	#41404243, r14
	cbne r15, r14, F16 ; check 16
	cbne r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F17 ; check 17
	mov	#0, r0
	halt
F1:	mov	#1, r0
	halt
F2:	mov	#2, r0
	halt
F3:	mov	#3, r0
	halt
F4:	mov	#4, r0
	halt
F5:	mov	#5, r0
	halt
F6:	mov	#6, r0
	halt
F7:	mov	#7, r0
	halt
F8:	mov	#8, r0
	halt
F9:	mov	#9, r0
	halt
F10:	mov	#10, r0
	halt
F11:	mov	#11, r0
	halt
F12:	mov	#12, r0
	halt
F13:	mov	#13, r0
	halt
F14:	mov	#14, r0
	halt
F15:	mov	#15, r0
	halt
F16:	mov	#16, r0
	halt
F17:	mov	#17, r0
	halt
h_irq:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	#1, r10
	mul	#100, r15
	add	r8, r15
	rti	#RTIMASK_ALL
	.data
	.align	8
vtab:
	.space	320
	.quad	h_irq
	.quad	h_irq
	.quad	h_irq
	.quad	h_irq
	.space	3744

