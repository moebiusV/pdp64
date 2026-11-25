; 6.14 story: the instruction a guest kernel runs that a user program must not (SPL), and what the hypervisor's handler does with it.  On the PDP-11 it was ignored in user mode;
; here the hypervisor sets the PRIO bit of HTRAP, the SPL exits (code 6), and the handler does what the instruction would have done: it changes the priority field of
; the guest's saved status word.  The guest then reads its own status word and sees the priority it asked for.  Run: sim64 -H
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	hx, r2
	lea	htab+8*VECTOR_HEXIT, r1
	movq	r2, (r1)
	movq	=(1<<HTRAP_PRIO), r1
	mtsr	htrap, r1			; SPL and a priority-changing MTPS of the guest exit
	lea	guest, r1
	mtsr	hepc, r1
	movq	#0, r1
	mtsr	hepsw, r1			; the guest starts at priority 0
	genter	#0
guest:	spl	#7				; keep interrupts out of the run-queue code
	mfps	r5				; what priority does the guest believe it has?
	movq	=(7<<PSW_PRI), r6
	and	r6, r5
	cbeq	r5, r6, 1f
	movq	#1, r0
	halt
1:	movq	#0, r0
	halt
hx:	mfsr	r20, hexitr
	cbeq	r20, #XCODE_PRIO, h_prio
	cbeq	r20, #XCODE_HALT, h_halt
	movq	#98, r0
	halt
h_prio:	mfsr	r21, hepsw			; the guest's status word at the exit; HEPC is already the next instruction
	movq	=(7<<PSW_PRI), r22		; the hypervisor would read the new level from HINSN; this example knows it is 7
	bis	r22, r21
	mtsr	hepsw, r21
	movq	#1, r22
	movq	r22, caught			; the hypervisor saw the SPL
	genter	#0
h_halt:	movq	caught, r22
	cbeq	r22, #1, 1f
	movq	#2, r0				; the SPL never exited
1:	halt
	.data
	.align	8
caught:	.quad	0
	.align	4096
htab:	.space	4096
