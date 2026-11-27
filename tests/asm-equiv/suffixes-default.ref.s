	.text
	; the explicit 64-bit spelling is the bare word: mov is mov.s64, aadd is aadd.s64, fadd is fadd.f64, div is div.s64
	mov (r1), r2
	mov r1, 4(r2)
	mov r1, r2
	mov $5, r1
	mov.user (r1), r2
	mov.user r1, (r2)
	bswap r1, r2
	bswap r1, r2
	ror r1, $5, r2
	ror r1, r2, r3
	mul r1, r2
	mul r1, r2
	div r1, r2, r3
	mod r1, r2, r3
	mulh r1, r2
	min r1, r2, r3
	max r1, r2, r3
	cas r1, (r2), r3
	cas r1, (r2), r3
	swap r1, (r2), r3
	aadd r1, (r2), r3
	aadd r1, (r2), r3
	aand r1, (r2), r3
	abis r1, (r2), r3
	axor r1, (r2), r3
	ll (r2), r1
	ll (r2), r1
	sc r1, (r2), r3
	amax r1, (r2), r3
	amin r1, (r2), r3
	fadd r1, r2
	fsub r1, r2
	fmul r1, r2
	fdiv r1, r2
	fsqrt r1, r2
	fmadd r1, r2, r3, r4
	fnmsub r1, r2, r3, r4
	fclass r1, r2
	fabs r1, r2
	fneg r1, r2
	fmin r1, r2, r3
	fmax r1, r2, r3
	fcopysign r1, r2, r3
	frint r1, r2
	frintz r1, r2
	fcblt r1, r2, L
	fcbeq r1, r2, L
L:
