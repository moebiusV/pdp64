; binary16 is a storage format: the six conversions, correctly rounded, flags from the rounding; arithmetic on halves is done in binary32 (every half is exact in binary32) and narrowed once
	.text
	.globl	_start
_start:
	movq	#0, r9
	fsflags	r9, r8
; the idiom for a half operation: widen, operate in binary32, narrow; add, subtract, multiply, divide and square root come out correctly rounded
	movq	#15872, r1		; 1.5
	movq	#16384, r2		; 2.0
	fcvths	r1, r3
	fcvths	r2, r4
	fadd32	r4, r3
	fcvtsh	r3, r5
	cmp	r5, #17152		; 1.5 + 2.0 = 3.5
	bne	f90
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0			; flags: exact
	bne	f91
	movq	#15360, r1		; 1.0
	movq	#16896, r2		; 3.0
	fcvths	r1, r3
	fcvths	r2, r4
	fdiv32	r4, r3
	fcvtsh	r3, r5
	cmp	r5, #13653		; 1/3 rounded to a half
	bne	f92
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1			; flags: inexact
	bne	f93
	movq	#31743, r1		; 65504, the largest half
	fcvths	r1, r3
	fcvths	r1, r4
	fadd32	r4, r3
	fcvtsh	r3, r5
	cmp	r5, #31744		; 65504 + 65504 overflows to +infinity
	bne	f94
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #5			; flags: overflow and inexact
	bne	f95
	movq	#17408, r1		; 4.0
	fcvths	r1, r3
	fsqrt32	r3, r4
	fcvtsh	r4, r5
	cmp	r5, #16384		; sqrt(4.0) = 2.0
	bne	f96
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0
	bne	f97
	movq	#0x3FC0, r1
	shl	#16, r1
	fcvtsh	r1, r2
	cmp	r2, #15872		; binary32 1.5 to half
	bne	f61
	fcvths	r2, r3
	cmp	r3, r1		; half 1.5 back to binary32
	bne	f62
	movq	#0x4008, r1
	shl	#48, r1
	fcvtdh	r1, r2
	cmp	r2, #16896		; binary64 3.0 to half
	bne	f63
	fcvthd	r2, r3
	cmp	r3, r1		; half 3.0 back to binary64
	bne	f64
	movq	#0x3FB9, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x9999, r1
	shl	#16, r1
	bis	#0x999A, r1
	movq	#0, r9
	fsflags	r9, r8
	fcvtdh	r1, r2
	cmp	r2, #11878		; binary64 0.1 to half
	bne	f65
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: 0.1 inexact
	bne	f66
	movq	#17152, r1
	fcvthl	r1, r2
	cmp	r2, #3		; 3.5 -> 3
	bne	f67
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: truncation is inexact
	bne	f68
	movq	#-16128, r1
	fcvthl	r1, r2
	cmp	r2, #-2		; -2.5 -> -2
	bne	f69
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: 
	bne	f70
	movq	#31744, r1
	fcvthl	r1, r2
	cmp	r2, #2147483647		; +inf saturates
	bne	f71
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: invalid
	bne	f72
	movq	#1000, r1
	fcvtlh	r1, r2
	cmp	r2, #25552		; 1000 -> 0x63D0
	bne	f73
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: exact
	bne	f74
	movq	#2049, r1
	fcvtlh	r1, r2
	cmp	r2, #26624		; 2049 is a tie: rounds to even 2048
	bne	f75
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: inexact
	bne	f76
	movq	#-1, r1
	fcvtlh	r1, r2
	cmp	r2, #-17408		; -1
	bne	f77
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: 
	bne	f78
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
