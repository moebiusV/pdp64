; k_mblend_chk, form: a scalar row loop around a 1D vec block (the existing form).  r0 = d, r1 = a, r2 = b, r3 = pitch of d, a, b and the mask, r4 = w, r5 = h; g_bnd4 = lo and hi of the planes of d, a, b, the mask (8 quads).
; k_mblend with a bounds check of the four streams (chk2: rlo <= r < rhi).
k_mblend_chk:
	movq	r3,r29
	sub	r4,r29			; pitch - w
	lea	g_mask,r6
	lea	g_bnd4,r27
	movq	0(r27),r16
	movq	8(r27),r17
	sub	r4,r17
	inc	r17			; plane 0: lo, hi - w + 1
	movq	16(r27),r18
	movq	24(r27),r19
	sub	r4,r19
	inc	r19			; plane 1: lo, hi - w + 1
	movq	32(r27),r20
	movq	40(r27),r21
	sub	r4,r21
	inc	r21			; plane 2: lo, hi - w + 1
	movq	48(r27),r22
	movq	56(r27),r23
	sub	r4,r23
	inc	r23			; plane 3: lo, hi - w + 1
.row:
	chk2	r0,r16,r17
	chk2	r1,r18,r19
	chk2	r2,r20,r21
	chk2	r6,r22,r23
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
