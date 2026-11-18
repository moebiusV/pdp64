; k_thresh with the words of wave 1 only (before errata 171): the mask is made by arithmetic, (t - x) >> 15, which is right only while t - x does not overflow 16 bits (the
; values of the data must be within 2^14 of t), and the select is b ^ ((a ^ b) & mask).  r0 = dst, r1 = x, r2 = a, r3 = b, r4 = t, r5 = n.
k_thresh:
	lea	(r1)(r5*2),r6
	vec	r1,r6
	vld.w	v0,(r1)+		; x
	vld.w	v1,(r2)+		; a
	vld.w	v2,(r3)+		; b
	vsubr.w	v3,v0,r4		; t - x
	vsar.w	v3,v3,#15		; mask: all ones if x > t
	vxor.w	v4,v1,v2
	vand.w	v4,v4,v3
	vxor.w	v4,v4,v2		; b ^ ((a ^ b) & mask)
	vst.w	v4,(r0)+
	vend
	ret
