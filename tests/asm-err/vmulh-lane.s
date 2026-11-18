	.text
	vec r1, r2
	vld.b v0, (r1)+
	vmulh.w v2, v0, #3
	vend
