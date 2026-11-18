	.text
	vec r1, r2
	vld.b v0, (r1)+
	vld.b v1, (r3)
	vld.w v4, (r5)
	vld.w v5, (r6)
	vcgt.b v2, v0, v1
	vbsl v3, v2, v4, v5
	vend
