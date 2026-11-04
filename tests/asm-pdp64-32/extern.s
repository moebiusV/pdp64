	.text
	call printf
	br printf
	lea buf,r1
	movq buf,r2
	movq r1,buf
	movq @1000,r3
	movq @abs,r3
	call printf
	cbeq r1,#0,printf
	ret
