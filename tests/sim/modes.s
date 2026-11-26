; every addressing mode, widths, sign and zero extension
	.text
	.globl	_start
_start:
	movq	buf, r1
	cbne r1, #11, f1
	lea	buf, r2
	movq	8(r2), r3
	cbne r3, #22, f2
	movq	(r2)+, r4
	cbne r4, #11, f3
	lea	buf, r5
	add	#8, r5
	cbne r2, r5, f4
	movq	(r2)+, r6
	cbne r6, #22, f5
	movq	-(r2), r7
	cbne r7, #22, f6
	lea	buf, r2
	movq	#2, r8
	movq	(r2)(r8*8), r9
	cbne r9, #33, f7
	movq	8(r2)(r8*8), r9
	cbne r9, #44, f8
	lea	(r2)(r8*8), r3
	sub	r2, r3
	cbne r3, #16, f9
	mov	32(r2).32, r1
	cbne r1, #5, f10
	mov	36(r2).16, r1
	cbne r1, #6, f11
	mov	38(r2).8, r1
	cbne r1, #7, f12
	mov	39(r2).8, r1
	cbne r1, #-1, f13
	mov	39(r2).u8, r1
	cbne r1, #255, f14
	mov	40(r2).16, r1
	cbne r1, #-1, f15
	mov	40(r2).u16, r1
	movq	=65535, r13
	cbne	r1, r13, f16
	mov	44(r2).32, r1
	cbne r1, #-1, f17
	mov	44(r2).u32, r1
	movq	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cbne r1, r12, f18
	movq	#77, r1
	movq	r1, 8(r2)
	movq	8(r2), r3
	cbne r3, #77, f19
	movq	#0x1FF, r1
	mov	r1, 48(r2).8
	mov	48(r2).u8, r3
	cbne r3, #255, f20
	movq	#-1, r1
	movq	r1, 48(r2)
	movq	#0, r1
	mov	r1, 48(r2).32
	movq	48(r2), r3
	movq	#-1, r12
	shl	#32, r12
	cbne r3, r12, f21
	mtdp	r2
	movq	8(dp), r3
	cbne r3, #77, f22
	movq	#-5, r1
	cbne r1, #-5, f23
	movq	#0x1234, r1		; a 48-bit value built from pieces: an immediate is 32 bits
	shl	#32, r1
	bis	#0x56789ABC, r1
	movq	#0x1234, r12
	shl	#32, r12
	movq	#0x56789ABC, r11
	bis	r11, r12
	cbne r1, r12, f24
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
