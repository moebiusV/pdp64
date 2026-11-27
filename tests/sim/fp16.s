; binary16 is a storage format: the six conversions, correctly rounded, flags from the rounding; arithmetic on halves is done in binary32 (every half is exact in binary32) and narrowed once
	.text
	.globl	_start
_start:
	mov	#0, r9
	fsflags	r9, r8
; the idiom for a half operation: widen, operate in binary32, narrow; add, subtract, multiply, divide and square root come out correctly rounded
	mov	#15872, r1		; 1.5
	mov	#16384, r2		; 2.0
	fcvt.f16.f32	r1, r3
	fcvt.f16.f32	r2, r4
	fadd.f32	r4, r3
	fcvt.f32.f16	r3, r5
	cbne r5, #17152, f90
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f91
	mov	#15360, r1		; 1.0
	mov	#16896, r2		; 3.0
	fcvt.f16.f32	r1, r3
	fcvt.f16.f32	r2, r4
	fdiv.f32	r4, r3
	fcvt.f32.f16	r3, r5
	cbne r5, #13653, f92
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f93
	mov	#31743, r1		; 65504, the largest half
	fcvt.f16.f32	r1, r3
	fcvt.f16.f32	r1, r4
	fadd.f32	r4, r3
	fcvt.f32.f16	r3, r5
	cbne r5, #31744, f94
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #5, f95
	mov	#17408, r1		; 4.0
	fcvt.f16.f32	r1, r3
	fsqrt.f32	r3, r4
	fcvt.f32.f16	r4, r5
	cbne r5, #16384, f96
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f97
	mov	#0x3FC0, r1
	shl	#16, r1
	fcvt.f32.f16	r1, r2
	cbne r2, #15872, f61
	fcvt.f16.f32	r2, r3
	cbne r3, r1, f62
	mov	#0x4008, r1
	shl	#48, r1
	fcvt.f64.f16	r1, r2
	cbne r2, #16896, f63
	fcvt.f16.f64	r2, r3
	cbne r3, r1, f64
	mov	#0x3FB9, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x999A, r1
	mov	#0, r9
	fsflags	r9, r8
	fcvt.f64.f16	r1, r2
	cbne r2, #11878, f65
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f66
	mov	#17152, r1
	fcvt.f16.s32	r1, r2
	cbne r2, #3, f67
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f68
	mov	#-16128, r1
	fcvt.f16.s32	r1, r2
	cbne r2, #-2, f69
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f70
	mov	#31744, r1
	fcvt.f16.s32	r1, r2
	mov	=2147483647, r10	; +inf saturates
	cbne	r2, r10, f71
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #16, f72
	mov	#1000, r1
	fcvt.s32.f16	r1, r2
	cbne r2, #25552, f73
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f74
	mov	#2049, r1
	fcvt.s32.f16	r1, r2
	cbne r2, #26624, f75
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f76
	mov	#-1, r1
	fcvt.s32.f16	r1, r2
	cbne r2, #-17408, f77
	mov	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f78
	mov	#0, r0
	trap	#0
	clr	r0
	trap	#0
f61:	mov	#61, r0
	trap	#0
f62:	mov	#62, r0
	trap	#0
f63:	mov	#63, r0
	trap	#0
f64:	mov	#64, r0
	trap	#0
f65:	mov	#65, r0
	trap	#0
f66:	mov	#66, r0
	trap	#0
f67:	mov	#67, r0
	trap	#0
f68:	mov	#68, r0
	trap	#0
f69:	mov	#69, r0
	trap	#0
f70:	mov	#70, r0
	trap	#0
f71:	mov	#71, r0
	trap	#0
f72:	mov	#72, r0
	trap	#0
f73:	mov	#73, r0
	trap	#0
f74:	mov	#74, r0
	trap	#0
f75:	mov	#75, r0
	trap	#0
f76:	mov	#76, r0
	trap	#0
f77:	mov	#77, r0
	trap	#0
f78:	mov	#78, r0
	trap	#0
f90:	mov	#90, r0
	trap	#0
f91:	mov	#91, r0
	trap	#0
f92:	mov	#92, r0
	trap	#0
f93:	mov	#93, r0
	trap	#0
f94:	mov	#94, r0
	trap	#0
f95:	mov	#95, r0
	trap	#0
f96:	mov	#96, r0
	trap	#0
f97:	mov	#97, r0
	trap	#0
