; k_q4dot (llama.cpp q4_0): two 4-bit weights in each byte (the low nibble minus 8 against x[i], the high nibble minus 8 against x[i+n]), int8 activations.
; r0 = w (n bytes), r1 = x, r2 = n; the result in r0.  Unpacking a nibble is a mask or a shift and a subtraction.
k_q4dot:
	clr	r4
	lea	(r0)(r2),r3
	lea	(r1)(r2),r5		; x + n
	vec	r0,r3
	vld.bu.h v0,(r0)+		; the bytes of weights
	vand.h	v1,v0,#15		; low nibbles
	vsub.h	v1,v1,#8
	vshr.h	v2,v0,#4		; high nibbles
	vsub.h	v2,v2,#8
	vld.b.h	v3,(r1)+		; x[i]
	vld.b.h	v4,(r5)+		; x[i+n]
	vmul.h	v1,v1,v3
	vmul.h	v2,v2,v4
	vadd.h	v1,v1,v2
	vacc.l	r4,v1
	vend
	movq	r4,r0
	ret
