; binary16 is a storage format: the six conversions, correctly rounded, flags from the rounding; arithmetic on halves is done in binary32 (every half is exact in binary32) and narrowed once
	.text
	.globl	_start
_start:
	movq	#0, r9
	fsflags	r9, r8
; the idiom for a half operation: widen, operate in binary32, narrow; add, subtract, multiply, divide and square root come out correctly rounded
	movq	#15872, r1		; 1.5
	movq	#16384, r2		; 2.0
	fcvt	r1.16, r3.32
	fcvt	r2.16, r4.32
	fadd	r4.32, r3.32
	fcvt	r3.32, r5.16
	cbne r5, #17152, f90
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f91
	movq	#15360, r1		; 1.0
	movq	#16896, r2		; 3.0
	fcvt	r1.16, r3.32
	fcvt	r2.16, r4.32
	fdiv	r4.32, r3.32
	fcvt	r3.32, r5.16
	cbne r5, #13653, f92
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f93
	movq	#31743, r1		; 65504, the largest half
	fcvt	r1.16, r3.32
	fcvt	r1.16, r4.32
	fadd	r4.32, r3.32
	fcvt	r3.32, r5.16
	cbne r5, #31744, f94
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #5, f95
	movq	#17408, r1		; 4.0
	fcvt	r1.16, r3.32
	fsqrt	r3.32, r4.32
	fcvt	r4.32, r5.16
	cbne r5, #16384, f96
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f97
	movq	#0x3FC0, r1
	shl	#16, r1
	fcvt	r1.32, r2.16
	cbne r2, #15872, f61
	fcvt	r2.16, r3.32
	cbne r3, r1, f62
	movq	#0x4008, r1
	shl	#48, r1
	fcvt	r1.64, r2.16
	cbne r2, #16896, f63
	fcvt	r2.16, r3.64
	cbne r3, r1, f64
	movq	#0x3FB9, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x999A, r1
	movq	#0, r9
	fsflags	r9, r8
	fcvt	r1.64, r2.16
	cbne r2, #11878, f65
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f66
	movq	#17152, r1
	fcvt	r1.16, r2.s32
	cbne r2, #3, f67
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f68
	movq	#-16128, r1
	fcvt	r1.16, r2.s32
	cbne r2, #-2, f69
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f70
	movq	#31744, r1
	fcvt	r1.16, r2.s32
	movq	=2147483647, r10	; +inf saturates
	cbne	r2, r10, f71
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #16, f72
	movq	#1000, r1
	fcvt	r1.s32, r2.16
	cbne r2, #25552, f73
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f74
	movq	#2049, r1
	fcvt	r1.s32, r2.16
	cbne r2, #26624, f75
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #1, f76
	movq	#-1, r1
	fcvt	r1.s32, r2.16
	cbne r2, #-17408, f77
	movq	#0, r9
	fsflags	r9, r8
	cbne r8, #0, f78
	movq	#0, r0
	trap	#0
	clr	r0
	trap	#0
f61:	movq	#61, r0
	trap	#0
f62:	movq	#62, r0
	trap	#0
f63:	movq	#63, r0
	trap	#0
f64:	movq	#64, r0
	trap	#0
f65:	movq	#65, r0
	trap	#0
f66:	movq	#66, r0
	trap	#0
f67:	movq	#67, r0
	trap	#0
f68:	movq	#68, r0
	trap	#0
f69:	movq	#69, r0
	trap	#0
f70:	movq	#70, r0
	trap	#0
f71:	movq	#71, r0
	trap	#0
f72:	movq	#72, r0
	trap	#0
f73:	movq	#73, r0
	trap	#0
f74:	movq	#74, r0
	trap	#0
f75:	movq	#75, r0
	trap	#0
f76:	movq	#76, r0
	trap	#0
f77:	movq	#77, r0
	trap	#0
f78:	movq	#78, r0
	trap	#0
f90:	movq	#90, r0
	trap	#0
f91:	movq	#91, r0
	trap	#0
f92:	movq	#92, r0
	trap	#0
f93:	movq	#93, r0
	trap	#0
f94:	movq	#94, r0
	trap	#0
f95:	movq	#95, r0
	trap	#0
f96:	movq	#96, r0
	trap	#0
f97:	movq	#97, r0
	trap	#0
