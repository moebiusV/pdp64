	.text
	vec r1, r2
	vld.b v0, (r1)+
	vdacc.w r4, v0, v0
	vend
