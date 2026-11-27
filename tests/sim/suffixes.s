; the width and kind suffixes: .s8 .u8 .s16 .u16 .s32 .u32 (and the bare 64-bit word), in loads, stores, register extensions, the 32-bit atomics, the byte swaps and the 32-bit rotate.
; Each check that fails exits with its number.
	.text
	.globl	_start
_start:
	lea	buf, r5
	mov	=0x1122334455667788, r1
	mov	r1, 0(r5)		; q stores 64 bits
	mov	=-1, r6
	mov	r6, 8(r5)
	mov.s8	r1, 8(r5)		; b stores the low byte only
	mov	8(r5), r2
	mov	=0xFFFFFFFFFFFFFF88, r12
	cbne	r2, r12, f1
	mov.s16	r1, 8(r5)		; w stores two bytes
	mov	8(r5), r2
	mov	=0xFFFFFFFFFFFF7788, r12
	cbne	r2, r12, f2
	mov.s32	r1, 8(r5)		; l stores four bytes
	mov	8(r5), r2
	mov	=0xFFFFFFFF55667788, r12
	cbne	r2, r12, f3
	mov.s8	0(r5), r2		; b loads sign-extended
	mov	#-120, r12
	cbne	r2, r12, f4
	mov.u8	0(r5), r2		; zb loads zero-extended
	cbne	r2, #136, f5
	mov.s16	0(r5), r2
	mov	=0x7788, r12
	cbne	r2, r12, f6
	mov.u16	0(r5), r2
	cbne	r2, r12, f7
	mov.s32	0(r5), r2
	mov	=0x55667788, r12
	cbne	r2, r12, f8
	mov.u32	4(r5), r2
	mov	=0x11223344, r12
	cbne	r2, r12, f9
	mov	=0x80, r3		; a register source: b is a sign extension, zb a zero extension
	mov.s8	r3, r2
	mov	#-128, r12
	cbne	r2, r12, f10
	mov.u8	r3, r2
	cbne	r2, #128, f11
	mov	0(r5), r2		; bare mov is movq
	cbne	r2, r1, f12
	mov.s8	(r5), r2		; the mark is the other spelling of the same instruction
	mov.s8	(r5), r4
	cbne	r2, r4, f13
	mov.u16	(r5), r2
	mov.u16	(r5), r4
	cbne	r2, r4, f14
	mov	#10, r3			; the 32-bit atomics: l works on a long, q (or none) on a quad
	mov.s32	r3, 16(r5)
	mov	#5, r2
	lea	16(r5), r7
	aadd.s32	r2, (r7), r4
	cbne	r4, #10, f15
	mov.s32	16(r5), r4
	cbne	r4, #15, f16
	mov	#30, r2
	aadd	r2, (r7), r4
	mov	16(r5), r4
	cbne	r4, #45, f17		; the quad: 15 plus 30 is 45 only if all eight bytes were added
	mov	=0x0102030405060708, r1
	bswap.u32	r1, r2
	mov	=0x0403020108070605, r12	; the bytes of each long
	cbne	r2, r12, f18
	bswap.u16	r1, r2
	mov	=0x0201040306050807, r12	; the bytes of each word
	cbne	r2, r12, f19
	mov	=0x80000001, r1
	ror.s32	r1, #1, r2		; the 32-bit rotate: the low bit goes to bit 31 of a long
	mov	=0xFFFFFFFFC0000000, r12	; sign-extended
	cbne	r2, r12, f20
	mov	=0x3F800000, r1		; 1.0 as a binary32: f is single, d is double, as on the PDP-11
	mov	r1, r2
	fadd.f32	r1, r2
	mov	=0x40000000, r12
	cbne	r2, r12, f21
	mov	=0x3FF0000000000000, r1	; 1.0 as a binary64
	mov	r1, r2
	fadd	r1, r2
	mov	=0x4000000000000000, r12
	cbne	r2, r12, f22
	fcvt.f64.f32	r2, r3			; double to single: 2.0
	mov	=0x40000000, r12
	cbne	r3, r12, f23
	fcvt.f32.f64	r3, r4			; and back
	mov	=0x4000000000000000, r12
	cbne	r4, r12, f24
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
	.data
	.align 8
buf:	.space 32
