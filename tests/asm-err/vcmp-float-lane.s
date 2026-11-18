	.text
	vec r1, r2
	vld.l v0, (r1)+
	vcgt.f v1, v0, v0
	vend
