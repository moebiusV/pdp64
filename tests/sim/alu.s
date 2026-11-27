; add, sub, logic, shifts, multiply, divide: values worked out by hand
	.text
	.globl	_start
_start:
	mov	#100, r1
	add	#23, r1
	cbne r1, #123, f1
	sub	#3, r1
	cbne r1, #120, f2
	mov	#0xF0, r2
	bis	#0x0F, r2
	cbne r2, #255, f3
	bic	#0x0F, r2
	cbne r2, #240, f4
	xor	#0xFF, r2
	cbne r2, #15, f5
	and	#6, r2
	cbne r2, #6, f6
	mov	#7, r3
	mul	#6, r3
	cbne r3, #42, f7
	shl	#3, r3
	cbne r3, #336, f8
	shr	#4, r3
	cbne r3, #21, f9
	mov	#-64, r4
	sar	#3, r4
	cbne r4, #-8, f10
	shr	#60, r4
	cbne r4, #15, f11
	mov	#1, r5
	shl	#62, r5
	mov	#8, r6
	mulh	r6, r5
	cbne r5, #2, f12
	mov	#-7, r7
	mov	#2, r8
	div	r7, r8, r9
	cbne r9, #-3, f13
	mod	r7, r8, r9
	cbne r9, #-1, f14
	mov	#100, r7
	mov	#3, r8
	div.u64	r7, r8, r9
	cbne r9, #33, f15
	mod.u64	r7, r8, r9
	cbne r9, #1, f16
	mov	#1, r7
	shl	#63, r7
	mov	#-1, r8
	div	r7, r8, r9
	cbne r9, r7, f17
	mod	r7, r8, r9
	cbne r9, #0, f18
	mov	#5, r1
	shl	#64, r1
	cbne r1, #0, f19
	mov	#-5, r1
	sar	#100, r1
	cbne r1, #-1, f20
	mov	#12345, r1
	shl	#0, r1
	cbne r1, #12345, f21
	mov	#0x1234, r1
	shl	#32, r1
	bis	#0x56789ABC, r1
	shr	#32, r1
	cbne r1, #4660, f22
	mov	#0, r0
	trap	#0
f1:	mov	#1, r0
	trap	#0
f2:	mov	#2, r0
	trap	#0
f3:	mov	#3, r0
	trap	#0
f4:	mov	#4, r0
	trap	#0
f5:	mov	#5, r0
	trap	#0
f6:	mov	#6, r0
	trap	#0
f7:	mov	#7, r0
	trap	#0
f8:	mov	#8, r0
	trap	#0
f9:	mov	#9, r0
	trap	#0
f10:	mov	#10, r0
	trap	#0
f11:	mov	#11, r0
	trap	#0
f12:	mov	#12, r0
	trap	#0
f13:	mov	#13, r0
	trap	#0
f14:	mov	#14, r0
	trap	#0
f15:	mov	#15, r0
	trap	#0
f16:	mov	#16, r0
	trap	#0
f17:	mov	#17, r0
	trap	#0
f18:	mov	#18, r0
	trap	#0
f19:	mov	#19, r0
	trap	#0
f20:	mov	#20, r0
	trap	#0
f21:	mov	#21, r0
	trap	#0
f22:	mov	#22, r0
	trap	#0
