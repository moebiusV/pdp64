; k_q4dot (llama.cpp q4_0): two 4-bit weights in each byte (the low nibble minus 8 against x[i], the high nibble minus 8 against x[i+n]), int8 activations.
; r0 = w (n bytes), r1 = x, r2 = n; the result in r0.  Unpacking a nibble is a mask or a shift and a subtraction.
k_q4dot:
	clr	r4
	lea	(r0)(r2),r3
	lea	(r1)(r2),r5		; x + n
	vec	r0,r3
	vld.bu	v0,(r0)+		; the bytes of weights: a strip of 32 (wave 1, errata 170)
	vand.b	v1,v0,#15		; low nibbles
	vsub.b	v1,v1,#8		; -8..7 fits a signed byte
	vshr.b	v2,v0,#4		; high nibbles
	vsub.b	v2,v2,#8
	vld.b	v3,(r1)+		; x[i]
	vld.b	v4,(r5)+		; x[i+n]
	vdacc.b	r4,v1,v3		; r4 += the byte products, exact
	vdacc.b	r4,v2,v4
	vend
	movq	r4,r0
	ret
