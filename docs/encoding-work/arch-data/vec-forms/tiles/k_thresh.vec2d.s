; k_thresh, form: one vec2 block for the whole tile (errata 176).  r0 = d, r1 = d stride, r2 = s, r3 = s stride, r4 = w, r5 = h.
; d = s > 128 ? 255 : 0 on bytes (binarising an image).
k_thresh:
	movq	r3,r29
	sub	r4,r29
	movq	r1,r30
	sub	r4,r30
	lea	(r2)(r4),r7
	vec2	r2,r7,r5,r4
	vskip	r2,r29
	vskip	r0,r30
	vld.bu	v0,(r2)+
	vcgtu.b	v1,v0,#128
	vst.b	v1,(r0)+
	vend
	ret
