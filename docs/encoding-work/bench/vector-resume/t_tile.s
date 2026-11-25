	.text
	.globl	_start
_start:
	lea	pd,r0
	lea	pa,r1
	lea	pb,r2
	movq	#320,r3
	movq	#256,r4
	movq	#256,r5
	call	k
	halt
; k_avg, form: one vec2 block for the whole tile (errata 176).  r0 = d, r1 = a, r2 = b, r3 = pitch of all three, r4 = w, r5 = h.
; d = (a + b + 1) >> 1 on bytes (the pixel average of two blocks).
k:
	movq	r3,r29
	sub	r4,r29			; pitch - w
	lea	(r1)(r4),r7
	vec2	r1,r7,r5,r4
	vskip	r1,r29
	vskip	r2,r29
	vskip	r0,r29
	vld.bu	v0,(r1)+
	vld.bu	v1,(r2)+
	vavgu.b	v0,v0,v1
	vst.b	v0,(r0)+
	vend
	ret

	.data
	.align	64
pd:	.space 81920
pa:	.space 81920
pb:	.space 81920
