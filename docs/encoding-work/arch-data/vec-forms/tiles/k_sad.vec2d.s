; k_sad, form: one vec2 block for the whole tile (errata 176).  r0 = a, r1 = a stride, r2 = b, r3 = b stride, r4 = w, r5 = h; returns the sum in r0.
; The sum of absolute differences of two w x h tiles of bytes.
k_sad:
	clr	r6
	movq	r1,r29
	sub	r4,r29			; a stride - w
	movq	r3,r30
	sub	r4,r30			; b stride - w
	lea	(r0)(r4),r7
	vec2	r0,r7,r5,r4
	vskip	r0,r29
	vskip	r2,r30
	vld.bu	v0,(r0)+
	vld.bu	v1,(r2)+
	vsad.bu	r6,v0,v1
	vend
	movq	r6,r0
	ret
