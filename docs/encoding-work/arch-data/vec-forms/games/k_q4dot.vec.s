; k_q4dot (llama.cpp q4_0): two 4-bit weights in each byte (the low nibble minus 8 against x[i], the high nibble minus 8 against x[i+n]), int8 activations.
; r0 = w (n bytes), r1 = x, r2 = n; the result in r0.  Unpacking a nibble is a mask or a shift and a subtraction.
k_q4dot:
	clr	r4
	lea	(r0)(r2),r3
	lea	(r1)(r2),r5		; x + n
	vec	r0,r3
	vld.bu.w v0,(r0)+		; the bytes of weights
	vand.w	v1,v0,#15		; low nibbles
	vsub.w	v1,v1,#8
	vshr.w	v2,v0,#4		; high nibbles
	vsub.w	v2,v2,#8
	vld.b.w	v3,(r1)+		; x[i]
	vld.b.w	v4,(r5)+		; x[i+n]
	vmul.w	v1,v1,v3
	vmul.w	v2,v2,v4
	vadd.w	v1,v1,v2
	vacc.w.l r4,v1
	vend
	movq	r4,r0
	ret
