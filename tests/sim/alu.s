; add, sub, logic, shifts, multiply, divide: values worked out by hand
	.text
	.globl	_start
_start:
	movq	#100, r1
	add	#23, r1
	cmp	r1, #123
	bne	f1
	sub	#3, r1
	cmp	r1, #120
	bne	f2
	movq	#0xF0, r2
	bis	#0x0F, r2
	cmp	r2, #255
	bne	f3
	bic	#0x0F, r2
	cmp	r2, #240
	bne	f4
	xor	#0xFF, r2
	cmp	r2, #15
	bne	f5
	and	#6, r2
	cmp	r2, #6
	bne	f6
	movq	#7, r3
	mul	#6, r3
	cmp	r3, #42
	bne	f7
	shl	#3, r3
	cmp	r3, #336
	bne	f8
	shr	#4, r3
	cmp	r3, #21
	bne	f9
	movq	#-64, r4
	sar	#3, r4
	cmp	r4, #-8
	bne	f10
	shr	#60, r4
	cmp	r4, #15		; -8 as unsigned >> 60
	bne	f11
	movq	#1, r5
	shl	#62, r5
	movq	#8, r6
	mulh	r6, r5
	cmp	r5, #2		; high half of 2^62 * 8 = 2^65
	bne	f12
	movq	#-7, r7
	movq	#2, r8
	div	r7, r8, r9
	cmp	r9, #-3		; truncates toward zero
	bne	f13
	mod	r7, r8, r9
	cmp	r9, #-1		; sign of the dividend
	bne	f14
	movq	#100, r7
	movq	#3, r8
	divu	r7, r8, r9
	cmp	r9, #33
	bne	f15
	modu	r7, r8, r9
	cmp	r9, #1
	bne	f16
	movq	#1, r7
	shl	#63, r7
	movq	#-1, r8
	div	r7, r8, r9
	cmp	r9, r7		; INT64_MIN / -1 wraps, no trap
	bne	f17
	mod	r7, r8, r9
	cmp	r9, #0
	bne	f18
	movq	#5, r1
	shl	#64, r1
	cmp	r1, #0		; a count of 64 or more shifts everything out
	bne	f19
	movq	#-5, r1
	sar	#100, r1
	cmp	r1, #-1		; sar by a huge count gives the sign
	bne	f20
	movq	#12345, r1
	shl	#0, r1
	cmp	r1, #12345
	bne	f21
	movq	#0x1234, r1
	shl	#32, r1
	bis	#0x56789ABC, r1
	shr	#32, r1
	cmp	r1, #4660		; the high half of a value made of a 16-bit and a 32-bit immediate
	bne	f22
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
