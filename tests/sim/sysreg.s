; mfsr and mtsr in kernel mode (sim64 -k): every writable system register round-trips, they are independent of each other and of r14.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	sp, r13			; the real stack pointer, to see that usp and ssp do not touch it
	movq	#101, r1
	mtsr	ptbr, r1
	movq	#102, r1
	mtsr	epc, r1
	movq	#106, r1
	mtsr	usp, r1
	movq	#107, r1
	mtsr	ssp, r1
	mfsr	r2, ptbr
	cbne r2, #101, f1
	mfsr	r2, epc
	cbne r2, #102, f2
	mfsr	r2, usp
	cbne r2, #106, f5
	mfsr	r2, ssp
	cbne r2, #107, f6
	cbne sp, r13, f7
; a 64-bit value, and a write after the others leaves them as they were
	movq	#-1, r3
	shl	#17, r3
	bis	#12345, r3
	mtsr	ptbr, r3
	mfsr	r4, ptbr
	cbne r4, r3, f8
	mfsr	r4, epc
	cbne r4, #102, f9
; the stack pointer register is not the system registers: writing r14 leaves usp and ssp
	movq	#0, r14
	mfsr	r4, usp
	cbne r4, #106, f10
	mfsr	r4, ssp
	cbne r4, #107, f11
; reading eva and ecause is allowed (they start at zero in the emulator)
	mfsr	r4, eva
	cbne r4, #0, f12
	mfsr	r4, ecause
	cbne r4, #0, f13
	movq	#0, r0
	halt
f1:	movq	#1, r0
	halt
f2:	movq	#2, r0
	halt
f5:	movq	#5, r0
	halt
f6:	movq	#6, r0
	halt
f7:	movq	#7, r0
	halt
f8:	movq	#8, r0
	halt
f9:	movq	#9, r0
	halt
f10:	movq	#10, r0
	halt
f11:	movq	#11, r0
	halt
f12:	movq	#12, r0
	halt
f13:	movq	#13, r0
	halt
