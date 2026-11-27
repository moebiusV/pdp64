; k_sgemm_nt, form 2: the micro-kernel of a register-blocked GEMM, 8 rows x 4 columns of C in eight hidden accumulators, over packed panels (what OpenBLAS's copy routines make: A packed
; 8 floats for each k, B packed 4 floats for each k).  C[8 x 4] += A_panel . B_panel.  r0 = packed A, r1 = packed B, r2 = C tile, r3 = K, r4 = ldc in bytes.
; Errata 173: the strip is invisible, so the tile is 4 columns = 16 bytes = the least strip of the architecture: a block with accumulators (vclr) or a vfmab has a strip of exactly 16 bytes on every
; implementation, one strip is one k step, and nothing here depends on the width of the implementation (before, `vlen.b` gave the strip and the packing of B depended on it).  A wider C is several
; calls, one for each 4 columns.  The accumulators are read out once, after the last strip, by the epilogue after `vfin` (adding C, one row each: the eight row pointers are made before the block).
k_ukr:
	mov	r3,r6
	shl	#4,r6			; K * 16 bytes: four floats for each k
	add	r1,r6			; end of the B panel
	mov	r2,r16			; the eight rows of the C tile
	lea	(r16)(r4*1),r17
	lea	(r17)(r4*1),r18
	lea	(r18)(r4*1),r19
	lea	(r19)(r4*1),r20
	lea	(r20)(r4*1),r21
	lea	(r21)(r4*1),r22
	lea	(r22)(r4*1),r23
	vec	r1,r6			; one strip is one k step
	vclr.f	v0,#8			; v0..v7 = 0 (the first strip only)
	vld.f	v8,(r1)+		; B[k, 0..4)
	vfmab.f	v0,v8,(r0)+		; v0 += v8 * broadcast of the float at (r0); r0 moves by one float
	vfmab.f	v1,v8,(r0)+
	vfmab.f	v2,v8,(r0)+
	vfmab.f	v3,v8,(r0)+
	vfmab.f	v4,v8,(r0)+
	vfmab.f	v5,v8,(r0)+
	vfmab.f	v6,v8,(r0)+
	vfmab.f	v7,v8,(r0)+
	vfin				; after the last strip, once:
	vld.f	v9,(r16)		; C += acc: eight rows (beta = 1)
	vadd.f	v9,v9,v0
	vst.f	v9,(r16)
	vld.f	v9,(r17)
	vadd.f	v9,v9,v1
	vst.f	v9,(r17)
	vld.f	v9,(r18)
	vadd.f	v9,v9,v2
	vst.f	v9,(r18)
	vld.f	v9,(r19)
	vadd.f	v9,v9,v3
	vst.f	v9,(r19)
	vld.f	v9,(r20)
	vadd.f	v9,v9,v4
	vst.f	v9,(r20)
	vld.f	v9,(r21)
	vadd.f	v9,v9,v5
	vst.f	v9,(r21)
	vld.f	v9,(r22)
	vadd.f	v9,v9,v6
	vst.f	v9,(r22)
	vld.f	v9,(r23)
	vadd.f	v9,v9,v7
	vst.f	v9,(r23)
	vend
	ret
