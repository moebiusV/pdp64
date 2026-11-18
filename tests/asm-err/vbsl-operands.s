	.text
	vec r1, r2
	vld.b v0, (r1)+
	vld.w v1, (r3)
	vld.w v2, (r5)
	vbsl v3, v0, v1, v2
	vend
