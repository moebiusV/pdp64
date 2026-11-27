	.text
	mov 8(r1)(r2*8), r3
	mov (r1)(r2), r3
	mov r3, 16(r1)(r2*4)
	mov (r4)+, r5
	mov r5, -(r4)
	mov.s8 (r6)+1, r2
	add d,r1
	mov r1, d
	jmp (r3)
	jmp r4
	call r5
	calli 8(r2)
	jtag 8(r1)(r2*8)
	jmp lab
lab:	ret
d:	.quad 1
