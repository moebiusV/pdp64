; k_softmax: x[i] = exp(x[i] - max) / sum.  r0 = x, r1 = n.  Three blocks: the maximum (a max reduction), the exponentials and their sum (vexp, not in the decided set), the scale.
k_softmax:
	lea	(r0)(r1*4),r3
	movl	(r0),r4			; the maximum so far
	movq	r0,r2
	vec	r2,r3
	vld.f	v0,(r2)+
	vmaxacc.f r4,v0			; r4 = max(r4, the largest lane): a max reduction into a register
	vend
	clr	r5
	movq	r0,r2
	vec	r2,r3
	vld.f	v0,(r2)
	vsub.f	v0,v0,r4
	vexp.f	v0,v0
	vst.f	v0,(r2)+
	vacc.f	r5,v0
	vend
	movq	r0,r2
	vec	r2,r3
	vld.f	v0,(r2)
	vdiv.f	v0,v0,r5
	vst.f	v0,(r2)+
	vend
	ret
