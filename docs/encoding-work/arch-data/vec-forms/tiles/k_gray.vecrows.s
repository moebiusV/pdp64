; k_gray, form: a scalar row loop around a 1D vec block (the existing form).  r0 = g, r1 = g stride, r2 = rgba, r3 = rgba stride, r4 = w (pixels), r5 = h.
; RGBA to gray, (77 r + 150 g + 29 b) >> 8, with one segment load for the four fields.
k_gray:
	movq	r4,r6
	shl	#2,r6			; bytes of a row of rgba
	movq	r3,r29
	sub	r6,r29
	movq	r1,r30
	sub	r4,r30
.row:
	lea	(r2)(r6),r7
	vec	r2,r7
	vlseg4.bu.w	v0,(r2)+
	vmul.w	v0,v0,#77
	vmul.w	v1,v1,#150
	vmul.w	v2,v2,#29
	vadd.w	v0,v0,v1
	vadd.w	v0,v0,v2
	vshr.w	v0,v0,#8
	vst.w.b	v0,(r0)+
	vend
	add	r29,r2
	add	r30,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
