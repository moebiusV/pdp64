; k_q8dot (llama.cpp q8_0 dot, the inner loop of a quantized layer): the sum of w[i]*x[i], int8 against int8, into an integer.  r0 = w, r1 = x, r2 = n; the result in r0.
k_q8dot:
	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.b.w	v0,(r0)+		; signed bytes widened to 16-bit lanes: an int8 product fits 16 bits
	vld.b.w	v1,(r1)+
	vmul.w	v0,v0,v1
	vacc.w.l r4,v0			; the sum of the 16-bit lanes, in 32 bits, added to r4
	vend
	movq	r4,r0
	ret
