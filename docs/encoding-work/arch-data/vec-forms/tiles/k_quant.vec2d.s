; k_quant, form: one vec2 block for the whole tile (errata 176).  r0 = d (bytes), r1 = d stride, r2 = s (floats), r3 = s stride in bytes, r4 = w, r5 = h.
; d = clamp(trunc(s * 0.375), -128, 127): the quantisation of a tile of floats to bytes.
k_quant:
	movq	r4,r6
	shl	#2,r6			; bytes of a row of floats
	movq	=0x3ec00000,r27	; 0.375f
	movq	r3,r29
	sub	r6,r29
	movq	r1,r30
	sub	r4,r30
	lea	(r2)(r6),r7
	vec2	r2,r7,r5,r6
	vskip	r2,r29
	vskip	r0,r30
	vld.f	v0,(r2)+
	vmul.f	v0,v0,r27
	vcvt.f.l	v1,v0
	vsts.l.b	v1,(r0)+
	vend
	ret
