; k_gray, form: one vec2 block for the whole tile (errata 176).  r0 = g, r1 = g stride, r2 = rgba, r3 = rgba stride, r4 = w (pixels), r5 = h.
; RGBA to gray, (77 r + 150 g + 29 b) >> 8, with one segment load for the four fields.
k_gray:
	movq	r4,r6
	shl	#2,r6			; bytes of a row of rgba
	movq	r3,r29
	sub	r6,r29
	movq	r1,r30
	sub	r4,r30
	lea	(r2)(r6),r7
	vec2	r2,r7,r5,r6
	vskip	r2,r29
	vskip	r0,r30
	vlseg4.bu.w	v0,(r2)+
	vmul.w	v0,v0,#77
	vmul.w	v1,v1,#150
	vmul.w	v2,v2,#29
	vadd.w	v0,v0,v1
	vadd.w	v0,v0,v2
	vshr.w	v0,v0,#8
	vst.w.b	v0,(r0)+
	vend
	ret
