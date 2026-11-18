; k_blend, form: one vec2 block for the whole tile (errata 176).  r0 = d (read and written in place), r1 = s, r2 = alpha, r3 = pitch of the three, r4 = w, r5 = h.
; d = (s*a + d*(255-a) + 128 + the carry correction) >> 8 on bytes in 16-bit lanes (alpha blending of a tile).
k_blend:
	movq	r3,r29
	sub	r4,r29			; pitch - w
	movq	r0,r6			; the read pointer of d; r0 stores
	lea	(r6)(r4),r7
	vec2	r6,r7,r5,r4
	vskip	r6,r29
	vskip	r1,r29
	vskip	r2,r29
	vskip	r0,r29
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
	ret
