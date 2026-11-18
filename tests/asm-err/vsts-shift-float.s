	.text
	vec r1, r2
	vld.f v0, (r1)+
	vsts.f.b v0, (r3)+, #2
	vend
