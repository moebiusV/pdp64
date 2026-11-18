	.text
	vec r1, r2
	vld.q v0, (r1)+
	vceq.q v1, v0, v0
	vend
