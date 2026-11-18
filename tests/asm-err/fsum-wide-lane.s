	.text
	vec r1, r2
	vld.f v0, (r1)+
	vld.q v1, (r3)+
	vacc.f r10, v0
	vend
