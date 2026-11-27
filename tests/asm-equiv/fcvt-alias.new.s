	.text
	; the three short forms (an integer to a float of the same width) in place of the official form of the same instruction; the rest are the official form
	fcvt	r1.f64, r2.s64
	fcvt	r3.f64, r4.u64
	fcvt.s64	r5, r6
	fcvt.u64	r7, r8
	fcvt	r9.f64, r10.f32
	fcvt	r11.f32, r12.f64
	fcvt	r13.f32, r14.s32
	fcvt.s32	r15, r16
	fcvt	r17.f32, r18.f16
	fcvt	r19.f16, r20.f32
	fcvt	r21.f64, r22.f16
	fcvt	r23.f16, r24.f64
	fcvt	r25.f16, r26.s32
	fcvt	r27.s32, r28.f16
