	.text
	vec r1, r2
	vld.l v0, (r1)+
	vcvt.f.l v1, v0
	vend
