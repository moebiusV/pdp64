	.text
	.globl	_start
_start:
	lea	px,r0
	lea	py,r1
	movq	#262144,r2
	call	k
	halt
k:	clr	r4
	lea	(r0)(r2*4),r3
	vec	r0,r3
	vclr.f	v4,#1
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vfma.f	v4,v0,v1
	vfin
	vacc.f	r4,v4
	vend
	ret

	.data
	.align	64
px:	.space 1048576
py:	.space 1048576
