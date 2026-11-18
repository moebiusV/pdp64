	.text
	vec	r1, r2
	vld.b	v0, (r1)+
	vadd.w	v1, v0, v0
	vend
