; k_avg, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d, r1 = a, r2 = b, r3 = pitch of all three, r4 = w, r5 = h.
; d = (a + b + 1) >> 1 on bytes (the pixel average of two blocks).
k_avg:
	movq	r3,r29
	sub	r4,r29			; pitch - w
.row:
	lea	(r1)(r4),r7
	vec	r1,r7
	vld.bu	v0,(r1)+
	vld.bu	v1,(r2)+
	vavgu.b	v0,v0,v1
	vst.b	v0,(r0)+
	vend
	add	r29,r1
	add	r29,r2
	add	r29,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
