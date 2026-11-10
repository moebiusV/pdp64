	.text
a:	cbeq r1,#0,z
	cbne r1,r2,z
	cbeq r1,#100000,z
	cbpl r1,#0,z
	br z
	beq z
	.space 70000
z:	ret
