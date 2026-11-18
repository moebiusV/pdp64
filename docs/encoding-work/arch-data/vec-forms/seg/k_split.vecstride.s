; k_split without a segment load: two strided loads (stride 4 bytes), two stores.
k_split:
	lea	(r2)(r3*4),r4
	vec	r2,r4
	vldt.w	v0,0(r2),#4
	vldt.w	v1,2(r2)+,#4
	vst.w	v0,(r0)+
	vst.w	v1,(r1)+
	vend
	ret
