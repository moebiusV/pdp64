; k_maskblend with the words of wave 1 only: the select is b ^ ((a ^ b) & m).  r0 = dst, r1 = a, r2 = b, r3 = m, r4 = n.
k_maskblend:
	lea	(r1)(r4),r5
	vec	r1,r5
	vld.b	v0,(r1)+		; a
	vld.b	v1,(r2)+		; b
	vld.b	v2,(r3)+		; m
	vxor.b	v3,v0,v1
	vand.b	v3,v3,v2
	vxor.b	v3,v3,v1
	vst.b	v3,(r0)+
	vend
	ret
