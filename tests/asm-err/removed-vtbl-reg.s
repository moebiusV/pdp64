	.text
	vec r1, r2
	vld.bu v0, (r1)+
	vld.w v1, (r3)
	vtbl.b v2, v1, v0
	vend
