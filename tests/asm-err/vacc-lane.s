	.text
	vec	r1, r2
	vld.bu.w v0, (r1)+
	vacc.bu.l r3, v0
	vend
