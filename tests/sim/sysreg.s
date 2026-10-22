; mfsr and mtsr in kernel mode (sim64 -k): every writable system register round-trips, they are independent of each other and of r14.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	sp, r13			; the real stack pointer, to see that usp and ssp do not touch it
	movq	#101, r1
	mtsr	ptbr, r1
	movq	#102, r1
	mtsr	epc, r1
	movq	#104, r1
	mtsr	dmw0, r1
	movq	#105, r1
	mtsr	dmw1, r1
	movq	#106, r1
	mtsr	usp, r1
	movq	#107, r1
	mtsr	ssp, r1
	mfsr	r2, ptbr
	cmp	r2, #101
	bne	f1
	mfsr	r2, epc
	cmp	r2, #102
	bne	f2
	mfsr	r2, dmw0
	cmp	r2, #104
	bne	f3
	mfsr	r2, dmw1
	cmp	r2, #105
	bne	f4
	mfsr	r2, usp
	cmp	r2, #106
	bne	f5
	mfsr	r2, ssp
	cmp	r2, #107
	bne	f6
	cmp	sp, r13			; r14 was not changed by writing usp and ssp
	bne	f7
; a 64-bit value, and a write after the others leaves them as they were
	movq	#-1, r3
	shl	#17, r3
	bis	#12345, r3
	mtsr	ptbr, r3
	mfsr	r4, ptbr
	cmp	r4, r3
	bne	f8
	mfsr	r4, epc
	cmp	r4, #102
	bne	f9
; the stack pointer register is not the system registers: writing r14 leaves usp and ssp
	movq	#0, r14
	mfsr	r4, usp
	cmp	r4, #106
	bne	f10
	mfsr	r4, ssp
	cmp	r4, #107
	bne	f11
; reading eva and ecause is allowed (they start at zero in the emulator)
	mfsr	r4, eva
	cmp	r4, #0
	bne	f12
	mfsr	r4, ecause
	cmp	r4, #0
	bne	f13
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f3:	movq	#3, r0
	trap	#0
f4:	movq	#4, r0
	trap	#0
f5:	movq	#5, r0
	trap	#0
f6:	movq	#6, r0
	trap	#0
f7:	movq	#7, r0
	trap	#0
f8:	movq	#8, r0
	trap	#0
f9:	movq	#9, r0
	trap	#0
f10:	movq	#10, r0
	trap	#0
f11:	movq	#11, r0
	trap	#0
f12:	movq	#12, r0
	trap	#0
f13:	movq	#13, r0
	trap	#0
