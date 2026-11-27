; System v1 (errata 40): exception and interrupt entry sets the priority to 7.  A level-6 request that becomes pending as the first instruction of a trap handler (entered from priority 0)
; starts is not taken until the handler lowers the priority, and EPC and EPSW are intact; after RTI the old priority is back.  A level-4 interrupt is entered; a level-6 request
; pending in its handler is masked by priority 7 and by spl #6 and taken after spl #3.  (sim64 -K -i: the request counts are in the .flags file.)  Generated.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	$0, r10
	mov	$0, r8
	mov	$0, r15
	mov	$0, r5
	mov	$0, r4
	mov	$0, r13
	mov	$0, r12
	mov	$0, r9
	mov	$0, r3
	spl	$0
	nop
	nop
	nop
	trap	$3
after_trap:
	mfps	r1
	cbne r1, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI)), F1 ; check 1
	cbne r10, $(1), F2 ; check 2
	cbne r5, $(0), F3 ; check 3
	cbne r4, $(1), F4 ; check 4
	lea	after_trap, r11
	cbne r6, r11, F5 ; check 5
	lea	after_trap, r11
	cbne r8, r11, F6 ; check 6
	cbne r7, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI)), F7 ; check 7
	cbne r9, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI)), F8 ; check 8
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F9 ; check 9
	cbne r15, $(40), F10 ; check 10
	mov	$0, r10
	mov	$0, r5
	mov	$0, r4
	mov	$0, r8
	mov	$0, r12
	mov	$0, r13
	mov	$0, r9
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
	cbne r1, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|0<<PSW_PRI)), F11 ; check 11
	cbne r8, $(1), F12 ; check 12
	cbne r13, $(0), F13 ; check 13
	cbne r12, $(0), F14 ; check 14
	cbne r9, $(1), F15 ; check 15
	cbne r10, $(1), F16 ; check 16
	cbne r3, $((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI)), F17 ; check 17
	mov	$404142, r14
	cbne r15, r14, F18 ; check 18
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
F6:	mov	$6, r0
	halt
F7:	mov	$7, r0
	halt
F8:	mov	$8, r0
	halt
F9:	mov	$9, r0
	halt
F10:	mov	$10, r0
	halt
F11:	mov	$11, r0
	halt
F12:	mov	$12, r0
	halt
F13:	mov	$13, r0
	halt
F14:	mov	$14, r0
	halt
F15:	mov	$15, r0
	halt
F16:	mov	$16, r0
	halt
F17:	mov	$17, r0
	halt
F18:	mov	$18, r0
	halt
	.globl	h_trap
h_trap:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mov	r10, r5
	nop
	nop
	mfsr	r8, epc
	mfsr	r9, epsw
	spl	$0
	nop
	mov	r10, r4
	mtsr	epc, r6
	mtsr	epsw, r7
	rti	$RTIMASK_ALL
h_irq:	add	$1, r10
	mfsr	r2, ecause
	mul	$100, r15
	add	r2, r15
	rti	$RTIMASK_ALL
h_41:	mfsr	r6, epc
	mfsr	r7, epsw
	mfps	r3
	add	$1, r8
	mfsr	r2, ecause
	mul	$100, r15
	add	r2, r15
	mov	r10, r13
	spl	$6
	nop
	nop
	mov	r10, r12
	spl	$3
	nop
	mov	r10, r9
	mtsr	epc, r6
	mtsr	epsw, r7
	rti	$RTIMASK_ALL
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

