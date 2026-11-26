; binary64 arithmetic in the general registers, comparison, conversion, exception flags
	.text
	.globl	_start
_start:
	movq	#0x3FF8, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fadd	r1, r2
	movq	#0x400C, r3
	shl	#48, r3
	cbne r2, r3, f2
	movq	#0x3FF8, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fmul	r1, r2
	movq	#0x4008, r3
	shl	#48, r3
	cbne r2, r3, f4
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x400C, r2
	shl	#48, r2
	fsub	r1, r2
	movq	#0x3FF8, r3
	shl	#48, r3
	cbne r2, r3, f6
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	fdiv	r1, r2
	movq	#0x3FF8, r3
	shl	#48, r3
	cbne r2, r3, f8
	movq	#0x4010, r1
	shl	#48, r1
	fsqrt	r1, r2
	movq	#0x4000, r3
	shl	#48, r3
	cbne r2, r3, f9
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	movq	#0x3FF0, r3
	shl	#48, r3
	fmadd	r1, r2, r3, r4
	movq	#0x401C, r5
	shl	#48, r5
	cbne r4, r5, f10
	movq	#3, r1
	fcvt	r1, r2.64
	movq	#0x4008, r3
	shl	#48, r3
	cbne r2, r3, f11
	movq	#0x400C, r1
	shl	#48, r1
	fcvt	r1.64, r2
	cbne r2, #3, f12
	movq	#0x3FF8, r1
	shl	#48, r1
	fneg	r1, r2
	fabs	r2, r3
	cbne r3, r1, f13
	movq	#0x3FF8, r1
	shl	#48, r1
	movq	#0x4000, r2
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
	movq	#0, r9
	fsflags	r9, r8
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	movq	#0x7FF0, r3
	shl	#48, r3
	cbne r1, r3, f23
	fsflags	r9, r8
	cbne r8, #8, f24
	fsflags	r9, r8
	cbne r8, #0, f25
	movq	#0x0000, r1
	shl	#48, r1
	movq	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	movq	#0x7FF8, r3
	shl	#48, r3
	cbne r1, r3, f26
	fsflags	r9, r8
	cbne r8, #16, f27
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	fdiv	r2, r1
	fsflags	r9, r8
	cbne r8, #1, f28
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fadd	r2, r1
	fsflags	r9, r8
	cbne r8, #0, f29
	movq	#31, r9
	fsflags	r9, r8
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #31, f30
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
