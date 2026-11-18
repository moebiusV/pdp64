; k_blend, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d (read and written in place), r1 = s, r2 = alpha, r3 = pitch of the three, r4 = w, r5 = h.
; d = (s*a + d*(255-a) + 128 + the carry correction) >> 8 on bytes in 16-bit lanes (alpha blending of a tile).
k_blend:
	movq	r3,r29
	sub	r4,r29			; pitch - w
	movq	r0,r6			; the read pointer of d; r0 stores
.row:
	lea	(r6)(r4),r7
	vec	r6,r7
	vld.bu.w	v0,(r6)+
	vld.bu.w	v1,(r1)+
	vld.bu.w	v2,(r2)+
	vmul.w	v3,v1,v2
	vsubr.w	v2,v2,#255
	vmul.w	v4,v0,v2
	vadd.w	v3,v3,v4
	vadd.w	v3,v3,#128
	vshr.w	v4,v3,#8
	vadd.w	v3,v3,v4
	vshr.w	v3,v3,#8
	vst.w.b	v3,(r0)+
	vend
	add	r29,r6
	add	r29,r1
	add	r29,r2
	add	r29,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
