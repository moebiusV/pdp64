; k_dctop_sum (dav1d dc_gen_top): dc = (width/2 + sum of top[0..width)) >> ctz(width).  r0 = top, r1 = width.
; A reduction into a scalar register: the single-instruction prefix of errata 139 is enough (one memory operand, the other a register), with one new form,
; the add of a zero-extended byte.
k_dctop_sum:
	movq	r1,r2
	shr	#1,r2
	lea	(r0)(r1),r3
	vec	r0,r3
	addbu	(r0)+,r2		; r2 += zero-extended byte, for every element of [r0, r3)
	bsf	r1,r4			; ctz(width)
	shr	r4,r2
	movq	r2,r0
	ret
