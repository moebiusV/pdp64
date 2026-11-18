; k_split: stereo 16-bit samples to two streams.  r0 = l, r1 = r, r2 = s, r3 = n frames.
k_split:
	lea	(r2)(r3*4),r4
	vec	r2,r4
	vlseg2.h v0,(r2)+		; left into v0, right into v1
	vst.h	v0,(r0)+
	vst.h	v1,(r1)+
	vend
	ret
