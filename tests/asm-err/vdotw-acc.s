	.text
	vec r1, r2
	vld.w v0, (r1)+
	vdot.w v2, v0, v0
	vacc.w.l r4, v2
	vend
