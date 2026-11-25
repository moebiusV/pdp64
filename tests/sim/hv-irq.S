; Physical interrupts and the hypervisor mode (errata 195, 196; design 1.8, 2.3; audit decision 1), on sim64 -H (the requests are injected by -i at instruction 1300, 3000 and 9000, after the table is filled):
;   1. a guest running at priority 7 is stopped by a physical interrupt of level 1: an exit with code 1 (XCODE_IRQ), HCAUSE the vector, HEPC the instruction not yet run, HINSN HEVA HGPA zero,
;      HEPSW the guest's status word (priority 7 untouched), the hypervisor's own priority 7 and kernel mode;
;   2. the hypervisor at priority 7 does not take a request of level 2 until it lowers its priority; then it takes it as its own interrupt (HEXITR 0, HCAUSE the vector, HEPC the next instruction);
;   3. a guest that executes WFE (not trapped) is woken by a physical interrupt of level 3, which exits (code 1) with HEPC after the WFE.
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
	lea	hh, r2			; the hypervisor's own interrupt (vector 41)
	lea	htab+8*41, r1
	movq	r2, (r1)
	movq	#0, r1
	mtsr	htrap, r1		; nothing trapped (WFE runs in the guest)
	; --- 1
	lea	loop, r2
	mtsr	hepc, r2
	movq	#(7<<PSW_PRI), r2
	mtsr	hepsw, r2
	lea	back1, r20
	movq	#99, r0			; a HALT of the guest that stops the machine ends the run with a status that is not 0
	genter	#RTIMASK_ALL
loop:	add	#1, r1
loop2:	br	loop
back1:
	mfsr	r2, hexitr
	cbeq	r2, #XCODE_IRQ, 1f
	movq	#1, r0
	halt
1:	mfsr	r2, hcause
	cbeq	r2, #40, 1f
	movq	#2, r0
	halt
1:	mfsr	r2, hepc
	lea	loop, r3
	lea	loop2, r4		; the request came between two instructions of the loop: at one or the other
	cbeq	r2, r3, 1f
	cbeq	r2, r4, 1f
	movq	#3, r0
	halt
1:	mfsr	r2, hinsn
	cbeq	r2, #0, 1f
	movq	#4, r0
	halt
1:	mfsr	r2, heva
	mfsr	r3, hgpa
	bis	r3, r2
	cbeq	r2, #0, 1f
	movq	#5, r0
	halt
1:	mfsr	r2, hepsw
	bic	#15, r2
	cbeq	r2, #(7<<PSW_PRI), 1f
	movq	#6, r0
	halt
1:	mfps	r2
	bic	#15, r2
	cbeq	r2, #(MODE_KERNEL<<PSW_MODE|MODE_KERNEL<<PSW_PREV|7<<PSW_PRI), 1f
	movq	#7, r0
	halt
	; --- 2: the request of level 2 (injected at instruction 400) waits for the priority
1:	movq	#0, r10
	movq	#2000, r3
wait7:	sob	r3, wait7		; priority 7: not taken
	cbeq	r10, #0, 1f
	movq	#8, r0
	halt
1:	spl	#0
	movq	#2000, r3
wait0:	cbne	r10, #0, got
	sob	r3, wait0
	movq	#9, r0			; never taken
	halt
got:	spl	#7
	cbeq	r10, #1, 1f
	movq	#10, r0
	halt
1:	cbeq	r6, #41, 1f
	movq	#11, r0
	halt
1:	cbeq	r7, #XCODE_TAKEN_AT_H, 1f
	movq	#12, r0
	halt
	; --- 3: WFE in a guest
1:	lea	g3, r2
	mtsr	hepc, r2
	movq	#0, r2
	mtsr	hepsw, r2
	lea	back3, r20
	movq	#99, r0
	genter	#RTIMASK_ALL
g3:	wfe
g3e:	halt
back3:
	mfsr	r2, hexitr
	cbeq	r2, #XCODE_IRQ, 1f
	movq	#13, r0
	halt
1:	mfsr	r2, hcause
	cbeq	r2, #42, 1f
	movq	#14, r0
	halt
1:	mfsr	r2, hepc
	lea	g3e, r3
	cbeq	r2, r3, 1f
	movq	#15, r0
	halt
1:	movq	#0, r0
	halt
xh:	jmp	r20
hh:	mfsr	r6, hcause		; the hypervisor's own interrupt handler
	mfsr	r7, hexitr
	add	#1, r10
	rti	#RTIMASK_ALL
	.data
	.align	8
htab:	.space	4096
