	.text
	; the fourteen conversions written with the format of each operand, then the three short forms; fcvt.words holds the parcels of the instructions of the encoding that they name (fcvtdq, fcvtdqu, fcvtqd, fcvtqud, fcvtds, fcvtsd, fcvtsl, fcvtls, fcvtsh, fcvths, fcvtdh, fcvthd, fcvthl, fcvtlh, then fcvtqd, fcvtqud, fcvtls)
	fcvt	r1.f64, r2.s64
	fcvt	r3.f64, r4.u64
	fcvt	r5.s64, r6.f64
	fcvt	r7.u64, r8.f64
	fcvt	r9.f64, r10.f32
	fcvt	r11.f32, r12.f64
	fcvt	r13.f32, r14.s32
	fcvt	r15.s32, r16.f32
	fcvt	r17.f32, r18.f16
	fcvt	r19.f16, r20.f32
	fcvt	r21.f64, r22.f16
	fcvt	r23.f16, r24.f64
	fcvt	r25.f16, r26.s32
	fcvt	r27.s32, r28.f16
	fcvt.s64	r5, r6
	fcvt.u64	r7, r8
	fcvt.s32	r15, r16
