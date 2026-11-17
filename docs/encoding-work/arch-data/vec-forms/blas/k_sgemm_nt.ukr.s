; k_sgemm_nt, form 2: the micro-kernel of a register-blocked GEMM, 8 rows x VL columns of C in eight hidden accumulators, over packed panels (what OpenBLAS's
; copy routines make: A packed 8 floats for each k, B packed VL floats for each k).  C[8 x VL] += A_panel . B_panel.
; r0 = packed A, r1 = packed B, r2 = C tile, r3 = K, r4 = ldc in bytes.
; vlen.f gives VL, the floats of a strip (what `cntw` is in SVE and `vsetvli` in RISC-V vector): the packing of B depends on it.
k_ukr:
	vlen.f	r5
	movq	r3,r6
	mul	r5,r6
	lea	(r1)(r6*4),r6		; end of the B panel: K strips of VL floats
	vclr.f	v0,#8			; v0..v7 = 0
	vec	r1,r6			; one strip is one k step
	vld.f	v8,(r1)+		; B[k, 0..VL)
	vfmab.f	v0,v8,(r0)+		; v0 += v8 * broadcast of the float at (r0); r0 moves by one float
	vfmab.f	v1,v8,(r0)+
	vfmab.f	v2,v8,(r0)+
	vfmab.f	v3,v8,(r0)+
	vfmab.f	v4,v8,(r0)+
	vfmab.f	v5,v8,(r0)+
	vfmab.f	v6,v8,(r0)+
	vfmab.f	v7,v8,(r0)+
	vend
	vld.f	v9,(r2)			; C += acc: eight rows (beta = 1)
	vadd.f	v9,v9,v0
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v1
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v2
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v3
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v4
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v5
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v6
	vst.f	v9,(r2)
	add	r4,r2
	vld.f	v9,(r2)
	vadd.f	v9,v9,v7
	vst.f	v9,(r2)
	ret
