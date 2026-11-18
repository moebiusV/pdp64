; k_thresh (wave 2, errata 171): dst[i] = x[i] > t ? a[i] : b[i] on signed 16-bit values (a masked loop: the ternary of a vectorized `if`).  r0 = dst, r1 = x, r2 = a, r3 = b, r4 = t, r5 = n.
; A compare makes the lane mask in an ordinary vector register and one bitwise select takes the arms: no mask file, no overflow limit.
k_thresh:
	lea	(r1)(r5*2),r6
	vec	r1,r6
	vld.w	v0,(r1)+		; x
	vld.w	v1,(r2)+		; a
	vld.w	v2,(r3)+		; b
	vcgt.w	v3,v0,r4		; mask = x > t (all ones or zero)
	vbsl	v3,v3,v1,v2		; (mask & a) | (~mask & b)
	vst.w	v3,(r0)+
	vend
	ret
