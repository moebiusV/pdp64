	.text
	vec r1, r2
	vld.q v0, (r1)+
	vcvt.q.d v1, v0
	vend
