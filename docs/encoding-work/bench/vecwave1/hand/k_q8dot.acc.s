; q8 dot, accumulator form: vdot.b into a hidden accumulator (a 16-byte strip on every implementation), the lanes summed once after vfin.
; r0 = w, r1 = x, r2 = n; result in r0.
k_q8dot:
	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v2,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v2,v0,v1
	vfin
	vacc.l.l r4,v2
	vend
	mov	r4,r0
	ret
