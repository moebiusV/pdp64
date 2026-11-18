	.text
	vec r1, r2
	vld.w v0, (r1)+
	vcvt.l.f v1, v0
	vend
