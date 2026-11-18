; k_vtxaos: vertices as (x y z w) floats by a 4x4 matrix, rows 0 to 2; w passes through.  r0 = o, r1 = v, r2 = m, r3 = n.  The twelve matrix elements in r10..r21 (loaded once, not shown).
k_vtxaos:
	lea	(r1)(r3*16),r4
	vec	r1,r4
	vlseg4.f v0,(r1)+		; x, y, z, w into v0..v3
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
	vmov	v7,v3
	vsseg4.f v4,(r0)+		; interleave v4..v7 into structures
	vend
	ret
