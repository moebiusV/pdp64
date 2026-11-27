	.text
	; the explicit 64-bit spelling is the bare word: mov is mov.s64, aadd is aadd.s64, fadd is fadd.f64, div is div.s64
	mov.s64 (r1), r2
	mov.u64 r1, 4(r2)
	mov.s64 r1, r2
	mov.s64 $5, r1
	mov.user.s64 (r1), r2
	mov.user.u64 r1, (r2)
	bswap.s64 r1, r2
	bswap.u64 r1, r2
	ror.s64 r1, $5, r2
	ror.u64 r1, r2, r3
	mul.s64 r1, r2
	mul.u64 r1, r2
	div.s64 r1, r2, r3
	mod.s64 r1, r2, r3
	mulh.s64 r1, r2
	min.s64 r1, r2, r3
	max.s64 r1, r2, r3
	cas.s64 r1, (r2), r3
	cas.u64 r1, (r2), r3
	swap.s64 r1, (r2), r3
	aadd.s64 r1, (r2), r3
	aadd.u64 r1, (r2), r3
	aand.s64 r1, (r2), r3
	abis.s64 r1, (r2), r3
	axor.u64 r1, (r2), r3
	ll.s64 (r2), r1
	ll.u64 (r2), r1
	sc.s64 r1, (r2), r3
	amax.s64 r1, (r2), r3
	amin.s64 r1, (r2), r3
	fadd.f64 r1, r2
	fsub.f64 r1, r2
	fmul.f64 r1, r2
	fdiv.f64 r1, r2
	fsqrt.f64 r1, r2
	fmadd.f64 r1, r2, r3, r4
	fnmsub.f64 r1, r2, r3, r4
	fclass.f64 r1, r2
	fabs.f64 r1, r2
	fneg.f64 r1, r2
	fmin.f64 r1, r2, r3
	fmax.f64 r1, r2, r3
	fcopysign.f64 r1, r2, r3
	frint.f64 r1, r2
	frintz.f64 r1, r2
	fcblt.f64 r1, r2, L
	fcbeq.f64 r1, r2, L
L:
