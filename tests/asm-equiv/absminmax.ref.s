	.text
	mov r1, r12
	sar #63, r12
	xor r12, r1
	sub r12, r1
	mov r1, r12
	sar #63, r12
	mov r1, r2
	xor r12, r2
	sub r12, r2
	setlt r1, r2, r12
	neg r12
	bsel r12, r1, r2, r3
	setcs r1, r2, r12
	neg r12
	bsel r12, r1, r2, r1
	setgt r4, r4, r12
	neg r12
	bsel r12, r4, r4, r4
	sethi r16, r17, r12
	neg r12
	bsel r12, r16, r17, r18
