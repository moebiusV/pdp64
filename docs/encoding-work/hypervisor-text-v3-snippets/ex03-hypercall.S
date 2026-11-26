; 6.15 example 3: a hypercall is a TRAP whose number is in a range that the hypervisor routed to itself: bit 1 of the mask routes 32 to 63.
; The exit code is 22 and the hypervisor's vector is 256 + 40.  Run: sim64 -H
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	hcall, r2
	lea	htab+8*(VECTOR_TRAP_BASE+40), r1
	movq	r2, (r1)			; one entry for hypercall number 40
	lea	hhalt, r2
	lea	htab+8*VECTOR_HEXIT, r1
	movq	r2, (r1)
	movq	=(2<<HTRAP_MASK), r1		; bit 1 of the 8-bit mask: the numbers 32 to 63
	mtsr	htrap, r1
	lea	guest, r1
	mtsr	hepc, r1
	movq	#0, r1
	mtsr	hepsw, r1
	genter	#0
guest:	movq	#65, r0				; the argument: the character 'A'
	trap	#40				; a hypercall: it exits, it does not enter the guest's own vector table
	halt					; the guest stops after the hypercall returned
hcall:	mfsr	r20, hexitr
	cbeq	r20, #XCODE_HYPERCALL, 1f
	br	hbad
1:	mfsr	r20, hcause
	cbeq	r20, #(VECTOR_TRAP_BASE+40), 1f
	br	hbad
1:	cbeq	r0, #65, 1f			; the argument is where the guest left it
	br	hbad
1:	movq	#0, r0				; the result, for the guest
	genter	#RTIMASK_NONE|1			; keep R0 (bit 0): the one register the guest is to see
hhalt:	mfsr	r20, hexitr			; the guest's HALT always exits
	cbeq	r20, #XCODE_HALT, 1f
	br	hbad
1:	movq	#0, r0
	halt
hbad:	movq	#98, r0
	halt
	.data
	.align	4096
htab:	.space	4096
