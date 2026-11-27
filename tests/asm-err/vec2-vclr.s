	.text
f:	vec2	r1, r2, r3, r4
	vclr.l	v0, $1
	vld.l	v1, (r1)+
	vend
