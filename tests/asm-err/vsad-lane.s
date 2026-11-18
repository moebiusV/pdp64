	.text
	vec r1, r2
	vld.w v0, (r1)+
	vsad.bu r4, v0, v0
	vend
