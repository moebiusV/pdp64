	.text
a:	cbeq r1,#0,z
	cbne r1,r2,z
	cbhi r1,r2,z
	cbge r1,#0,z
	br z
	cbeq r1,r2,z
	.space 70000
z:	ret
