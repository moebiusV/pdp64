	.text
	vec r1, r2
	vld.l v0, (r1)+
	vcvt.l.f v1, v0
	vacc.l.l r4, v1
	vend
