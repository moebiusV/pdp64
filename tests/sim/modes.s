; every addressing mode, widths, sign and zero extension
	.text
	.globl	_start
_start:
	movq	buf, r1
	cmp	r1, #11		; pc-relative
	bne	f1
	lea	buf, r2
	movq	8(r2), r3
	cmp	r3, #22		; base + displacement
	bne	f2
	movq	(r2)+, r4
	cmp	r4, #11		; post-increment returns the old
	bne	f3
	lea	buf, r5
	add	#8, r5
	cmp	r2, r5		; post-increment added the stride (8)
	bne	f4
	movq	(r2)+, r6
	cmp	r6, #22
	bne	f5
	movq	-(r2), r7
	cmp	r7, #22		; pre-decrement subtracts first
	bne	f6
	lea	buf, r2
	movq	#2, r8
	movq	(r2)(r8*8), r9
	cmp	r9, #33		; indexed
	bne	f7
	movq	8(r2)(r8*8), r9
	cmp	r9, #44		; indexed with displacement
	bne	f8
	lea	(r2)(r8*8), r3
	sub	r2, r3
	cmp	r3, #16		; lea of an indexed address
	bne	f9
	movl	32(r2), r1
	cmp	r1, #5
	bne	f10
	movw	36(r2), r1
	cmp	r1, #6
	bne	f11
	movb	38(r2), r1
	cmp	r1, #7
	bne	f12
	movb	39(r2), r1
	cmp	r1, #-1		; movb sign-extends
	bne	f13
	movzb	39(r2), r1
	cmp	r1, #255		; movzb zero-extends
	bne	f14
	movw	40(r2), r1
	cmp	r1, #-1
	bne	f15
	movzw	40(r2), r1
	cmp	r1, #65535
	bne	f16
	movl	44(r2), r1
	cmp	r1, #-1
	bne	f17
	movzl	44(r2), r1
	cmp	r1, #4294967295
	bne	f18
	movq	#77, r1
	movq	r1, 8(r2)
	movq	8(r2), r3
	cmp	r3, #77		; store and reload
	bne	f19
	movq	#0x1FF, r1
	movb	r1, 48(r2)
	movzb	48(r2), r3
	cmp	r3, #255		; a byte store keeps the low byte
	bne	f20
	movq	#-1, r1
	movq	r1, 48(r2)
	movl	#0, r1
	movl	r1, 48(r2)
	movq	48(r2), r3
	cmp	r3, #-4294967296		; a long store leaves the other half
	bne	f21
	mtdp	r2
	movq	8(dp), r3
	cmp	r3, #77		; direct page
	bne	f22
	movq	#-5, r1
	cmp	r1, #-5		; immediate sign-extended
	bne	f23
	movq	#0x123456789ABC, r1
	cmp	r1, #20015998343868
	bne	f24
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
	.data
	.even
buf:	.quad	11, 22, 33, 44
	.long	5
	.word	6
	.byte	7, -1
	.word	-1
	.word	0
	.long	-1
	.quad	0
