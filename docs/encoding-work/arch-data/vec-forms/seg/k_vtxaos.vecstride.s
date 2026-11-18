; k_vtxaos without segment loads and stores: four strided loads and four strided stores.
k_vtxaos:
	lea	(r1)(r3*16),r4
	vec	r1,r4
	vldt.f	v0,0(r1),#16
	vldt.f	v1,4(r1),#16
	vldt.f	v2,8(r1),#16
	vldt.f	v3,12(r1)+,#16
	vmul.f	v4,v0,r10
	vfma.f	v4,v1,r11
	vfma.f	v4,v2,r12
	vadd.f	v4,v4,r13
	vmul.f	v5,v0,r14
	vfma.f	v5,v1,r15
	vfma.f	v5,v2,r16
	vadd.f	v5,v5,r17
	vmul.f	v6,v0,r18
	vfma.f	v6,v1,r19
	vfma.f	v6,v2,r20
	vadd.f	v6,v6,r21
	vstt.f	v4,0(r0),#16
	vstt.f	v5,4(r0),#16
	vstt.f	v6,8(r0),#16
	vstt.f	v3,12(r0)+,#16
	vend
	ret
