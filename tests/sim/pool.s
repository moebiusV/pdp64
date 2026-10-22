; constants wider than 32 bits go through the literal pool and behave as immediates.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	#0x123456789ABC, r1
	movq	r1, r2
	shr	#32, r2
	cmp	r2, #0x1234
	bne	f1
	movq	#0x123456789ABC, r3
	cmp	r1, r3			; the same literal twice
	bne	f2
	cmp	r1, #0x123456789ABC	; equal: Z set
	bne	f3
	add	#0x100000000, r1
	shr	#32, r1
	cmp	r1, #0x1235
	bne	f4
	movq	#-1, r4
	and	#0xFFFFFFFF00, r4
	shr	#8, r4
	cmp	r4, #0xFFFFFFFF
	bne	f5
	push	#0x7000000000
	pop	r5
	shr	#32, r5
	cmp	r5, #0x70
	bne	f6
	movq	#-0x8000000001, r6	; below -2^31
	add	#1, r6
	movq	#-0x8000000000, r7
	cmp	r6, r7
	bne	f7
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
