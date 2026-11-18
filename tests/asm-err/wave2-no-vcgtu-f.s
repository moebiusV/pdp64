	.text
	vec r1, r2
	vld.f v0, (r1)+
	vcgtu.f v1, v0, v0
	vend
