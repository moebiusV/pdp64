; 6.15 examples 1 and 2: the hypervisor starts a guest; the guest executes WFE; the hypervisor sees the exit and enters the guest again; the guest's HALT exits too.
; The hypervisor keeps its count in memory, not in a register, because GENTER #0 clears every register.  Run: sim64 -H
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1			; where the hypervisor's own vector table is
	lea	hx, r2
	lea	htab+8*VECTOR_HEXIT, r1
	mov	r2, (r1)			; vector 17: an exit for an instruction
	mov	=(1<<HTRAP_WFE), r1
	mtsr	htrap, r1			; exit on WFE (HALT always exits)
	lea	guest, r1
	mtsr	hepc, r1
	mov	#0, r1
	mtsr	hepsw, r1			; kernel mode, priority 0
	genter	#0				; the guest starts with every register zero
guest:	wfe
	halt
hx:	mfsr	r20, hexitr			; why did the guest stop?
	cbeq	r20, #XCODE_WFE, h_wfe
	cbeq	r20, #XCODE_HALT, h_halt
	mov	#1, r0				; an exit we did not expect
	halt
h_wfe:	lea	guest+2, r21			; HEPC must be the instruction after the WFE (WFE is one parcel)
	mfsr	r22, hepc
	cbeq	r21, r22, 1f
	mov	#2, r0
	halt
1:	mov	seen, r21
	add	#1, r21
	mov	r21, seen
	genter	#0				; the guest resumes after its WFE
h_halt:	mov	seen, r21
	cbeq	r21, #1, 1f
	mov	#3, r0
	halt
1:	mov	#0, r0				; the machine ends with status 0
	halt
	.data
	.align	8
seen:	.quad	0
	.align	4096
htab:	.space	4096
