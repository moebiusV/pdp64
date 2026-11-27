	.text
	vec r1, r2
	vld.b v0, (r1)+
	vld.b v1, (r2)+
	vdot.w v2, v0, v1
	vend
