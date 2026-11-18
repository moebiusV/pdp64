; k_sad_chk, form: a scalar row loop around a 1D vec block (the existing form).  r0 = a, r1 = a stride, r2 = b, r3 = b stride, r4 = w, r5 = h; g_bnd = lo and hi (one past the end) of the plane of a, then of b; returns the sum in r0.
; k_sad with a bounds check: every row of every stream must lie in [lo, hi) of its plane, or the check traps (vector 16).  chk2 r, rlo, rhi traps unless rlo <= r < rhi (signed): the row start against [lo, hi - w + 1).
k_sad_chk:
	clr	r6
	movq	r1,r29
	sub	r4,r29			; a stride - w
	movq	r3,r30
	sub	r4,r30			; b stride - w
	lea	g_bnd,r27
	movq	0(r27),r16
	movq	8(r27),r17
	sub	r4,r17
	inc	r17			; the a plane: lo r16, hi - w + 1 r17
	lea	g_bnd,r28
	movq	16(r28),r27
	movq	24(r28),r28
	sub	r4,r28
	inc	r28			; the b plane: lo r27, hi - w + 1 r28
.row:
	chk2	r0,r16,r17
	chk2	r2,r27,r28
	lea	(r0)(r4),r7
	vec	r0,r7
	vld.bu	v0,(r0)+
	vld.bu	v1,(r2)+
	vsad.bu	r6,v0,v1
	vend
	add	r29,r0
	add	r30,r2
	dec	r5
	cbgt	r5,#0,.row
	movq	r6,r0
	ret
