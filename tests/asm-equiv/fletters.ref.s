	.text
L:
	fadd r1.32, r2.32
	fadd r1, r2
	fadd r1.64, r2.64
	fadd r1.32, r2.32
	fsub r1.32, r2.32
	fsub r1, r2
	fsub r1.64, r2.64
	fsub r1.32, r2.32
	fmul r1.32, r2.32
	fmul r1, r2
	fmul r1.64, r2.64
	fmul r1.32, r2.32
	fdiv r1.32, r2.32
	fdiv r1, r2
	fdiv r1.64, r2.64
	fdiv r1.32, r2.32
	fsqrt r1.32, r2.32
	fsqrt r1, r2
	fsqrt r3, r4
	fclass r1.32, r2
	fclass r1.64, r2
	fclass r3, r4
	fabs r1.32, r1
	fabs r1.32, r2
	fabs r1, r2
	fneg r1.32, r1
	fneg r1.32, r2
	fneg r1, r2
	fmadd r1.32, r2.32, r3.32, r4.32
	fmadd r1.64, r2, r3, r4
	fnmsub r1.32, r2.32, r3.32, r4.32
	fnmsub r1, r2, r3, r4
	fcbeq r1.32, r2.32, L
	fcbeq r1.64, r2.64, L
	fcbne r1.32, r2.32, L
	fcbne r1.64, r2.64, L
	fcblt r1.32, r2.32, L
	fcblt r1.64, r2.64, L
	fcble r1.32, r2.32, L
	fcble r1.64, r2.64, L
	fcbgt r1.32, r2.32, L
	fcbgt r1.64, r2.64, L
	fcbge r1.32, r2.32, L
	fcbge r1.64, r2.64, L
	fcbor r1.32, r2.32, L
	fcbor r1.64, r2.64, L
	fcbuo r1.32, r2.32, L
	fcbuo r1.64, r2.64, L
	fcvt r1.64, r2.32
	fcvt r1.32, r2.64
	fcvt r1.64, r2.32
	fcvt r1.32, r2.64
