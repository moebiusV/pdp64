; k_rmsnorm: o[i] = wt[i] * (ss * x[i]) with ss = 1 / sqrt(sum(x*x)/n + eps).  r0 = o, r1 = x, r2 = wt, r3 = n (an integer), r6 = eps and r7 = n as floats.
; A reduction block, four scalar operations, a map block.
k_rmsnorm:
	clr	r5
	lea	(r1)(r3*4),r4
	movq	r1,r8
	vec	r8,r4
	vld.f	v0,(r8)+
	vmul.f	v0,v0,v0
	vacc.f	r5,v0			; the sum of squares
	vend
	fdiv32	r7,r5			; / n
	fadd32	r6,r5			; + eps
	fsqrt32	r5,r5
	fdiv32	r5,r9			; ss = 1 / sqrt(...)   (r9 holds 1.0)
	vec	r1,r4
	vld.f	v0,(r1)+
	vld.f	v1,(r2)+
	vmul.f	v0,v0,r9		; ss * x[i]
	vmul.f	v0,v0,v1		; wt[i] * (...)
	vst.f	v0,(r0)+
	vend
	ret
