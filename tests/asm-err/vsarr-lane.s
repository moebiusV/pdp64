	.text
	vec r1, r2
	vld.bu.w v0, (r1)+
	vsarr.l v2, v0, #3
	vend
