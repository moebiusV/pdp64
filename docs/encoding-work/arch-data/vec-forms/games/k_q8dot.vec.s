; k_q8dot (llama.cpp q8_0 dot, the inner loop of a quantized layer): the sum of w[i]*x[i], int8 against int8, into an integer.  r0 = w, r1 = x, r2 = n; the result in r0.
k_q8dot:
	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vld.b	v0,(r0)+		; signed bytes, a strip of 32 (wave 1, errata 170: no widening, the dot reduces into the register)
	vld.b	v1,(r1)+
	vdacc.b	r4,v0,v1		; r4 += the sum of the 32 byte products (exact)
	vend
	movq	r4,r0
	ret
