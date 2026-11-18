; k_cmul without segment loads and stores: four strided loads, two strided stores.
k_cmul:
	lea	(r1)(r3*8),r4
	vec	r1,r4
	vldt.f	v0,0(r1),#8
	vldt.f	v1,4(r1)+,#8
	vldt.f	v2,0(r2),#8
	vldt.f	v3,4(r2)+,#8
	vmul.f	v4,v0,v2
	vfnma.f	v4,v1,v3
	vmul.f	v5,v0,v3
	vfma.f	v5,v1,v2
	vstt.f	v4,0(r0),#8
	vstt.f	v5,4(r0)+,#8
	vend
	ret
