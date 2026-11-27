	.text
	vec r1, r2
	vld.b v0, (r1)+
	vceq.b v1, v0, $0
	vacc.w.l r4, v1
	vend
