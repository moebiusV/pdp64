; k_sgemm_nt, form 3: the micro-kernel with a hidden tile accumulator t0 (VL x VL floats) and an outer-product instruction (what FMOPA is in ARM SME and the
; tile multiplies are in Intel AMX and POWER MMA).  Same packed panels, MR = NR = VL.  r0 = packed A, r1 = packed B, r2 = C tile, r3 = K, r4 = ldc in bytes.
k_ukr:
	vlen.f	r5
	movq	r3,r6
	mul	r5,r6
	lea	(r1)(r6*4),r6
	vtclr	t0			; the tile = 0
	vec	r1,r6
	vld.f	v8,(r1)+		; B[k, 0..VL)
	vld.f	v9,(r0)+		; A[0..VL, k)
	vtfmopa.f t0,v9,v8		; t0[i][j] += v9[i] * v8[j]: VL*VL multiply-adds
	vend
	vtld.f	t1,(r2),r4		; C tile, rows ldc bytes apart
	vtadd.f	t0,t0,t1
	vtst.f	t0,(r2),r4
	ret
