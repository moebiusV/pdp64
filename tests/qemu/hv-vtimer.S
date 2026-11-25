; The virtual timer (errata 195, 196; design 1.9, decision 17), QEMU machine with hypervisor=on.  The core's timer page (MAP_VTIMER) has the registers of the physical timer: its counter reads the
; real counter minus VTOFF, its compare and enable are the guest's, and its expiry sets VIRQ bit 6 (the hardware clears it when the guest's priority lets the interrupt in).
;   1. VTOFF: the guest's counter is the real counter minus VTOFF, read with no exit (the hypervisor reads the real counter from the physical page, which is unmodified at H = 1);
;   2. the guest arms its compare 20000 ticks ahead and spins at priority 6: the line (6) is not above its priority, so it is not taken, but VIRQ bit 6 is set when the counter passes the compare;
;   3. the guest lowers its priority (SPL 5, no exit): the virtual interrupt is taken with the vector of line 6 in VIVEC, its handler reads the counter (>= compare) and halts;
;   4. after the exit VIRQ bit 6 is clear (cleared at delivery); a second arming with the compare in the past fires at once.
#include "pdp64-consts.h"
VEC6 = 0x60
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	xh, r2
	movq	#512, r3
fill1:	movq	r2, (r1)+
	sob	r3, fill1
	lea	gvtab, r1
	mtsr	vbr, r1
	lea	gbad, r2
	movq	#512, r3
fill2:	movq	r2, (r1)+
	sob	r3, fill2
	lea	gh6, r2
	lea	gvtab+8*VEC6, r1
	movq	r2, (r1)
	lea	gstk_top, r2
	mtsr	gksp, r2
	movq	#0, r1
	mtsr	htrap, r1
	mtsr	epc, r1
	mtsr	gecause, r1
	movq	=(VEC6<<40), r1		; line 6 -> vector 0x60
	mtsr	vivec, r1
	movq	#0, r1
	mtsr	virq, r1
	movq	=MAP_TIMER, r13		; the physical timer: the real counter
	movq	=2000000, r3		; wait until the real counter is large (0.2 s), so that a counter that ignores VTOFF is far from the one that applies it
wait:	movq	(r13), r4
	cbcs	r4, r3, wait
	movq	(r13), r9
	movq	r9, r12			; r12: the real counter when VTOFF was written
	sub	#100, r9
	movq	r9, r2
	mtsr	vtoff, r2		; the guest's counter is the real counter minus (real - 100): about 100 at the start
	mfsr	r2, vtoff
	cbeq	r2, r9, 1f
	movq	#1, r0
	halt
1:	movq	=(MAP_VTIMER), r13
	lea	guest, r1
	mtsr	hepc, r1
	movq	#(5<<PSW_PRI), r2	; priority 5: line 6 can be taken ... after the SPL below the guest raises it to 6 first
	mtsr	hepsw, r2
	movq	#99, r0
	genter	#RTIMASK_ALL
guest:	movq	=MAP_VTIMER, r13
	movq	(r13), r1		; c0: the counter, about 100
	movq	r1, r2
	add	#20000, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	spl	#6			; masks line 6 (the line must be above the priority); SPL does not exit
	movq	#(1<<TIMER_CTL_ENABLE), r3
	movq	r3, TIMER_REG_CONTROL(r13)
spin:	movq	TIMER_REG_CONTROL(r13), r5	; spin until the counter passes the compare (PENDING): the line is raised but masked
	and	#(1<<TIMER_CTL_PENDING), r5
	beq	spin
	movq	#0, r6			; the interrupt has not been taken
	spl	#5			; line 6 is now above the priority: taken before the next instruction
	nop
	movq	#1, r6			; not reached before the handler has run
	movq	=MAP_VTIMER, r13
	movq	#0, r4
	movq	r4, TIMER_REG_CONTROL(r13)
	; second arming with the compare in the past: fires at once, taken at once (priority 5)
	movq	#0, r2
	movq	r2, TIMER_REG_COMPARE(r13)
	movq	#(1<<TIMER_CTL_ENABLE), r3
	movq	r3, TIMER_REG_CONTROL(r13)
	nop
	halt
gh6:	add	#1, r10			; the guest's handler of vector 0x60
	movq	(r13), r4		; the counter at the interrupt
	mfsr	r7, ecause
	mfsr	r8, epc
	rti	#RTIMASK_ALL
gbad:	movq	#77, r11
	halt
xh:	mfsr	r20, hexitr
	cbeq	r20, #XCODE_HALT, 1f
	movq	#2, r0
	halt
1:	; the log: r10 = number of virtual interrupts taken, r1 = c0, r2 = compare, r4 = the counter at the first interrupt
	movq	=MAP_TIMER, r15
	movq	(r15), r15		; the real counter now
	cbeq	r10, #2, 1f		; two interrupts: the armed one and the one with the compare in the past
	movq	#3, r0
	halt
1:	cbeq	r11, #0, 1f		; no other vector
	movq	#4, r0
	halt
1:	cbeq	r7, #VEC6, 1f
	movq	#5, r0
	halt
1:	movq	#100, r16		; c0 >= 100 and c0 - 100 <= real_now - real_at_vtoff
	cbcc	r1, r16, 1f
	movq	#6, r0
	halt
1:	sub	r12, r15		; r15 = real_now - real0
	movq	r1, r16
	sub	#100, r16
	cbcc	r15, r16, 1f
	movq	#7, r0
	halt
1:	mfsr	r17, virq
	cbeq	r17, #0, 1f		; both cleared at delivery
	movq	#8, r0
	halt
1:	movq	#0, r0
	halt
	.data
	.align	8
htab:	.space	4096
gvtab:	.space	4096
	.space	512
gstk_top:
