; extb, extzb, insb and dshr with their position and width (the executor once ignored both).  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	=0x1234567890abcdef, r1
	extzb	r1, #8, #16, r5
	cmp	r5, #43981		; 0xabcd
	bne	f1
	extb	r1, #4, #8, r6
	cmp	r6, #-34		; 0xde sign-extended
	bne	f2
	movq	=0xffffffffffffffff, r3
	movq	#0x5a, r4
	insb	r4, #12, #8, r3		; bits 19..12 of r3 become 0x5a
	movq	=0xfffffffffff5afff, r7
	cmp	r3, r7
	bne	f3
	movq	=0x8000000000000001, r2
	movq	=0xffffffffffffff85, r1
	dshr	r1, r2, #1, r3		; (r1:r2) >> 1, low 64 bits
	movq	=0xc000000000000000, r7
	cmp	r3, r7
	bne	f4
	dshr	r1, r2, #0, r3
	cmp	r3, r2
	bne	f5
	clr	r0
	halt
f1:	movq	#1, r0
	halt
f2:	movq	#2, r0
	halt
f3:	movq	#3, r0
	halt
f4:	movq	#4, r0
	halt
f5:	movq	#5, r0
	halt
