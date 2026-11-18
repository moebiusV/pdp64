; k_mblend_chk, form: one vec2 block for the whole tile (errata 176).  r0 = d, r1 = a, r2 = b, r3 = pitch of d, a, b and the mask, r4 = w, r5 = h; g_bnd4 = lo and hi of the planes of d, a, b, the mask (8 quads).
; k_mblend with a bounds check of the first and the last row of the four streams (chk2: rlo <= r < rhi).
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
	chk2	r0,r16,r17
	chk2	r1,r18,r19
	chk2	r2,r20,r21
	chk2	r6,r22,r23
	movq	r5,r12
	dec	r12
	mul	r3,r12
	add	r0,r12
	chk2	r12,r16,r17
	movq	r5,r12
	dec	r12
	mul	r3,r12
	add	r1,r12
	chk2	r12,r18,r19
	movq	r5,r12
	dec	r12
	mul	r3,r12
	add	r2,r12
	chk2	r12,r20,r21
	movq	r5,r12
	dec	r12
	mul	r3,r12
	add	r6,r12
	chk2	r12,r22,r23
	lea	(r1)(r4),r7
	vec2	r1,r7,r5,r4
	vskip	r1,r29
	vskip	r2,r29
	vskip	r6,r29
	vskip	r0,r29
	vld.b	v0,(r1)+
	vld.b	v1,(r2)+
	vld.b	v2,(r6)+
	vxor.b	v3,v0,v1
	vand.b	v3,v3,v2
	vxor.b	v3,v3,v1
	vst.b	v3,(r0)+
	vend
	ret
