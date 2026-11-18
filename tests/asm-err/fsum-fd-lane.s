	.text
	vec r1, r2
	vld.f v0, (r1)+
	vld.d v1, (r3)+
	vacc.f.d r10, v0
	vend
