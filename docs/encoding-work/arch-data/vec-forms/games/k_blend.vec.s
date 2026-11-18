; k_blend: dst = (src*a + dst*(255-a) + 128 + the carry correction) >> 8 on 8-bit channels (alpha blending of a row).  r0 = dst, r1 = src, r2 = alpha, r3 = n.
; 16-bit lanes: 255 * 255 + 128 fits.  Three streams in, one out; a widening multiply and a narrowing store.
k_blend:
	lea	(r0)(r3),r4
	movq	r0,r5			; dst read pointer; r0 stores
	vec	r5,r4
	vld.bu.w v0,(r5)+		; dst
	vld.bu.w v1,(r1)+		; src
	vld.bu.w v2,(r2)+		; alpha
	vmul.w	v3,v1,v2		; src * a
	vsubr.w	v2,v2,#255		; 255 - a
	vmul.w	v4,v0,v2		; dst * (255 - a)
	vadd.w	v3,v3,v4
	vadd.w	v3,v3,#128
	vshr.w	v4,v3,#8
	vadd.w	v3,v3,v4
	vshr.w	v3,v3,#8
	vst.w.b	v3,(r0)+		; narrow to bytes
	vend
	ret
