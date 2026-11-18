	.text
	vec r1, r2
	vld.bu v0, (r1)+
	vld.w v1, (r3)
	vceq.w v2, v0, v1
	vend
