; k_gray without a segment load: three strided loads (stride 4 bytes), each reading the whole structure's cache lines again.
k_gray:
	lea	(r1)(r2*4),r3
	vec	r1,r3
	vldt.bu.w v0,0(r1),#4		; every fourth byte from r1
	vldt.bu.w v1,1(r1),#4
	vldt.bu.w v2,2(r1)+,#4		; and r1 moves past the strip
	vmul.w	v0,v0,#77
	vmul.w	v1,v1,#150
	vmul.w	v2,v2,#29
	vadd.w	v0,v0,v1
	vadd.w	v0,v0,v2
	vshr.w	v0,v0,#8
	vst.w.b	v0,(r0)+
	vend
	ret
