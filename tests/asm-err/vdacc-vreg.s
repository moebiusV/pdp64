	.text
	vec r1, r2
	vld.b v0, (r1)+
	vdacc.b v1, v0, v0
	vend
