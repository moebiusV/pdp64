	.text
	call printf
	br printf
	lea buf,r1
	mov buf, r2
	mov r1, buf
	mov @1000, r3
	mov @abs, r3
	call printf
	cbeq r1,#0,printf
	ret
