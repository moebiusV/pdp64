	.text
	movq r17,r20
	add r31,r30
	movq 8(r24),r25
	movq r26,16(sp)
	movq (r16)(r31*8),r18
	pushm #0xFF000000
	popm #-16740608
	lea 8(r28),r29
	cbeq r19,#0,x
	cbne r30,r31,x
	xor r27,r26
x:	ret
