; k_mix16: the saturating sum of two 16-bit streams (audio).  r0 = o, r1 = a, r2 = b, r3 = n.  A saturating add is one lane operation here (padds in x86, sqadd in NEON).
k_mix16:
	lea	(r1)(r3*2),r4
	vec	r1,r4
	vld.h	v0,(r1)+
	vld.h	v1,(r2)+
	vadds.h	v0,v0,v1
	vst.h	v0,(r0)+
	vend
	ret
