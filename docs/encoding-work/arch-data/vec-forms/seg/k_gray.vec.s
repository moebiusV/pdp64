; k_gray: RGBA bytes to a gray byte, 3 of the 4 fields.  r0 = g, r1 = rgba, r2 = n pixels.  Form with a segment load: one load de-interleaves four fields into v0..v3
; (16-bit lanes); a strip is VL pixels, 4*VL bytes of the first stream.
k_gray:
	lea	(r1)(r2*4),r3
	vec	r1,r3
	vlseg4.bu.h v0,(r1)+		; r, g, b, a into v0, v1, v2, v3
	vmul.h	v0,v0,#77
	vmul.h	v1,v1,#150
	vmul.h	v2,v2,#29
	vadd.h	v0,v0,v1
	vadd.h	v0,v0,v2
	vshr.h	v0,v0,#8
	vst.h.b	v0,(r0)+
	vend
	ret
