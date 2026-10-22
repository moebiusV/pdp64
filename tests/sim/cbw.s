; the wide-immediate cbCC (errata 34): conditions taken and not taken, the flags those of cmp, and a displacement of many thousand parcels.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	#255, r1
	cbeq	r1, #255, 1f
	br	f1
1:
	cbne	r1, #255, f2
	cbhi	r1, #-1, f3
	cbgt	r1, #1000, f4
	cblt	r1, #1000, 1f
	br	f5
1:
	cbge	r1, #255, 1f
	br	f6
1:
	cble	r1, #254, f7
	cbgt	r1, #254, 1f
	br	f8
1:
	cbcs	r1, #256, 1f
	br	f9
1:
	cbcc	r1, #255, 1f
	br	f10
1:
	cbhi	r1, #254, 1f
	br	f11
1:
	cblos	r1, #255, 1f
	br	f12
1:
	cbmi	r1, #256, 1f
	br	f13
1:
	cbpl	r1, #256, f14
	cbhis	r1, #255, 1f
	br	f15
1:
	cblo	r1, #255, f16
	movq	#-1, r2
	cbgt	r2, #-1000, 1f
	br	f17
1:
	cbhi	r2, #-1000, 1f
	br	f18
1:
	cblos	r2, #-1000, f19
	cbmi	r2, #32767, 1f
	br	f20
1:
	cblt	r2, #-1000, f21
	cbeq	r2, #-32768, f22
	cbgt	r2, #-32768, 1f
	br	f23
1:
	cbmi	r2, #-32768, f24
	movq	#1, r3
	shl	#15, r3
	shl	#16, r3
	shl	#16, r3
	shl	#16, r3
				; r3 = 0x8000000000000000, the most negative number
	cbvs	r3, #1000, 1f
	br	f25
1:
	cbvc	r3, #1000, f26
	cblt	r3, #1000, 1f
	br	f27
1:
	cbvs	r3, #-1000, f28
	cbgt	r3, #-1000, f29
	movq	#255, r1
	cbne	r1, #255, f30
	beq	1f
	br	f30
1:
	cbeq	r1, #300, f31
	bne	1f
	br	f31
1:
	cbgt	r1, #300, f32
	bcs	1f
	br	f32
1:			; 255 - 300 borrows: C set
	movq	#300, r4
	movq	#0, r5
2:	add	#1, r5
	sub	#1, r4
	cbne	r4, #200, 2b
	cmp	r5, #100
	bne	f33
	movq	#255, r1
	.word	0xA911, 0x00FF, 4	; cbne r1, #255: not taken, falls to the next instruction
	br	1f
1:
	movq	#254, r1
	.word	0xA911, 0x00FF, 4	; cbne r1, #255: taken, over the two parcels of the br
	br	f35
1:
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
