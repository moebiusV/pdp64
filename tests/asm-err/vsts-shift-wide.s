	.text
	vec r1, r2
	vld.w v0, (r1)+
	vsts.w.b v0, (r3)+, $64
	vend
