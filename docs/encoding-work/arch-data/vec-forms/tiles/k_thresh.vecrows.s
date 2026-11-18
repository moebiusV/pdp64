; k_thresh, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d, r1 = d stride, r2 = s, r3 = s stride, r4 = w, r5 = h.
; d = s > 128 ? 255 : 0 on bytes (binarising an image).
k_thresh:
	movq	r3,r29
	sub	r4,r29
	movq	r1,r30
	sub	r4,r30
.row:
	lea	(r2)(r4),r7
	vec	r2,r7
	vld.bu	v0,(r2)+
	vcgtu.b	v1,v0,#128
	vst.b	v1,(r0)+
	vend
	add	r29,r2
	add	r30,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
