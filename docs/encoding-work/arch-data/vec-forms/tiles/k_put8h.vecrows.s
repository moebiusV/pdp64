; k_put8h, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d, r1 = d stride, r2 = s, r3 = s stride, r4 = w, r5 = h; the taps are the bytes of g_coef.
; The 8-tap horizontal filter d = clip((sum g_coef[k] * s[x+k-3] + 32) >> 6) over a tile (the shape of the codecs' put_8tap_h), with vfir.
k_put8h:
	lea	g_coef,r6
	movb	(r6),r16
	movb	1(r6),r17
	movb	2(r6),r18
	movb	3(r6),r19
	movb	4(r6),r20
	movb	5(r6),r21
	movb	6(r6),r22
	movb	7(r6),r23
	movq	r3,r29
	sub	r4,r29			; s stride - w
	movq	r1,r30
	sub	r4,r30			; d stride - w
.row:
	lea	(r2)(r4),r7
	vec	r2,r7
	vld.bu.l	v0,(r2)+
	vfir.l	v1,v0,r16,#8
	vadd.l	v1,v1,#32
	vsar.l	v1,v1,#6
	vsts.l.bu	v1,(r0)+
	vend
	add	r29,r2
	add	r30,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
