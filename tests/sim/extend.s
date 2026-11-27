; sign and zero extension of every width, from a register and from memory; partial stores
	.text
	.globl	_start
_start:
	mov	$0x1234, r1
	shl	$16, r1
	bis	$0x5678, r1
	shl	$16, r1
	bis	$0x9ABC, r1
	shl	$16, r1
	bis	$0xDEF0, r1
	mov.s8	r1, r2
	cbne r2, $-16, f1
	mov.u8	r1, r2
	cbne r2, $240, f2
	mov.s16	r1, r2
	cbne r2, $-8464, f3
	mov.u16	r1, r2
	mov	=57072, r12	; register source: mov .u16 
	cbne	r2, r12, f4
	mov.s32	r1, r2
	mov	=-1698898192, r12	; register source: mov .32 low long 0x9ABCDEF0
	cbne	r2, r12, f5
	mov.u32	r1, r2
	mov	$39612, r12
	shl	$16, r12
	bis	$57072, r12
	cbne r2, r12, f6
	mov	r1, r2
	cbne r2, r1, f7
	mov	$0, r3
	mov	$0, r3
	bis	$127, r3
	mov	$-1, r4
	shl	$8, r4
	bis	r4, r3
	mov.s8	r3, r2
	cbne r2, $127, f8
	mov.u8	r3, r2
	cbne r2, $127, f9
	mov	$0, r3
	mov	$0, r3
	bis	$128, r3
	mov	$-1, r4
	shl	$8, r4
	bis	r4, r3
	mov.s8	r3, r2
	cbne r2, $-128, f10
	mov.u8	r3, r2
	cbne r2, $128, f11
	mov	$0, r3
	mov	$0, r3
	bis	$32767, r3
	mov	$-1, r4
	shl	$16, r4
	bis	r4, r3
	mov.s16	r3, r2
	cbne r2, $32767, f12
	mov.u16	r3, r2
	cbne r2, $32767, f13
	mov	$0, r3
	mov	$0, r3
	bis	$32768, r3
	mov	$-1, r4
	shl	$16, r4
	bis	r4, r3
	mov.s16	r3, r2
	cbne r2, $-32768, f14
	mov.u16	r3, r2
	mov	=32768, r12	; boundary 0x8000 mov .u16
	cbne	r2, r12, f15
	mov	$32767, r3
	shl	$16, r3
	bis	$65535, r3
	mov	$-1, r4
	shl	$32, r4
	bis	r4, r3
	mov.s32	r3, r2
	mov	=2147483647, r12	; boundary 0x7FFFFFFF mov .32
	cbne	r2, r12, f16
	mov.u32	r3, r2
	mov	=2147483647, r12	; boundary 0x7FFFFFFF mov .u32
	cbne	r2, r12, f17
	mov	$32768, r3
	shl	$16, r3
	bis	$0, r3
	mov	$-1, r4
	shl	$32, r4
	bis	r4, r3
	mov.s32	r3, r2
	mov	=-2147483648, r12	; boundary 0x80000000 mov .32
	cbne	r2, r12, f18
	mov.u32	r3, r2
	mov	$32768, r12
	shl	$16, r12
	bis	$0, r12
	cbne r2, r12, f19
	mov	r1, r2
	mov.u32	r2, r2
	mov	$39612, r12
	shl	$16, r12
	bis	$57072, r12
	cbne r2, r12, f20
	mov	r1, r2
	mov.s32	r2, r2
	mov	=-1698898192, r12	; mov .32 r,r sign-extends
	cbne	r2, r12, f21
	mov	r1, r2
	mov.u8	r2, r2
	cbne r2, $240, f22
	lea	pat, r5
	mov.s8	0(r5), r2
	cbne r2, $-16, f23
	lea	pat, r5
	mov.s8	1(r5), r2
	cbne r2, $-34, f24
	lea	pat, r5
	mov.u8	1(r5), r2
	cbne r2, $222, f25
	lea	pat, r5
	mov.s16	0(r5), r2
	cbne r2, $-8464, f26
	lea	pat, r5
	mov.s16	2(r5), r2
	cbne r2, $-25924, f27
	lea	pat, r5
	mov.u16	2(r5), r2
	mov	=39612, r12	; memory source: mov .u16 at +2
	cbne	r2, r12, f28
	lea	pat, r5
	mov.s32	0(r5), r2
	mov	=-1698898192, r12	; memory source: mov .32 at +0
	cbne	r2, r12, f29
	lea	pat, r5
	mov.s32	4(r5), r2
	mov	=305419896, r12	; memory source: mov .32 at +4
	cbne	r2, r12, f30
	lea	pat, r5
	mov.u32	0(r5), r2
	mov	$39612, r12
	shl	$16, r12
	bis	$57072, r12
	cbne r2, r12, f31
	lea	pat, r5
	mov.u32	4(r5), r2
	mov	=305419896, r12	; memory source: mov .u32 at +4
	cbne	r2, r12, f32
	lea	out, r5
	mov	$-1, r6
	mov.s8	r6, 0(r5)
	mov	0(r5), r2
	mov	exp1, r12	; mov .8 stores one byte, the others stay
	cbne	r2, r12, f41
	mov.s16	r6, 8(r5)
	mov	8(r5), r2
	mov	exp2, r12	; mov .16 stores two bytes
	cbne	r2, r12, f42
	mov	$0x1234, r6
	shl	$16, r6
	bis	$0x5678, r6
	mov.s32	r6, 8(r5)
	mov	8(r5), r2
	mov	exp3, r12	; mov .32 stores four bytes
	cbne	r2, r12, f43
; the sign and zero extension show in the register (checks 44 to 49)
	mov	$128, r3
	mov.s8	r3, r2
	cbne r2, $-128, f44
	mov	$128, r3
	mov.u8	r3, r2
	cbne r2, $128, f45
	mov	$0, r3
	mov.s8	r3, r2
	cbne r2, $0, f46
	mov	$0, r3
	mov.u16	r3, r2
	cbne r2, $0, f47
	mov	$32768, r3
	shl	$16, r3
	mov.s32	r3, r2
	mov	=-2147483648, r12	; and it is sign-extended
	cbne r2, r12, f48
	mov	$32768, r3
	shl	$16, r3
	mov.u32	r3, r2
	cbne r2, r3, f49
	mov	$0, r0
	trap	$0
f1:	mov	$1, r0
	trap	$0
f2:	mov	$2, r0
	trap	$0
f3:	mov	$3, r0
	trap	$0
f4:	mov	$4, r0
	trap	$0
f5:	mov	$5, r0
	trap	$0
f6:	mov	$6, r0
	trap	$0
f7:	mov	$7, r0
	trap	$0
f8:	mov	$8, r0
	trap	$0
f9:	mov	$9, r0
	trap	$0
f10:	mov	$10, r0
	trap	$0
f11:	mov	$11, r0
	trap	$0
f12:	mov	$12, r0
	trap	$0
f13:	mov	$13, r0
	trap	$0
f14:	mov	$14, r0
	trap	$0
f15:	mov	$15, r0
	trap	$0
f16:	mov	$16, r0
	trap	$0
f17:	mov	$17, r0
	trap	$0
f18:	mov	$18, r0
	trap	$0
f19:	mov	$19, r0
	trap	$0
f20:	mov	$20, r0
	trap	$0
f21:	mov	$21, r0
	trap	$0
f22:	mov	$22, r0
	trap	$0
f23:	mov	$23, r0
	trap	$0
f24:	mov	$24, r0
	trap	$0
f25:	mov	$25, r0
	trap	$0
f26:	mov	$26, r0
	trap	$0
f27:	mov	$27, r0
	trap	$0
f28:	mov	$28, r0
	trap	$0
f29:	mov	$29, r0
	trap	$0
f30:	mov	$30, r0
	trap	$0
f31:	mov	$31, r0
	trap	$0
f32:	mov	$32, r0
	trap	$0
f41:	mov	$41, r0
	trap	$0
f42:	mov	$42, r0
	trap	$0
f43:	mov	$43, r0
	trap	$0
f44:	mov	$44, r0
	trap	$0
f45:	mov	$45, r0
	trap	$0
f46:	mov	$46, r0
	trap	$0
f47:	mov	$47, r0
	trap	$0
f48:	mov	$48, r0
	trap	$0
f49:	mov	$49, r0
	trap	$0
	.data
	.even
pat:	.byte	0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
out:	.quad	0x1111111111111111, 0x2222222222222222
exp1:	.quad	0x11111111111111FF
exp2:	.quad	0x222222222222FFFF
exp3:	.quad	0x2222222212345678
