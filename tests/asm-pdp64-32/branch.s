	.text
a:	cbeq r1,#0,z
	cbne r1,r2,a
	cblt r3,#100,z
	cbge r1,#-3,a
	cbhi r2,#5000,z
	cbeq r1,#40000,z
	cbcc r1,#7,a
	beq a
	bne z
	br z
	bcs a
	bge z
	.space 300
	bcs a
	br a
z:	ret
