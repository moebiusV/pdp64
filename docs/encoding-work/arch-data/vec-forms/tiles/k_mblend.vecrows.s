; k_mblend, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d, r1 = a, r2 = b, r3 = pitch of d, a, b and the mask g_mask, r4 = w, r5 = h.
; d = (a & m) | (b & ~m) = b ^ ((a ^ b) & m), the mask blend of two tiles.
k_mblend:
	movq	r3,r29
	sub	r4,r29			; pitch - w
	lea	g_mask,r6
.row:
	lea	(r1)(r4),r7
	vec	r1,r7
	vld.b	v0,(r1)+
	vld.b	v1,(r2)+
	vld.b	v2,(r6)+
	vxor.b	v3,v0,v1
	vand.b	v3,v3,v2
	vxor.b	v3,v3,v1
	vst.b	v3,(r0)+
	vend
	add	r29,r1
	add	r29,r2
	add	r29,r6
	add	r29,r0
	dec	r5
	cbgt	r5,#0,.row
	ret
