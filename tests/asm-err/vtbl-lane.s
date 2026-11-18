	.text
	vec r1, r2
	vld.w v0, (r1)+
	vtbl.b v1, (r3), v0
	vend
