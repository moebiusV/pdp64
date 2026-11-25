	.text
	movq #5, r3
	movq #100000, r3
	movq #0x123456789abcdef0, r3
	movq #-1, r4
	trap #3
	trap #200
	jmp lab
	br lab
	nop
lab:	ret
	.encode 3
	movq #5, r3
	.encode 5
	movq #-1, r4
	.encode 0
	movq #5, r3
	.encode 2
	movq r1, r2
	.encode
	movq r1, r2
