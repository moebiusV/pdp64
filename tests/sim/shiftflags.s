; shl, shr and sar write the same flags for every count (errata 39): N and Z from the result (a count of 0 leaves the operand), V = 0, C = the last
; bit shifted out, and C = 0 for a count of 0.  Counts 0, 1, 2, 31, 63, 64, 65 and 100 in a register with the flags all set before, and immediates 0, 1, 15
; (one-parcel forms), 16 and 63 with the flags all clear before.  Expectations from a model of the definition, written out as constants.  Exit n on failure.
	.text
	.globl	_start
_start:
	movq	#0, r11
	movq	=0x8000000000000001, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f1
	cmp	r3, =0x8000000000000001
	bne	f1
	movq	=0x8000000000000001, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f2
	cmp	r3, =0x2
	bne	f2
	movq	=0x8000000000000001, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f3
	cmp	r3, =0x4
	bne	f3
	movq	=0x8000000000000001, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f4
	cmp	r3, =0x80000000
	bne	f4
	movq	=0x8000000000000001, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f5
	cmp	r3, =0x8000000000000000
	bne	f5
	movq	=0x8000000000000001, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #5
	bne	f6
	cmp	r3, =0x0
	bne	f6
	movq	=0x8000000000000001, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f7
	cmp	r3, =0x0
	bne	f7
	movq	=0x8000000000000001, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f8
	cmp	r3, =0x0
	bne	f8
	movq	=0x8000000000000001, r3
	mtps	r11
	shl	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f9
	cmp	r3, =0x8000000000000001
	bne	f9
	movq	=0x8000000000000001, r3
	mtps	r11
	shl	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f10
	cmp	r3, =0x2
	bne	f10
	movq	=0x8000000000000001, r3
	mtps	r11
	shl	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f11
	cmp	r3, =0x8000
	bne	f11
	movq	=0x8000000000000001, r3
	mtps	r11
	shl	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f12
	cmp	r3, =0x10000
	bne	f12
	movq	=0x8000000000000001, r3
	mtps	r11
	shl	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f13
	cmp	r3, =0x8000000000000000
	bne	f13
	movq	=0xF0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f14
	cmp	r3, =0xF0
	bne	f14
	movq	=0xF0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f15
	cmp	r3, =0x1E0
	bne	f15
	movq	=0xF0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f16
	cmp	r3, =0x3C0
	bne	f16
	movq	=0xF0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f17
	cmp	r3, =0x7800000000
	bne	f17
	movq	=0xF0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f18
	cmp	r3, =0x0
	bne	f18
	movq	=0xF0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f19
	cmp	r3, =0x0
	bne	f19
	movq	=0xF0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f20
	cmp	r3, =0x0
	bne	f20
	movq	=0xF0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f21
	cmp	r3, =0x0
	bne	f21
	movq	=0xF0, r3
	mtps	r11
	shl	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f22
	cmp	r3, =0xF0
	bne	f22
	movq	=0xF0, r3
	mtps	r11
	shl	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f23
	cmp	r3, =0x1E0
	bne	f23
	movq	=0xF0, r3
	mtps	r11
	shl	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f24
	cmp	r3, =0x780000
	bne	f24
	movq	=0xF0, r3
	mtps	r11
	shl	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f25
	cmp	r3, =0xF00000
	bne	f25
	movq	=0xF0, r3
	mtps	r11
	shl	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f26
	cmp	r3, =0x0
	bne	f26
	movq	=0x0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f27
	cmp	r3, =0x0
	bne	f27
	movq	=0x0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f28
	cmp	r3, =0x0
	bne	f28
	movq	=0x0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f29
	cmp	r3, =0x0
	bne	f29
	movq	=0x0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f30
	cmp	r3, =0x0
	bne	f30
	movq	=0x0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f31
	cmp	r3, =0x0
	bne	f31
	movq	=0x0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f32
	cmp	r3, =0x0
	bne	f32
	movq	=0x0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f33
	cmp	r3, =0x0
	bne	f33
	movq	=0x0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f34
	cmp	r3, =0x0
	bne	f34
	movq	=0x0, r3
	mtps	r11
	shl	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f35
	cmp	r3, =0x0
	bne	f35
	movq	=0x0, r3
	mtps	r11
	shl	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f36
	cmp	r3, =0x0
	bne	f36
	movq	=0x0, r3
	mtps	r11
	shl	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f37
	cmp	r3, =0x0
	bne	f37
	movq	=0x0, r3
	mtps	r11
	shl	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f38
	cmp	r3, =0x0
	bne	f38
	movq	=0x0, r3
	mtps	r11
	shl	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f39
	cmp	r3, =0x0
	bne	f39
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f40
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f40
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f41
	cmp	r3, =0xFFFFFFFFFFFFFFFE
	bne	f41
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f42
	cmp	r3, =0xFFFFFFFFFFFFFFFC
	bne	f42
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f43
	cmp	r3, =0xFFFFFFFF80000000
	bne	f43
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f44
	cmp	r3, =0x8000000000000000
	bne	f44
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #5
	bne	f45
	cmp	r3, =0x0
	bne	f45
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f46
	cmp	r3, =0x0
	bne	f46
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shl	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f47
	cmp	r3, =0x0
	bne	f47
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shl	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f48
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f48
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shl	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f49
	cmp	r3, =0xFFFFFFFFFFFFFFFE
	bne	f49
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shl	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f50
	cmp	r3, =0xFFFFFFFFFFFF8000
	bne	f50
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shl	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f51
	cmp	r3, =0xFFFFFFFFFFFF0000
	bne	f51
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shl	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f52
	cmp	r3, =0x8000000000000000
	bne	f52
	movq	=0x8000000000000001, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f53
	cmp	r3, =0x8000000000000001
	bne	f53
	movq	=0x8000000000000001, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f54
	cmp	r3, =0x4000000000000000
	bne	f54
	movq	=0x8000000000000001, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f55
	cmp	r3, =0x2000000000000000
	bne	f55
	movq	=0x8000000000000001, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f56
	cmp	r3, =0x100000000
	bne	f56
	movq	=0x8000000000000001, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f57
	cmp	r3, =0x1
	bne	f57
	movq	=0x8000000000000001, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #5
	bne	f58
	cmp	r3, =0x0
	bne	f58
	movq	=0x8000000000000001, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f59
	cmp	r3, =0x0
	bne	f59
	movq	=0x8000000000000001, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f60
	cmp	r3, =0x0
	bne	f60
	movq	=0x8000000000000001, r3
	mtps	r11
	shr	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f61
	cmp	r3, =0x8000000000000001
	bne	f61
	movq	=0x8000000000000001, r3
	mtps	r11
	shr	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f62
	cmp	r3, =0x4000000000000000
	bne	f62
	movq	=0x8000000000000001, r3
	mtps	r11
	shr	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f63
	cmp	r3, =0x1000000000000
	bne	f63
	movq	=0x8000000000000001, r3
	mtps	r11
	shr	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f64
	cmp	r3, =0x800000000000
	bne	f64
	movq	=0x8000000000000001, r3
	mtps	r11
	shr	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f65
	cmp	r3, =0x1
	bne	f65
	movq	=0xF0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f66
	cmp	r3, =0xF0
	bne	f66
	movq	=0xF0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f67
	cmp	r3, =0x78
	bne	f67
	movq	=0xF0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f68
	cmp	r3, =0x3C
	bne	f68
	movq	=0xF0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f69
	cmp	r3, =0x0
	bne	f69
	movq	=0xF0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f70
	cmp	r3, =0x0
	bne	f70
	movq	=0xF0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f71
	cmp	r3, =0x0
	bne	f71
	movq	=0xF0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f72
	cmp	r3, =0x0
	bne	f72
	movq	=0xF0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f73
	cmp	r3, =0x0
	bne	f73
	movq	=0xF0, r3
	mtps	r11
	shr	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f74
	cmp	r3, =0xF0
	bne	f74
	movq	=0xF0, r3
	mtps	r11
	shr	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f75
	cmp	r3, =0x78
	bne	f75
	movq	=0xF0, r3
	mtps	r11
	shr	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f76
	cmp	r3, =0x0
	bne	f76
	movq	=0xF0, r3
	mtps	r11
	shr	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f77
	cmp	r3, =0x0
	bne	f77
	movq	=0xF0, r3
	mtps	r11
	shr	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f78
	cmp	r3, =0x0
	bne	f78
	movq	=0x0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f79
	cmp	r3, =0x0
	bne	f79
	movq	=0x0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f80
	cmp	r3, =0x0
	bne	f80
	movq	=0x0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f81
	cmp	r3, =0x0
	bne	f81
	movq	=0x0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f82
	cmp	r3, =0x0
	bne	f82
	movq	=0x0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f83
	cmp	r3, =0x0
	bne	f83
	movq	=0x0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f84
	cmp	r3, =0x0
	bne	f84
	movq	=0x0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f85
	cmp	r3, =0x0
	bne	f85
	movq	=0x0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f86
	cmp	r3, =0x0
	bne	f86
	movq	=0x0, r3
	mtps	r11
	shr	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f87
	cmp	r3, =0x0
	bne	f87
	movq	=0x0, r3
	mtps	r11
	shr	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f88
	cmp	r3, =0x0
	bne	f88
	movq	=0x0, r3
	mtps	r11
	shr	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f89
	cmp	r3, =0x0
	bne	f89
	movq	=0x0, r3
	mtps	r11
	shr	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f90
	cmp	r3, =0x0
	bne	f90
	movq	=0x0, r3
	mtps	r11
	shr	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f91
	cmp	r3, =0x0
	bne	f91
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f92
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f92
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f93
	cmp	r3, =0x7FFFFFFFFFFFFFFF
	bne	f93
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f94
	cmp	r3, =0x3FFFFFFFFFFFFFFF
	bne	f94
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f95
	cmp	r3, =0x1FFFFFFFF
	bne	f95
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f96
	cmp	r3, =0x1
	bne	f96
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #5
	bne	f97
	cmp	r3, =0x0
	bne	f97
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f98
	cmp	r3, =0x0
	bne	f98
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	shr	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f99
	cmp	r3, =0x0
	bne	f99
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shr	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f100
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f100
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shr	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f101
	cmp	r3, =0x7FFFFFFFFFFFFFFF
	bne	f101
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shr	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f102
	cmp	r3, =0x1FFFFFFFFFFFF
	bne	f102
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shr	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f103
	cmp	r3, =0xFFFFFFFFFFFF
	bne	f103
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	shr	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #1
	bne	f104
	cmp	r3, =0x1
	bne	f104
	movq	=0x8000000000000001, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f105
	cmp	r3, =0x8000000000000001
	bne	f105
	movq	=0x8000000000000001, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f106
	cmp	r3, =0xC000000000000000
	bne	f106
	movq	=0x8000000000000001, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f107
	cmp	r3, =0xE000000000000000
	bne	f107
	movq	=0x8000000000000001, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f108
	cmp	r3, =0xFFFFFFFF00000000
	bne	f108
	movq	=0x8000000000000001, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f109
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f109
	movq	=0x8000000000000001, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f110
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f110
	movq	=0x8000000000000001, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f111
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f111
	movq	=0x8000000000000001, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f112
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f112
	movq	=0x8000000000000001, r3
	mtps	r11
	sar	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f113
	cmp	r3, =0x8000000000000001
	bne	f113
	movq	=0x8000000000000001, r3
	mtps	r11
	sar	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f114
	cmp	r3, =0xC000000000000000
	bne	f114
	movq	=0x8000000000000001, r3
	mtps	r11
	sar	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f115
	cmp	r3, =0xFFFF000000000000
	bne	f115
	movq	=0x8000000000000001, r3
	mtps	r11
	sar	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f116
	cmp	r3, =0xFFFF800000000000
	bne	f116
	movq	=0x8000000000000001, r3
	mtps	r11
	sar	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f117
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f117
	movq	=0xF0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f118
	cmp	r3, =0xF0
	bne	f118
	movq	=0xF0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f119
	cmp	r3, =0x78
	bne	f119
	movq	=0xF0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f120
	cmp	r3, =0x3C
	bne	f120
	movq	=0xF0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f121
	cmp	r3, =0x0
	bne	f121
	movq	=0xF0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f122
	cmp	r3, =0x0
	bne	f122
	movq	=0xF0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f123
	cmp	r3, =0x0
	bne	f123
	movq	=0xF0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f124
	cmp	r3, =0x0
	bne	f124
	movq	=0xF0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f125
	cmp	r3, =0x0
	bne	f125
	movq	=0xF0, r3
	mtps	r11
	sar	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f126
	cmp	r3, =0xF0
	bne	f126
	movq	=0xF0, r3
	mtps	r11
	sar	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #0
	bne	f127
	cmp	r3, =0x78
	bne	f127
	movq	=0xF0, r3
	mtps	r11
	sar	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f128
	cmp	r3, =0x0
	bne	f128
	movq	=0xF0, r3
	mtps	r11
	sar	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f129
	cmp	r3, =0x0
	bne	f129
	movq	=0xF0, r3
	mtps	r11
	sar	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f130
	cmp	r3, =0x0
	bne	f130
	movq	=0x0, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f131
	cmp	r3, =0x0
	bne	f131
	movq	=0x0, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f132
	cmp	r3, =0x0
	bne	f132
	movq	=0x0, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f133
	cmp	r3, =0x0
	bne	f133
	movq	=0x0, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f134
	cmp	r3, =0x0
	bne	f134
	movq	=0x0, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f135
	cmp	r3, =0x0
	bne	f135
	movq	=0x0, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f136
	cmp	r3, =0x0
	bne	f136
	movq	=0x0, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f137
	cmp	r3, =0x0
	bne	f137
	movq	=0x0, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f138
	cmp	r3, =0x0
	bne	f138
	movq	=0x0, r3
	mtps	r11
	sar	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f139
	cmp	r3, =0x0
	bne	f139
	movq	=0x0, r3
	mtps	r11
	sar	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f140
	cmp	r3, =0x0
	bne	f140
	movq	=0x0, r3
	mtps	r11
	sar	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f141
	cmp	r3, =0x0
	bne	f141
	movq	=0x0, r3
	mtps	r11
	sar	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f142
	cmp	r3, =0x0
	bne	f142
	movq	=0x0, r3
	mtps	r11
	sar	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #4
	bne	f143
	cmp	r3, =0x0
	bne	f143
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#0, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f144
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f144
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#1, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f145
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f145
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#2, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f146
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f146
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#31, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f147
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f147
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#63, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f148
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f148
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#64, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f149
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f149
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#65, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f150
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f150
	movq	=0xFFFFFFFFFFFFFFFF, r3
	movq	#100, r4
	movq	#15, r6
	mtps	r6
	sar	r4, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f151
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f151
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	sar	#0, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #8
	bne	f152
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f152
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	sar	#1, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f153
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f153
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	sar	#15, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f154
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f154
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	sar	#16, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f155
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f155
	movq	=0xFFFFFFFFFFFFFFFF, r3
	mtps	r11
	sar	#63, r3
	mfps	r7
	and	#15, r7
	cmp	r7, #9
	bne	f156
	cmp	r3, =0xFFFFFFFFFFFFFFFF
	bne	f156
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
f79:	movq	#79, r0
	trap	#0
f80:	movq	#80, r0
	trap	#0
f81:	movq	#81, r0
	trap	#0
f82:	movq	#82, r0
	trap	#0
f83:	movq	#83, r0
	trap	#0
f84:	movq	#84, r0
	trap	#0
f85:	movq	#85, r0
	trap	#0
f86:	movq	#86, r0
	trap	#0
f87:	movq	#87, r0
	trap	#0
f88:	movq	#88, r0
	trap	#0
f89:	movq	#89, r0
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
f98:	movq	#98, r0
	trap	#0
f99:	movq	#99, r0
	trap	#0
f100:	movq	#100, r0
	trap	#0
f101:	movq	#101, r0
	trap	#0
f102:	movq	#102, r0
	trap	#0
f103:	movq	#103, r0
	trap	#0
f104:	movq	#104, r0
	trap	#0
f105:	movq	#105, r0
	trap	#0
f106:	movq	#106, r0
	trap	#0
f107:	movq	#107, r0
	trap	#0
f108:	movq	#108, r0
	trap	#0
f109:	movq	#109, r0
	trap	#0
f110:	movq	#110, r0
	trap	#0
f111:	movq	#111, r0
	trap	#0
f112:	movq	#112, r0
	trap	#0
f113:	movq	#113, r0
	trap	#0
f114:	movq	#114, r0
	trap	#0
f115:	movq	#115, r0
	trap	#0
f116:	movq	#116, r0
	trap	#0
f117:	movq	#117, r0
	trap	#0
f118:	movq	#118, r0
	trap	#0
f119:	movq	#119, r0
	trap	#0
f120:	movq	#120, r0
	trap	#0
f121:	movq	#121, r0
	trap	#0
f122:	movq	#122, r0
	trap	#0
f123:	movq	#123, r0
	trap	#0
f124:	movq	#124, r0
	trap	#0
f125:	movq	#125, r0
	trap	#0
f126:	movq	#126, r0
	trap	#0
f127:	movq	#127, r0
	trap	#0
f128:	movq	#128, r0
	trap	#0
f129:	movq	#129, r0
	trap	#0
f130:	movq	#130, r0
	trap	#0
f131:	movq	#131, r0
	trap	#0
f132:	movq	#132, r0
	trap	#0
f133:	movq	#133, r0
	trap	#0
f134:	movq	#134, r0
	trap	#0
f135:	movq	#135, r0
	trap	#0
f136:	movq	#136, r0
	trap	#0
f137:	movq	#137, r0
	trap	#0
f138:	movq	#138, r0
	trap	#0
f139:	movq	#139, r0
	trap	#0
f140:	movq	#140, r0
	trap	#0
f141:	movq	#141, r0
	trap	#0
f142:	movq	#142, r0
	trap	#0
f143:	movq	#143, r0
	trap	#0
f144:	movq	#144, r0
	trap	#0
f145:	movq	#145, r0
	trap	#0
f146:	movq	#146, r0
	trap	#0
f147:	movq	#147, r0
	trap	#0
f148:	movq	#148, r0
	trap	#0
f149:	movq	#149, r0
	trap	#0
f150:	movq	#150, r0
	trap	#0
f151:	movq	#151, r0
	trap	#0
f152:	movq	#152, r0
	trap	#0
f153:	movq	#153, r0
	trap	#0
f154:	movq	#154, r0
	trap	#0
f155:	movq	#155, r0
	trap	#0
f156:	movq	#156, r0
	trap	#0
