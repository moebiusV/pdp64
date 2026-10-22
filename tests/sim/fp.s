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
	cmp	r2, r3		; onehalf fadd two
	bne	f2
	movq	#0x3FF8, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fmul	r1, r2
	movq	#0x4008, r3
	shl	#48, r3
	cmp	r2, r3		; onehalf fmul two
	bne	f4
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x400C, r2
	shl	#48, r2
	fsub	r1, r2
	movq	#0x3FF8, r3
	shl	#48, r3
	cmp	r2, r3		; rd - rs
	bne	f6
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	fdiv	r1, r2
	movq	#0x3FF8, r3
	shl	#48, r3
	cmp	r2, r3		; rd / rs
	bne	f8
	movq	#0x4010, r1
	shl	#48, r1
	fsqrt	r1, r2
	movq	#0x4000, r3
	shl	#48, r3
	cmp	r2, r3		; sqrt 4
	bne	f9
	movq	#0x4000, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	movq	#0x3FF0, r3
	shl	#48, r3
	fmadd	r1, r2, r3, r4
	movq	#0x401C, r5
	shl	#48, r5
	cmp	r4, r5		; 2*3+1
	bne	f10
	movq	#3, r1
	fcvtqd	r1, r2
	movq	#0x4008, r3
	shl	#48, r3
	cmp	r2, r3		; int to double
	bne	f11
	movq	#0x400C, r1
	shl	#48, r1
	fcvtdq	r1, r2
	cmp	r2, #3		; truncates
	bne	f12
	movq	#0x3FF8, r1
	shl	#48, r1
	fneg	r1, r2
	fabs	r2, r3
	cmp	r3, r1		; abs(-x)
	bne	f13
	movq	#0x3FF8, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fcmp	r1, r2
	set	lt, r4
	set	gt, r5
	set	eq, r6
	set	ne, r7
	set	le, r8
	set	ge, r9
	cmp	r4, #1		; 1.5 vs 2.0 lt
	bne	f14
	cmp	r5, #0		; 1.5 vs 2.0 gt
	bne	f15
	cmp	r6, #0		; 1.5 vs 2.0 eq
	bne	f16
	cmp	r7, #1		; 1.5 vs 2.0 ne
	bne	f17
	cmp	r8, #1		; 1.5 vs 2.0 le
	bne	f18
	cmp	r9, #0		; 1.5 vs 2.0 ge
	bne	f19
	fcmp	r2, r2
	set	eq, r4
	set	lt, r5
	set	ge, r6
	cmp	r4, #1		; 2.0 vs 2.0 eq
	bne	f20
	cmp	r5, #0		; 2.0 vs 2.0 lt
	bne	f21
	cmp	r6, #1		; 2.0 vs 2.0 ge
	bne	f22
	movq	#0, r9
	fsflags	r9, r8
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	movq	#0x7FF0, r3
	shl	#48, r3
	cmp	r1, r3		; 1/0 = inf
	bne	f23
	fsflags	r9, r8
	cmp	r8, #8		; DZ raised and read back, then cleared
	bne	f24
	fsflags	r9, r8
	cmp	r8, #0
	bne	f25
	movq	#0x0000, r1
	shl	#48, r1
	movq	#0x0000, r2
	shl	#48, r2
	fdiv	r2, r1
	movq	#0x7FF8, r3
	shl	#48, r3
	cmp	r1, r3		; 0/0 = default quiet NaN
	bne	f26
	fsflags	r9, r8
	cmp	r8, #16		; NV
	bne	f27
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x4008, r2
	shl	#48, r2
	fdiv	r2, r1
	fsflags	r9, r8
	cmp	r8, #1		; 1/3 is inexact (NX)
	bne	f28
	movq	#0x3FF0, r1
	shl	#48, r1
	movq	#0x4000, r2
	shl	#48, r2
	fadd	r2, r1
	fsflags	r9, r8
	cmp	r8, #0		; exact sums raise nothing
	bne	f29
	movq	#31, r9
	fsflags	r9, r8
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #31		; writing sets all five
	bne	f30
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
