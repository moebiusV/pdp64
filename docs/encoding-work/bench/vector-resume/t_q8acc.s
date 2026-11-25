	.text
	.globl	_start
_start:
	lea	px,r0
	lea	py,r1
	movq	#1048576,r2
	call	k
	halt
k:	clr	r4
	lea	(r0)(r2),r3
	vec	r0,r3
	vclr.l	v4,#1
	vld.b	v0,(r0)+
	vld.b	v1,(r1)+
	vdot.b	v4,v0,v1
	vfin
	vacc.l.q	r4,v4
	vend
	movq	r4,r0
	ret

	.data
	.align	64
px:	.space 1048576
py:	.space 1048576
