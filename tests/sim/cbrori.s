; cbCC (compare a register with a 5-bit immediate and branch) and rori32.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	#5, r1
	cbeq	r1, #5, 1f		; taken: 5 - 5 = 0
	br	f1
1:	cbne	r1, #5, f2		; not taken
	cblt	r1, #6, 1f		; taken: 5 < 6 signed
	br	f3
1:	cbge	r1, #6, f4		; not taken
	cbgt	r1, #-1, 1f		; taken: 5 > -1 signed
	br	f5
1:	cbhi	r1, #-1, f6		; not taken: -1 is 0xFFFF...F unsigned, 5 is below it
	cblos	r1, #-1, 1f		; taken, unsigned lower or same
	br	f7
1:	cble	r1, #5, 1f		; taken: equal
	br	f8
1:	cbcs	r1, #6, 1f		; taken: 5 - 6 borrows
	br	f9
1:	cbcc	r1, #6, f10		; not taken
	cbpl	r1, #15, f11		; not taken: 5 - 15 is negative
	cbmi	r1, #15, 1f		; taken
	br	f12
1:	cbvs	r1, #0, f13		; not taken: no overflow
	cbvc	r1, #0, 1f		; taken
	br	f14
1:	cbhis	r1, #-16, f15		; not taken: unsigned 5 is below 0xFFFF...F0
	cblo	r1, #-16, 1f		; taken
	br	f16
1:
; the flags are those of cmp r1, #imm: after cbne (not taken) Z is set; after cbeq (not taken) it is clear
	cbne	r1, #5, f17
	beq	1f
	br	f18
1:	cbeq	r1, #4, f19
	bne	1f
	br	f20
1:
; the extreme immediates: -16 and 15
	movq	#-16, r2
	cbeq	r2, #-16, 1f
	br	f21
1:	movq	#15, r2
	cbeq	r2, #15, 1f
	br	f22
1:
; a loop with the branch backward: counts 10 down to 0
	movq	#10, r3
	movq	#0, r4
2:	add	#1, r4
	sub	#1, r3
	cbne	r3, #0, 2b
	cmp	r4, #10
	bne	f23
; the long form: a target more than 1024 parcels away, forward and backward
	cbeq	r4, #10, 1f
	br	f24
	.space	3000
1:	br	3f
4:	movq	#1, r5
	br	5f
	.space	3000
3:	cbeq	r4, #10, 4b
	br	f25
5:	cmp	r5, #1
	bne	f26
; rori32: the low 32 bits rotate right, the result is sign-extended from bit 31 (errata 34)
	movq	#-1, r6
	shl	#16, r6
	bis	#0x8000, r6
	shl	#16, r6
	bis	#1, r6			; r6 = 0xFFFFFFFF80000001
	rori32	r6, #1, r7		; ror32(0x80000001, 1) = 0xC0000000: bit 31 set, so negative: 0xFFFFFFFFC0000000
	movq	#-1073741824, r8
	cmp	r7, r8
	bne	f27
	rori32	r6, #0, r7		; a zero count: 0x80000001 sign-extended
	movq	#-2147483647, r8
	cmp	r7, r8
	bne	f28
	rori32	r6, #31, r7		; ror32(0x80000001, 31) = 3: bit 31 clear, positive
	cmp	r7, #3
	bne	f29
	movq	#0x12345678, r6
	rori32	r6, #8, r7		; 0x78123456: bit 31 clear
	movq	#0x78123456, r8
	cmp	r7, r8
	bne	f30
	rori32	r6, #4, r6		; rd = rs; 0x81234567: bit 31 set, 0xFFFFFFFF81234567
	movq	#-2128394905, r8
	cmp	r6, r8
	bne	f31
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
f14:	movq	#14, r0
	trap	#0
f15:	movq	#15, r0
	trap	#0
f16:	movq	#16, r0
	trap	#0
f17:	movq	#17, r0
	trap	#0
f18:	movq	#18, r0
	trap	#0
f19:	movq	#19, r0
	trap	#0
f20:	movq	#20, r0
	trap	#0
f21:	movq	#21, r0
	trap	#0
f22:	movq	#22, r0
	trap	#0
f23:	movq	#23, r0
	trap	#0
f24:	movq	#24, r0
	trap	#0
f25:	movq	#25, r0
	trap	#0
f26:	movq	#26, r0
	trap	#0
f27:	movq	#27, r0
	trap	#0
f28:	movq	#28, r0
	trap	#0
f29:	movq	#29, r0
	trap	#0
f30:	movq	#30, r0
	trap	#0
f31:	movq	#31, r0
	trap	#0
