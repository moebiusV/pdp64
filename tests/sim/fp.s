; binary64 arithmetic in the general registers, comparison, conversion, exception flags
	.text
	.globl	_start
_start:
	mov	#0x3FF8, r1
	shl	#48, r1
	mov	#0x4000, r2
	shl	#48, r2
	fadd	r1, r2
	mov	#0x400C, r3
	shl	#48, r3
	cbne r2, r3, f2
	mov	#0x3FF8, r1
	shl	#48, r1
	mov	#0x4000, r2
	shl	#48, r2
	fmul	r1, r2
	mov	#0x4008, r3
	shl	#48, r3
	cbne r2, r3, f4
	mov	#0x4000, r1
	shl	#48, r1
	mov	#0x400C, r2
	shl	#48, r2
	fsub	r1, r2
	mov	#0x3FF8, r3
	shl	#48, r3
	cbne r2, r3, f6
	mov	#0x4000, r1
	shl	#48, r1
	mov	#0x4008, r2
	shl	#48, r2
	fdiv	r1, r2
	mov	#0x3FF8, r3
	shl	#48, r3
	cbne r2, r3, f8
	mov	#0x4010, r1
	shl	#48, r1
	fsqrt	r1, r2
	mov	#0x4000, r3
	shl	#48, r3
	cbne r2, r3, f9
	mov	#0x4000, r1
	shl	#48, r1
	mov	#0x4008, r2
	shl	#48, r2
	mov	#0x3FF0, r3
	shl	#48, r3
	fmadd	r1, r2, r3, r4
	mov	#0x401C, r5
	shl	#48, r5
	cbne r4, r5, f10
	mov	#3, r1
	fcvt.s64		r1, r2
	mov	#0x4008, r3
	shl	#48, r3
	cbne r2, r3, f11
	mov	#0x400C, r1
	shl	#48, r1
	fcvt.f64.s64	r1, r2
	cbne r2, #3, f12
	mov	#0x3FF8, r1
	shl	#48, r1
	fneg	r1, r2
	fabs	r2, r3
	cbne r3, r1, f13
	mov	#0x3FF8, r1
	shl	#48, r1
	mov	#0x4000, r2
	shl	#48, r2
	fcblt	r1, r2, 1f
	br	f14
1:
	fcbgt	r1, r2, f15
	fcbeq	r1, r2, f16
	fcbne	r1, r2, 1f
	br	f17
1:
	fcble	r1, r2, 1f
	br	f18
1:
	fcbge	r1, r2, f19
	fcbeq	r2, r2, 1f
	br	f20
1:
	fcblt	r2, r2, f21
	fcbge	r2, r2, 1f
	br	f22
1:
	mov	#0, r9
	fsflags	r9, r8
	mov	#0x3FF0, r1
	shl	#48, r1
	mov	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	mov	#0x7FF0, r3
	shl	#48, r3
	cbne r1, r3, f23
	fsflags	r9, r8
	cbne r8, #8, f24
	fsflags	r9, r8
	cbne r8, #0, f25
	mov	#0x0000, r1
	shl	#48, r1
	mov	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	mov	#0x7FF8, r3
	shl	#48, r3
	cbne r1, r3, f26
	fsflags	r9, r8
	cbne r8, #16, f27
	mov	#0x3FF0, r1
	shl	#48, r1
	mov	#0x4008, r2
	shl	#48, r2
	fdiv	r2, r1
	fsflags	r9, r8
	cbne r8, #1, f28
	mov	#0x3FF0, r1
	shl	#48, r1
	mov	#0x4000, r2
	shl	#48, r2
	fadd	r2, r1
	fsflags	r9, r8
	cbne r8, #0, f29
	mov	#31, r9
	fsflags	r9, r8
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #31, f30
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
f23:	mov	#23, r0
	trap	#0
f24:	mov	#24, r0
	trap	#0
f25:	mov	#25, r0
	trap	#0
f26:	mov	#26, r0
	trap	#0
f27:	mov	#27, r0
	trap	#0
f28:	mov	#28, r0
	trap	#0
f29:	mov	#29, r0
	trap	#0
f30:	mov	#30, r0
	trap	#0
