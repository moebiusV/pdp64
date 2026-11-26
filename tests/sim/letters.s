; the width letters: b w l q (8, 16, 32, 64 bits) and z (zero-extending), in loads, stores, register extensions, the 32-bit atomics, the byte swaps and the 32-bit rotate.
; Each check that fails exits with its number.
	.text
	.globl	_start
_start:
	lea	buf, r5
	movq	=0x1122334455667788, r1
	movq	r1, 0(r5)		; q stores 64 bits
	movq	=-1, r6
	movq	r6, 8(r5)
	movb	r1, 8(r5)		; b stores the low byte only
	movq	8(r5), r2
	movq	=0xFFFFFFFFFFFFFF88, r12
	cbne	r2, r12, f1
	movw	r1, 8(r5)		; w stores two bytes
	movq	8(r5), r2
	movq	=0xFFFFFFFFFFFF7788, r12
	cbne	r2, r12, f2
	movl	r1, 8(r5)		; l stores four bytes
	movq	8(r5), r2
	movq	=0xFFFFFFFF55667788, r12
	cbne	r2, r12, f3
	movb	0(r5), r2		; b loads sign-extended
	movq	#-120, r12
	cbne	r2, r12, f4
	movzb	0(r5), r2		; zb loads zero-extended
	cbne	r2, #136, f5
	movw	0(r5), r2
	movq	=0x7788, r12
	cbne	r2, r12, f6
	movzw	0(r5), r2
	cbne	r2, r12, f7
	movl	0(r5), r2
	movq	=0x55667788, r12
	cbne	r2, r12, f8
	movzl	4(r5), r2
	movq	=0x11223344, r12
	cbne	r2, r12, f9
	movq	=0x80, r3		; a register source: b is a sign extension, zb a zero extension
	movb	r3, r2
	movq	#-128, r12
	cbne	r2, r12, f10
	movzb	r3, r2
	cbne	r2, #128, f11
	mov	0(r5), r2		; bare mov is movq
	cbne	r2, r1, f12
	mov	(r5).8, r2		; the mark is the other spelling of the same instruction
	movb	(r5), r4
	cbne	r2, r4, f13
	mov	(r5).u16, r2
	movzw	(r5), r4
	cbne	r2, r4, f14
	movq	#10, r3			; the 32-bit atomics: l works on a long, q (or none) on a quad
	movl	r3, 16(r5)
	movq	#5, r2
	lea	16(r5), r7
	aaddl	r2, (r7), r4
	cbne	r4, #10, f15
	movl	16(r5), r4
	cbne	r4, #15, f16
	movq	#30, r2
	aaddq	r2, (r7), r4
	movq	16(r5), r4
	cbne	r4, #45, f17		; the quad: 15 plus 30 is 45 only if all eight bytes were added
	movq	=0x0102030405060708, r1
	bswapl	r1, r2
	movq	=0x0403020108070605, r12	; the bytes of each long
	cbne	r2, r12, f18
	bswapw	r1, r2
	movq	=0x0201040306050807, r12	; the bytes of each word
	cbne	r2, r12, f19
	movq	=0x80000001, r1
	rorl	r1, #1, r2		; the 32-bit rotate: the low bit goes to bit 31 of a long
	movq	=0xFFFFFFFFC0000000, r12	; sign-extended
	cbne	r2, r12, f20
	movq	=0x3F800000, r1		; 1.0 as a binary32: f is single, d is double, as on the PDP-11
	movq	r1, r2
	faddf	r1, r2
	movq	=0x40000000, r12
	cbne	r2, r12, f21
	movq	=0x3FF0000000000000, r1	; 1.0 as a binary64
	movq	r1, r2
	faddd	r1, r2
	movq	=0x4000000000000000, r12
	cbne	r2, r12, f22
	fcvtdf	r2, r3			; double to single: 2.0
	movq	=0x40000000, r12
	cbne	r3, r12, f23
	fcvtfd	r3, r4			; and back
	movq	=0x4000000000000000, r12
	cbne	r4, r12, f24
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
	.align 8
buf:	.space 32
