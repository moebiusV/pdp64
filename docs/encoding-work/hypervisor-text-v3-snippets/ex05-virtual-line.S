; 6.15 example 5: a virtual interrupt line.  The hypervisor sets bit 6 of VIRQ and the vector that line 6 takes in VIVEC, and enters a guest at priority 7: nothing happens.
; The guest lowers its priority with SPL #0 (which does not exit) and the hardware makes the guest's own exception entry, with no exit.  Run: sim64 -H
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	hx, r2
	lea	htab+8*VECTOR_HEXIT, r1
	mov	r2, (r1)			; the only exit we expect is the guest's HALT
	mov	$(1<<6), r1
	mtsr	virq, r1			; line 6 is pending
	mov	=(0x60<<40), r1			; line 6 is field 6 of VIVEC (bits 47 to 40): vector 0x60
	mtsr	vivec, r1
	lea	guest, r1
	mtsr	hepc, r1
	mov	=((MODE_KERNEL<<PSW_MODE)|(MODE_KERNEL<<PSW_PREV)|(7<<PSW_PRI)), r1
	mtsr	hepsw, r1			; the guest starts in kernel mode at priority 7
	genter	$0
hx:	mfsr	r20, hexitr
	cbeq	r20, $XCODE_HALT, 1f
	mov	$97, r0
1:	halt					; the guest's R0 is its status, and the machine ends with it
guest:	lea	gvtab, r1			; the guest is a kernel: it sets its own vector base ...
	mtsr	vbr, r1
	lea	g_tick, r2
	lea	gvtab+8*0x60, r1
	mov	r2, (r1)			; ... and the handler of vector 0x60
	lea	gstk_top, r14
	nop
	mov	ticks, r1			; at priority 7 the line is held off
	cbeq	r1, $0, 1f
	mov	$1, r0
	halt
1:	spl	$0				; the priority drops: the interrupt is taken before the next instruction
	nop
	mov	ticks, r1
	cbeq	r1, $1, 1f			; the handler ran exactly once
	mov	$2, r0
	halt
1:	mov	$0, r0
	halt
g_tick:	mov	ticks, r21
	add	$1, r21
	mov	r21, ticks
	rti	$RTIMASK_ALL			; the same mode: the mask is ignored
	.data
	.align	8
ticks:	.quad	0
	.align	4096
htab:	.space	4096
gvtab:	.space	4096
	.space	512
gstk_top:
