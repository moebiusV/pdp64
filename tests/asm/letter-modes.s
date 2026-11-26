	.text
	movq 8(r1)(r2*8),r3
	movq (r1)(r2),r3
	movq r3,16(r1)(r2*4)
	movq (r4)+,r5
	movq r5,-(r4)
	movb (r6)+1,r2
	add d,r1
	movq r1,d
	jmp (r3)
	jmp r4
	call r5
	calli 8(r2)
	jtag 8(r1)(r2*8)
	jmp lab
lab:	ret
d:	.quad 1
