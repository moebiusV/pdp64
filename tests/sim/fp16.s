; binary16 arithmetic and conversions, correctly rounded, flags from the rounding
	.text
	.globl	_start
_start:
	movq	#0, r9
	fsflags	r9, r8
	movq	#16384, r1
	movq	#15872, r2
	fadd16	r1, r2
	cmp	r2, #17152		; 1.5 + 2.0 = 3.5
	bne	f1
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: 1.5 + 2.0 = 3.5
	bne	f2
	movq	#16384, r1
	movq	#17152, r2
	fsub16	r1, r2
	cmp	r2, #15872		; 3.5 - 2.0 = 1.5
	bne	f3
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: 3.5 - 2.0 = 1.5
	bne	f4
	movq	#16384, r1
	movq	#15872, r2
	fmul16	r1, r2
	cmp	r2, #16896		; 1.5 * 2.0 = 3.0
	bne	f5
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: 1.5 * 2.0 = 3.0
	bne	f6
	movq	#16384, r1
	movq	#16896, r2
	fdiv16	r1, r2
	cmp	r2, #15872		; 3.0 / 2.0 = 1.5
	bne	f7
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: 3.0 / 2.0 = 1.5
	bne	f8
	movq	#16896, r1
	movq	#15360, r2
	fdiv16	r1, r2
	cmp	r2, #13653		; 1/3 is inexact: 0x3555
	bne	f9
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: 1/3 is inexact: 0x3555
	bne	f10
	movq	#31743, r1
	movq	#31743, r2
	fadd16	r1, r2
	cmp	r2, #31744		; 65504 + 65504 overflows to infinity: OF|NX
	bne	f11
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #5		; flags: 65504 + 65504 overflows to infinity: OF|NX
	bne	f12
	movq	#19456, r1
	movq	#31743, r2
	fadd16	r1, r2
	cmp	r2, #31744		; 65504 + 16 = 65520 is a tie that rounds to even = infinity
	bne	f13
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #5		; flags: 65504 + 16 = 65520 is a tie that rounds to even = infinity
	bne	f14
	movq	#1, r1
	movq	#1, r2
	fadd16	r1, r2
	cmp	r2, #2		; subnormals add exactly
	bne	f15
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: subnormals add exactly
	bne	f16
	movq	#14336, r1
	movq	#1, r2
	fmul16	r1, r2
	cmp	r2, #0		; 2^-24 * 0.5 is a tie, rounds to even (zero): UF|NX
	bne	f17
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #3		; flags: 2^-24 * 0.5 is a tie, rounds to even (zero): UF|NX
	bne	f18
	movq	#15361, r1
	movq	#15361, r2
	fmul16	r1, r2
	cmp	r2, #15362		; (1+2^-10)^2 rounds to 1+2^-9
	bne	f19
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: (1+2^-10)^2 rounds to 1+2^-9
	bne	f20
	movq	#0, r1
	movq	#15360, r2
	fdiv16	r1, r2
	cmp	r2, #31744		; 1/0 = infinity, DZ
	bne	f21
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #8		; flags: 1/0 = infinity, DZ
	bne	f22
	movq	#0, r1
	movq	#0, r2
	fdiv16	r1, r2
	cmp	r2, #32256		; 0/0 = canonical NaN, NV
	bne	f23
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: 0/0 = canonical NaN, NV
	bne	f24
	movq	#31744, r1
	movq	#31744, r2
	fadd16	r1, r2
	cmp	r2, #31744		; inf + inf = inf
	bne	f25
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: inf + inf = inf
	bne	f26
	movq	#31744, r1
	movq	#31744, r2
	fsub16	r1, r2
	cmp	r2, #32256		; inf - inf is invalid
	bne	f27
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: inf - inf is invalid
	bne	f28
	movq	#31745, r1
	movq	#15360, r2
	fadd16	r1, r2
	cmp	r2, #32256		; a signaling NaN is invalid and gives the canonical NaN
	bne	f29
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: a signaling NaN is invalid and gives the canonical NaN
	bne	f30
	movq	#17408, r1
	fsqrt16	r1, r2
	cmp	r2, #16384		; sqrt 4 = 2
	bne	f31
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: sqrt exact
	bne	f32
	movq	#16384, r1
	fsqrt16	r1, r2
	cmp	r2, #15784		; sqrt 2 = 0x3DA8
	bne	f33
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #1		; flags: sqrt 2 inexact
	bne	f34
	movq	#-17408, r1
	fsqrt16	r1, r2
	cmp	r2, #32256		; sqrt -1 = NaN
	bne	f35
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: sqrt -1 invalid
	bne	f36
	movq	#16384, r1
	movq	#16896, r2
	movq	#15360, r3
	fmadd16	r1, r2, r3, r4
	cmp	r4, #18176		; 2*3+1 = 7
	bne	f37
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: fma exact
	bne	f38
	movq	#15361, r1
	movq	#15361, r2
	movq	#-17406, r3
	fmadd16	r1, r2, r3, r4
	cmp	r4, #16		; fused: (1+2^-10)^2 - (1+2^-9) = 2^-20 exactly
	bne	f39
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: fma single rounding
	bne	f40
	movq	#16384, r1
	movq	#16896, r2
	movq	#15360, r3
	fmsub16	r1, r2, r3, r4
	cmp	r4, #17664		; 2*3-1 = 5
	bne	f41
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: fmsub
	bne	f42
	fnmadd16	r1, r2, r3, r4
	cmp	r4, #-14592		; -(2*3)-1 = -7
	bne	f43
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: fnmadd
	bne	f44
	fnmsub16	r1, r2, r3, r4
	cmp	r4, #-15104		; -(2*3)+1 = -5
	bne	f45
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #0		; flags: fnmsub
	bne	f46
	movq	#31744, r1
	movq	#0, r2
	movq	#15360, r3
	fmadd16	r1, r2, r3, r4
	cmp	r4, #32256		; inf*0 is invalid
	bne	f47
	movq	#0, r9
	fsflags	r9, r8
	cmp	r8, #16		; flags: inf*0
	bne	f48
	movq	#16384, r1
	movq	#15872, r2
	fcmp16	r2, r1
	set	lt, r4
	set	eq, r5
	set	gt, r6
	cmp	r4, #1		; 1.5 < 2.0
	bne	f49
	cmp	r5, #0
	bne	f50
	cmp	r6, #0
	bne	f51
	fcmp16	r1, r1
	set	eq, r5
	cmp	r5, #1		; 2.0 == 2.0
	bne	f52
	movq	#31744, r1
	fclass16	r1, r2
	cmp	r2, #128		; +inf
	bne	f53
	movq	#1, r1
	fclass16	r1, r2
	cmp	r2, #32		; +subnormal
	bne	f54
	movq	#15360, r1
	fclass16	r1, r2
	cmp	r2, #64		; +normal
	bne	f55
	movq	#32256, r1
	fclass16	r1, r2
	cmp	r2, #512		; quiet NaN
	bne	f56
	movq	#31745, r1
	fclass16	r1, r2
	cmp	r2, #256		; signaling NaN
	bne	f57
	movq	#-1024, r1
	fclass16	r1, r2
	cmp	r2, #1		; -inf
	bne	f58
	movq	#-32768, r1
	fclass16	r1, r2
	cmp	r2, #8		; -0
	bne	f59
	movq	#0, r1
	fclass16	r1, r2
	cmp	r2, #16		; +0
	bne	f60
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
f36:	movq	#36, r0
	trap	#0
f37:	movq	#37, r0
	trap	#0
f38:	movq	#38, r0
	trap	#0
f39:	movq	#39, r0
	trap	#0
f40:	movq	#40, r0
	trap	#0
f41:	movq	#41, r0
	trap	#0
f42:	movq	#42, r0
	trap	#0
f43:	movq	#43, r0
	trap	#0
f44:	movq	#44, r0
	trap	#0
f45:	movq	#45, r0
	trap	#0
f46:	movq	#46, r0
	trap	#0
f47:	movq	#47, r0
	trap	#0
f48:	movq	#48, r0
	trap	#0
f49:	movq	#49, r0
	trap	#0
f50:	movq	#50, r0
	trap	#0
f51:	movq	#51, r0
	trap	#0
f52:	movq	#52, r0
	trap	#0
f53:	movq	#53, r0
	trap	#0
f54:	movq	#54, r0
	trap	#0
f55:	movq	#55, r0
	trap	#0
f56:	movq	#56, r0
	trap	#0
f57:	movq	#57, r0
	trap	#0
f58:	movq	#58, r0
	trap	#0
f59:	movq	#59, r0
	trap	#0
f60:	movq	#60, r0
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
