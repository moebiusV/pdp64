; k_gray without a segment load: three strided loads (stride 4 bytes), each reading the whole structure's cache lines again.
k_gray:
	lea	(r1)(r2*4),r3
	vec	r1,r3
	vlds.bu.h v0,0(r1),#4		; every fourth byte from r1
	vlds.bu.h v1,1(r1),#4
	vlds.bu.h v2,2(r1)+,#4		; and r1 moves past the strip
	vmul.h	v0,v0,#77
	vmul.h	v1,v1,#150
	vmul.h	v2,v2,#29
	vadd.h	v0,v0,v1
	vadd.h	v0,v0,v2
	vshr.h	v0,v0,#8
	vst.h.b	v0,(r0)+
	vend
	ret
