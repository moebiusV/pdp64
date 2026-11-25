	.text
	.globl	_start
_start:
	lea	vtab,r1
	mtsr	vbr,r1
	movq	#0x800000,r0
	movq	#0x900000,r1
	movq	#16384,r2
	call	k
	halt
k:	clr	r4
	lea	(r0)(r2*4),r3
	vec	r0,r3
	vld.f	v0,(r0)+
	vld.f	v1,(r1)+
	vmul.f	v0,v0,v1
	vacc.f	r4,v0
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
