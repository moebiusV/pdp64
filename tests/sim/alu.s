; add, sub, logic, shifts, multiply, divide: values worked out by hand
	.text
	.globl	_start
_start:
	movq	#100, r1
	add	#23, r1
	cbne r1, #123, f1
	sub	#3, r1
	cbne r1, #120, f2
	movq	#0xF0, r2
	bis	#0x0F, r2
	cbne r2, #255, f3
	bic	#0x0F, r2
	cbne r2, #240, f4
	xor	#0xFF, r2
	cbne r2, #15, f5
	and	#6, r2
	cbne r2, #6, f6
	movq	#7, r3
	mul	#6, r3
	cbne r3, #42, f7
	shl	#3, r3
	cbne r3, #336, f8
	shr	#4, r3
	cbne r3, #21, f9
	movq	#-64, r4
	sar	#3, r4
	cbne r4, #-8, f10
	shr	#60, r4
	cbne r4, #15, f11
	movq	#1, r5
	shl	#62, r5
	movq	#8, r6
	mulh	r6, r5
	cbne r5, #2, f12
	movq	#-7, r7
	movq	#2, r8
	div	r7, r8, r9
	cbne r9, #-3, f13
	mod	r7, r8, r9
	cbne r9, #-1, f14
	movq	#100, r7
	movq	#3, r8
	divu	r7, r8, r9
	cbne r9, #33, f15
	modu	r7, r8, r9
	cbne r9, #1, f16
	movq	#1, r7
	shl	#63, r7
	movq	#-1, r8
	div	r7, r8, r9
	cbne r9, r7, f17
	mod	r7, r8, r9
	cbne r9, #0, f18
	movq	#5, r1
	shl	#64, r1
	cbne r1, #0, f19
	movq	#-5, r1
	sar	#100, r1
	cbne r1, #-1, f20
	movq	#12345, r1
	shl	#0, r1
	cbne r1, #12345, f21
	movq	#0x1234, r1
	shl	#32, r1
	bis	#0x56789ABC, r1
	shr	#32, r1
	cbne r1, #4660, f22
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
