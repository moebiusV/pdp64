; extb, extzb, insb and dshr with their position and width (the executor once ignored both).  A failed check n exits with n.
	.text
	.globl	_start
_start:
	mov	=0x1234567890abcdef, r1
	extzb	r1, #8, #16, r5
	mov	#43981, r7		; 0xabcd
	cbne	r5, r7, f1
	extb	r1, #4, #8, r6
	cbne r6, #-34, f2
	mov	=0xffffffffffffffff, r3
	mov	#0x5a, r4
	insb	r4, #12, #8, r3		; bits 19..12 of r3 become 0x5a
	mov	=0xfffffffffff5afff, r7
	cbne r3, r7, f3
	mov	=0x8000000000000001, r2
	mov	=0xffffffffffffff85, r1
	dshr	r1, r2, #1, r3		; (r1:r2) >> 1, low 64 bits
	mov	=0xc000000000000000, r7
	cbne r3, r7, f4
	dshr	r1, r2, #0, r3
	cbne r3, r2, f5
	clr	r0
	halt
f1:	mov	#1, r0
	halt
f2:	mov	#2, r0
	halt
f3:	mov	#3, r0
	halt
f4:	mov	#4, r0
	halt
f5:	mov	#5, r0
	halt
