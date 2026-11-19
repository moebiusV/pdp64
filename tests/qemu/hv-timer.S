; A physical interrupt stops a guest whatever its priority (errata 195, 196; design 1.8, 2.3; audit decision 1), with the timer of the machine as the source (the sim64 version, with injected
; requests, is tests/sim/hv-irq.S).  The hypervisor starts the timer and enters a guest that loops at priority 7: the timer interrupt (vector 32, level 6) is an exit with code 1, HCAUSE 32, HEPC the
; loop, HEPSW the guest's status word untouched.  Then the hypervisor, at priority 7, does not take the next timer interrupt until it lowers its priority; it takes it as its own (code 0).
; The machine is pdp64-virt,kernel-mode=on,hypervisor=on (tools/check-qemu.sh: the flag -H).
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	xh, r2
	movq	#512, r3
fill:	movq	r2, (r1)+
	sob	r3, fill
	movq	#0, r1
	mtsr	htrap, r1
	movq	=MAP_TIMER, r13
	movq	(r13), r2
	add	#50000, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
	lea	loop, r2
	mtsr	hepc, r2
	movq	#(7<<PSW_PRI), r2
	mtsr	hepsw, r2
	lea	back1, r20
	movq	#99, r0			; a HALT of the guest that stops the machine ends the run with a status that is not 0
	genter
loop:	add	#1, r1
loop2:	br	loop
back1:
	movq	#0, r2
	movq	r2, TIMER_REG_CONTROL(r13)		; stop the timer: the line goes down
	mfsr	r2, hexitr
	cbeq	r2, #XCODE_IRQ, 1f
	movq	#1, r0
	halt
1:	mfsr	r2, hcause
	cbeq	r2, #VECTOR_TIMER, 1f
	movq	#2, r0
	halt
1:	mfsr	r2, hepc
	lea	loop, r3
	lea	loop2, r4
	cbeq	r2, r3, 1f
	cbeq	r2, r4, 1f
	movq	#3, r0
	halt
1:	mfsr	r2, hinsn
	mfsr	r3, heva
	bis	r3, r2
	mfsr	r3, hgpa
	bis	r3, r2
	cbeq	r2, #0, 1f
	movq	#4, r0
	halt
1:	mfsr	r2, hepsw
	bic	#15, r2
	cbeq	r2, #(7<<PSW_PRI), 1f
	movq	#5, r0
	halt
1:	mfps	r2
	bic	#15, r2
	cbeq	r2, #(MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI), 1f
	movq	#6, r0
	halt
	; --- the hypervisor's own timer interrupt: masked at priority 7, taken after spl #0
1:	movq	#0, r10
	movq	(r13), r2
	add	#20000, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r2
	movq	r2, TIMER_REG_CONTROL(r13)
2:	movq	TIMER_REG_CONTROL(r13), r2
	and	#(1<<TIMER_CTL_PENDING), r2
	beq	2b			; wait until it is pending
	nop
	nop
	cbeq	r10, #0, 1f		; priority 7: not taken
	movq	#7, r0
	halt
1:	spl	#0
	nop
	nop
	spl	#7
	cbeq	r10, #1, 1f
	movq	#8, r0
	halt
1:	cbeq	r6, #VECTOR_TIMER, 1f
	movq	#9, r0
	halt
1:	cbeq	r7, #XCODE_TAKEN_AT_H, 1f
	movq	#10, r0
	halt
1:	movq	#0, r0
	halt
xh:	mfsr	r7, hexitr
	cbne	r7, #0, 1f
	mfsr	r6, hcause		; the hypervisor's own interrupt
	add	#1, r10
	movq	#0, r5
	movq	r5, TIMER_REG_CONTROL(r13)
	rti
1:	jmp	r20
	.data
	.align	8
htab:	.space	4096
