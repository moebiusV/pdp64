; k_cmul: arrays of (re, im) float pairs multiplied.  r0 = c, r1 = a, r2 = b, r3 = n.
k_cmul:
	lea	(r1)(r3*8),r4
	vec	r1,r4
	vlseg2.f v0,(r1)+		; ar, ai
	vlseg2.f v2,(r2)+		; br, bi
	vmul.f	v4,v0,v2		; ar*br
	vfnma.f	v4,v1,v3		; - ai*bi
	vmul.f	v5,v0,v3		; ar*bi
	vfma.f	v5,v1,v2		; + ai*br
	vsseg2.f v4,(r0)+
	vend
	ret
