; binary16 is a storage format: the six conversions, correctly rounded, flags from the rounding; arithmetic on halves is done in binary32 (every half is exact in binary32) and narrowed once
	.text
	.globl	_start
_start:
	mov	$0, r9
	fsflags	r9, r8
; the idiom for a half operation: widen, operate in binary32, narrow; add, subtract, multiply, divide and square root come out correctly rounded
	mov	$15872, r1		; 1.5
	mov	$16384, r2		; 2.0
	fcvt	r1.f16, r3.f32
	fcvt	r2.f16, r4.f32
	fadd.f32	r4, r3
	fcvt	r3.f32, r5.f16
	cbne r5, $17152, fail90
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $0, fail91
	mov	$15360, r1		; 1.0
	mov	$16896, r2		; 3.0
	fcvt	r1.f16, r3.f32
	fcvt	r2.f16, r4.f32
	fdiv.f32	r4, r3
	fcvt	r3.f32, r5.f16
	cbne r5, $13653, fail92
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $1, fail93
	mov	$31743, r1		; 65504, the largest half
	fcvt	r1.f16, r3.f32
	fcvt	r1.f16, r4.f32
	fadd.f32	r4, r3
	fcvt	r3.f32, r5.f16
	cbne r5, $31744, fail94
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $5, fail95
	mov	$17408, r1		; 4.0
	fcvt	r1.f16, r3.f32
	fsqrt.f32	r3, r4
	fcvt	r4.f32, r5.f16
	cbne r5, $16384, fail96
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $0, fail97
	mov	$0x3FC0, r1
	shl	$16, r1
	fcvt	r1.f32, r2.f16
	cbne r2, $15872, fail61
	fcvt	r2.f16, r3.f32
	cbne r3, r1, fail62
	mov	$0x4008, r1
	shl	$48, r1
	fcvt	r1.f64, r2.f16
	cbne r2, $16896, fail63
	fcvt	r2.f16, r3.f64
	cbne r3, r1, fail64
	mov	$0x3FB9, r1
	shl	$16, r1
	bis	$0x9999, r1
	shl	$16, r1
	bis	$0x9999, r1
	shl	$16, r1
	bis	$0x999A, r1
	mov	$0, r9
	fsflags	r9, r8
	fcvt	r1.f64, r2.f16
	cbne r2, $11878, fail65
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $1, fail66
	mov	$17152, r1
	fcvt	r1.f16, r2.s32
	cbne r2, $3, fail67
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $1, fail68
	mov	$-16128, r1
	fcvt	r1.f16, r2.s32
	cbne r2, $-2, fail69
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $1, fail70
	mov	$31744, r1
	fcvt	r1.f16, r2.s32
	mov	=2147483647, r10	; +inf saturates
	cbne	r2, r10, fail71
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $16, fail72
	mov	$1000, r1
	fcvt	r1.s32, r2.f16
	cbne r2, $25552, fail73
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $0, fail74
	mov	$2049, r1
	fcvt	r1.s32, r2.f16
	cbne r2, $26624, fail75
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $1, fail76
	mov	$-1, r1
	fcvt	r1.s32, r2.f16
	cbne r2, $-17408, fail77
	mov	$0, r9
	fsflags	r9, r8
	cbne r8, $0, fail78
	mov	$0, r0
	trap	$0
	clr	r0
	trap	$0
fail61:	mov	$61, r0
	trap	$0
fail62:	mov	$62, r0
	trap	$0
fail63:	mov	$63, r0
	trap	$0
fail64:	mov	$64, r0
	trap	$0
fail65:	mov	$65, r0
	trap	$0
fail66:	mov	$66, r0
	trap	$0
fail67:	mov	$67, r0
	trap	$0
fail68:	mov	$68, r0
	trap	$0
fail69:	mov	$69, r0
	trap	$0
fail70:	mov	$70, r0
	trap	$0
fail71:	mov	$71, r0
	trap	$0
fail72:	mov	$72, r0
	trap	$0
fail73:	mov	$73, r0
	trap	$0
fail74:	mov	$74, r0
	trap	$0
fail75:	mov	$75, r0
	trap	$0
fail76:	mov	$76, r0
	trap	$0
fail77:	mov	$77, r0
	trap	$0
fail78:	mov	$78, r0
	trap	$0
fail90:	mov	$90, r0
	trap	$0
fail91:	mov	$91, r0
	trap	$0
fail92:	mov	$92, r0
	trap	$0
fail93:	mov	$93, r0
	trap	$0
fail94:	mov	$94, r0
	trap	$0
fail95:	mov	$95, r0
	trap	$0
fail96:	mov	$96, r0
	trap	$0
fail97:	mov	$97, r0
	trap	$0
