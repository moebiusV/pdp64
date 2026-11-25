	.text
	.globl	_start
_start:
	lea	vtab,r1
	mtsr	vbr,r1
	movq	#0x800000,r0
	movq	#0x900000,r1
	movq	#65536,r2
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
	.align	8
vtab:
	.space	56
	.quad	hf
	.quad	hf
	.space	3900
	.text
hf:	rti
