	.text
	vec r1, r2
	vld.f v0, (r1)+
	vcvt.f.l v1, v0
	vst.f v1, (r3)+
	vend
