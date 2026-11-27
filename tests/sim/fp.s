; binary64 arithmetic in the general registers, comparison, conversion, exception flags
	.text
	.globl	_start
_start:
	mov	$0x3FF8, r1
	shl	$48, r1
	mov	$0x4000, r2
	shl	$48, r2
	fadd	r1, r2
	mov	$0x400C, r3
	shl	$48, r3
	cbne r2, r3, fail2
	mov	$0x3FF8, r1
	shl	$48, r1
	mov	$0x4000, r2
	shl	$48, r2
	fmul	r1, r2
	mov	$0x4008, r3
	shl	$48, r3
	cbne r2, r3, fail4
	mov	$0x4000, r1
	shl	$48, r1
	mov	$0x400C, r2
	shl	$48, r2
	fsub	r1, r2
	mov	$0x3FF8, r3
	shl	$48, r3
	cbne r2, r3, fail6
	mov	$0x4000, r1
	shl	$48, r1
	mov	$0x4008, r2
	shl	$48, r2
	fdiv	r1, r2
	mov	$0x3FF8, r3
	shl	$48, r3
	cbne r2, r3, fail8
	mov	$0x4010, r1
	shl	$48, r1
	fsqrt	r1, r2
	mov	$0x4000, r3
	shl	$48, r3
	cbne r2, r3, fail9
	mov	$0x4000, r1
	shl	$48, r1
	mov	$0x4008, r2
	shl	$48, r2
	mov	$0x3FF0, r3
	shl	$48, r3
	fmadd	r1, r2, r3, r4
	mov	$0x401C, r5
	shl	$48, r5
	cbne r4, r5, fail10
	mov	$3, r1
	fcvt.s64		r1, r2
	mov	$0x4008, r3
	shl	$48, r3
	cbne r2, r3, fail11
	mov	$0x400C, r1
	shl	$48, r1
	fcvt	r1.f64, r2.s64
	cbne r2, $3, fail12
	mov	$0x3FF8, r1
	shl	$48, r1
	fneg	r1, r2
	fabs	r2, r3
	cbne r3, r1, fail13
	mov	$0x3FF8, r1
	shl	$48, r1
	mov	$0x4000, r2
	shl	$48, r2
	fcblt	r1, r2, 1f
	br	fail14
1:
	fcbgt	r1, r2, fail15
	fcbeq	r1, r2, fail16
	fcbne	r1, r2, 1f
	br	fail17
1:
	fcble	r1, r2, 1f
	br	fail18
1:
	fcbge	r1, r2, fail19
	fcbeq	r2, r2, 1f
	br	fail20
1:
	fcblt	r2, r2, fail21
	fcbge	r2, r2, 1f
	br	fail22
1:
	mov	$0, r9
	fsflags	r9, r8
	mov	$0x3FF0, r1
	shl	$48, r1
	mov	$0x0000, r2
	shl	$48, r2
	fdiv	r2, r1
	mov	$0x7FF0, r3
	shl	$48, r3
	cbne r1, r3, fail23
	fsflags	r9, r8
	cbne r8, $8, fail24
	fsflags	r9, r8
	cbne r8, $0, fail25
	mov	$0x0000, r1
	shl	$48, r1
	mov	$0x0000, r2
	shl	$48, r2
	fdiv	r2, r1
	mov	$0x7FF8, r3
	shl	$48, r3
	cbne r1, r3, fail26
	fsflags	r9, r8
	cbne r8, $16, fail27
	mov	$0x3FF0, r1
	shl	$48, r1
	mov	$0x4008, r2
	shl	$48, r2
	fdiv	r2, r1
	fsflags	r9, r8
	cbne r8, $1, fail28
	mov	$0x3FF0, r1
	shl	$48, r1
	mov	$0x4000, r2
	shl	$48, r2
	fadd	r2, r1
	fsflags	r9, r8
	cbne r8, $0, fail29
	mov	$31, r9
	fsflags	r9, r8
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $31, fail30
	mov	$0, r0
	trap	$0
fail1:	mov	$1, r0
	trap	$0
fail2:	mov	$2, r0
	trap	$0
fail3:	mov	$3, r0
	trap	$0
fail4:	mov	$4, r0
	trap	$0
fail5:	mov	$5, r0
	trap	$0
fail6:	mov	$6, r0
	trap	$0
fail7:	mov	$7, r0
	trap	$0
fail8:	mov	$8, r0
	trap	$0
fail9:	mov	$9, r0
	trap	$0
fail10:	mov	$10, r0
	trap	$0
fail11:	mov	$11, r0
	trap	$0
fail12:	mov	$12, r0
	trap	$0
fail13:	mov	$13, r0
	trap	$0
fail14:	mov	$14, r0
	trap	$0
fail15:	mov	$15, r0
	trap	$0
fail16:	mov	$16, r0
	trap	$0
fail17:	mov	$17, r0
	trap	$0
fail18:	mov	$18, r0
	trap	$0
fail19:	mov	$19, r0
	trap	$0
fail20:	mov	$20, r0
	trap	$0
fail21:	mov	$21, r0
	trap	$0
fail22:	mov	$22, r0
	trap	$0
fail23:	mov	$23, r0
	trap	$0
fail24:	mov	$24, r0
	trap	$0
fail25:	mov	$25, r0
	trap	$0
fail26:	mov	$26, r0
	trap	$0
fail27:	mov	$27, r0
	trap	$0
fail28:	mov	$28, r0
	trap	$0
fail29:	mov	$29, r0
	trap	$0
fail30:	mov	$30, r0
	trap	$0
