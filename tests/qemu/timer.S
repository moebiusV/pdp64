; System v1 timer (QEMU kernel-mode machine): the counter runs; compare and enable; the interrupt is taken at level 6 (masked by spl 7 and spl 6, taken after spl 5 and spl 0); wfe wakes.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	#(MAP_TIMER), r13
	movq	#0, r10
	movq	(r13), r2
	movq	r2, r3
	add	#1000, r3
1:	movq	(r13), r4
	cmp	r4, r3
	blo	1b
	movq	#0, r6
	movq	#0, r7
	movq	#0, r12
	movq	(r13), r2
	add	#20000, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	movq	TIMER_REG_CONTROL(r13), r2
	and	#(1<<TIMER_CTL_PENDING), r2
	cmp	r2, #(0)
	beq	1f
	movq	#2, r0	; check 1
	halt
1:
1:	movq	TIMER_REG_CONTROL(r13), r2
	and	#(1<<TIMER_CTL_PENDING), r2
	beq	1b
	cmp	r10, #(0)
	beq	1f
	movq	#3, r0	; check 2
	halt
1:
	spl	#6
	nop
	nop
	cmp	r10, #(0)
	beq	1f
	movq	#4, r0	; check 3
	halt
1:
	spl	#5
after5:
	nop
	cmp	r10, #(1)
	beq	1f
	movq	#5, r0	; check 4
	halt
1:
	lea	after5, r11
	cmp	r6, r11
	beq	1f
	movq	#6, r0	; check 5
	halt
1:
	bic	#15, r7
	cmp	r7, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|5<<PSW_PRI))
	beq	1f
	movq	#7, r0	; check 6
	halt
1:
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|6<<PSW_PRI))
	beq	1f
	movq	#8, r0	; check 7
	halt
1:
	cmp	r8, #(VECTOR_TIMER)
	beq	1f
	movq	#9, r0	; check 8
	halt
1:
	movq	TIMER_REG_CONTROL(r13), r2
	cmp	r2, #((1<<TIMER_CTL_PENDING))
	beq	1f
	movq	#10, r0	; check 9
	halt
1:
	spl	#7
	movq	(r13), r2
	add	#20000, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	spl	#0
	wfe
afterw:
	nop
	cmp	r10, #(2)
	beq	1f
	movq	#11, r0	; check 10
	halt
1:
	lea	afterw, r11
	cmp	r6, r11
	beq	1f
	movq	#12, r0	; check 11
	halt
1:
	spl	#7
	movq	(r13), r2
	add	#0, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	spl	#3
	nop
	cmp	r10, #(3)
	beq	1f
	movq	#13, r0	; check 12
	halt
1:
	movq	#-1, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	nop
	nop
	cmp	r10, #(3)
	beq	1f
	movq	#14, r0	; check 13
	halt
1:
	movq	#0, r3
	movq	r3, (r13)
	movq	(r13), r3
	cmp	r3, #1000
	bhi	1f
	movq	#15, r0
	halt
1:
	movq	#0, r0
	halt
h_timer:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	add	#1, r10
	movq	#0, r9
	movq	r9, TIMER_REG_CONTROL(r13)
	rti
	.data
	.align	8
vtab:
	.space	256
	.quad	h_timer
	.space	3832

