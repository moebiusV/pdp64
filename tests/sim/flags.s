; condition codes as set by add, sub, cmp, shifts and logic, read with set cc
	.text
	.globl	_start
_start:
	movq	#-1, r1
	add	#1, r1
	set	cs, r3
	set	eq, r4
	set	vs, r5
	set	mi, r6
	cmp	r3, #1		; cs: -1 + 1 carries out
	bne	f1
	cmp	r4, #1		; eq
	bne	f2
	cmp	r5, #0		; vs
	bne	f3
	cmp	r6, #0		; mi
	bne	f4
	movq	#0, r1
	sub	#1, r1
	set	cs, r3
	set	mi, r4
	set	vs, r5
	set	lt, r6
	set	eq, r7
	cmp	r3, #1		; cs: 0 - 1 borrows (C is the borrow)
	bne	f5
	cmp	r4, #1		; mi
	bne	f6
	cmp	r5, #0		; vs
	bne	f7
	cmp	r6, #1		; lt
	bne	f8
	cmp	r7, #0		; eq
	bne	f9
	movq	#-1, r1
	shr	#1, r1
	add	#1, r1
	set	vs, r3
	set	mi, r4
	set	cs, r5
	set	ge, r6
	set	lt, r7
	cmp	r3, #1		; vs: 0x7fff... + 1 overflows
	bne	f10
	cmp	r4, #1		; mi
	bne	f11
	cmp	r5, #0		; cs
	bne	f12
	cmp	r6, #1		; ge
	bne	f13
	cmp	r7, #0		; lt
	bne	f14
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	set	cs, r3
	set	hi, r4
	set	lt, r5
	set	gt, r6
	set	le, r7
	set	los, r8
	cmp	r3, #1		; cs: 5 < 7 unsigned
	bne	f15
	cmp	r4, #0		; hi
	bne	f16
	cmp	r5, #1		; lt
	bne	f17
	cmp	r6, #0		; gt
	bne	f18
	cmp	r7, #1		; le
	bne	f19
	cmp	r8, #1		; los
	bne	f20
	movq	#9, r1
	movq	#9, r2
	cmp	r1, r2
	set	eq, r3
	set	cc, r4
	set	hi, r5
	set	los, r6
	set	ge, r7
	set	gt, r8
	set	le, r9
	cmp	r3, #1		; eq
	bne	f21
	cmp	r4, #1		; cc: no borrow
	bne	f22
	cmp	r5, #0		; hi
	bne	f23
	cmp	r6, #1		; los
	bne	f24
	cmp	r7, #1		; ge
	bne	f25
	cmp	r8, #0		; gt
	bne	f26
	cmp	r9, #1		; le
	bne	f27
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	set	lt, r3
	set	hi, r4
	set	gt, r5
	cmp	r3, #1		; lt: -1 < 1 signed
	bne	f28
	cmp	r4, #1		; hi: 0xfff... > 1 unsigned
	bne	f29
	cmp	r5, #0		; gt
	bne	f30
	movq	#1, r1
	shl	#63, r1
	shl	#1, r1
	set	cs, r3
	set	eq, r4
	cmp	r3, #1		; cs: the bit shifted out of bit 63
	bne	f31
	cmp	r4, #1		; eq
	bne	f32
	movq	#1, r1
	shr	#1, r1
	set	cs, r3
	set	eq, r4
	cmp	r3, #1		; cs: the bit shifted out of bit 0
	bne	f33
	cmp	r4, #1		; eq
	bne	f34
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	shl	#0, r3
	set	cs, r3
	cmp	r3, #1		; cs: a zero shift count changes no flag, not even C
	bne	f35
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bis	#1, r1
	set	cs, r3
	set	vs, r4
	cmp	r3, #1		; cs: logic operations leave C
	bne	f36
	cmp	r4, #0		; vs
	bne	f37
	cmp	r1, r2
	inc	r1
	set	cs, r3
	cmp	r3, #1		; cs: inc leaves C
	bne	f38
	com	r1
	set	cs, r3
	cmp	r3, #1		; cs: com sets C
	bne	f39
	movq	#0, r1
	neg	r1
	set	cs, r3
	set	eq, r4
	cmp	r3, #0		; cs: neg of 0 clears C
	bne	f40
	cmp	r4, #1		; eq
	bne	f41
	movq	#5, r1
	neg	r1
	set	cs, r3
	set	mi, r4
	cmp	r3, #1		; cs: neg of non-zero sets C
	bne	f42
	cmp	r4, #1		; mi
	bne	f43
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	tst	r1
	set	cs, r3
	set	vs, r4
	cmp	r3, #0		; cs: tst clears C
	bne	f44
	cmp	r4, #0		; vs
	bne	f45
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
f32:	movq	#32, r0
	trap	#0
f33:	movq	#33, r0
	trap	#0
f34:	movq	#34, r0
	trap	#0
f35:	movq	#35, r0
	trap	#0
f36:	movq	#36, r0
	trap	#0
f37:	movq	#37, r0
	trap	#0
f38:	movq	#38, r0
	trap	#0
f39:	movq	#39, r0
	trap	#0
f40:	movq	#40, r0
	trap	#0
f41:	movq	#41, r0
	trap	#0
f42:	movq	#42, r0
	trap	#0
f43:	movq	#43, r0
	trap	#0
f44:	movq	#44, r0
	trap	#0
f45:	movq	#45, r0
	trap	#0
