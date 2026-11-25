# sum of n 16-bit words with RISC-V vectors (a strip-mined loop: the program sets the strip each time round)
	li	t2, 0
loop:	vsetvli	t0, a1, e16, m1, ta, ma
	vle16.v	v8, (a0)
	vsetvli	zero, t0, e32, m2, ta, ma
	vzext.vf2 v12, v8
	vmv.s.x	v16, zero
	vredsum.vs v16, v12, v16
	vmv.x.s	t3, v16
	add	t2, t2, t3
	sub	a1, a1, t0
	slli	t0, t0, 1
	add	a0, a0, t0
	bnez	a1, loop
