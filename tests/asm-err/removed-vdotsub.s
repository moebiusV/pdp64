	.text
	vec r1, r2
	vld.b v0, (r1)+
	vld.b v1, (r2)+
	vdotsu.b v2, v0, v1
	vend
