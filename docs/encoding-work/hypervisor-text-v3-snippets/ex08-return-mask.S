; 6.15 example 8: RTI #mask is the only RTI.  The kernel leaves a secret in R5 and a user value in R8 and returns to user mode naming only R8 (the callee-saved
; registers of the ABI are R8 to R11, R13, R15 and R24 to R31).  The hardware clears R5 in the same step as the return, and the user program sees zero.
; Run: sim64 -K
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	hbad, r2
	movq	#512, r3
kfill:	movq	r2, (r1)+
	sob	r3, kfill
	lea	vtab, r1
	lea	h_ok, r2
	movq	r2, 8*(VECTOR_TRAP_BASE+0)(r1)	; TRAP #0: the user program is satisfied
	lea	h_fail, r2
	movq	r2, 8*(VECTOR_TRAP_BASE+1)(r1)	; TRAP #1: it failed, R0 says which check
	lea	ustack_top, r1
	mtsr	usp, r1
	lea	user, r1
	mtsr	epc, r1
	movq	#((MODE_USER<<PSW_MODE)|(MODE_USER<<PSW_PREV)), r1
	mtsr	epsw, r1
	movq	=0x1234, r5			; a value of the kernel's own: a secret
	movq	=0x77, r8			; a value of the user's that the kernel restored
	rti	#(1<<8)				; keep R8; every other register is cleared, R5 included
user:	cbeq	r5, #0, 1f			; the secret must be gone
	movq	#1, r0
	trap	#1
1:	cbeq	r8, #0x77, 1f			; the named register must be kept
	movq	#2, r0
	trap	#1
1:	trap	#0
h_ok:	movq	#0, r0
	halt
h_fail:	halt
hbad:	movq	#98, r0
	halt
	.data
	.align	4096
vtab:	.space	4096
	.space	512
ustack_top:
