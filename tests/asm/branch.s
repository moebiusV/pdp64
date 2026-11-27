	.text
a:	cbeq r1,$0,z
	cbne r1,r2,a
	cblt r3,$100,z
	cbge r1,$-3,a
	cbhi r2,$5000,z
	cbeq r1,$30000,z
	cbcc r1,$7,a
	cbeq r1,r2,a
	cbne r1,r2,z
	br z
	cbcs r1,r2,a
	cbge r1,r2,z
	.space 300
	cbcs r1,r2,a
	br a
z:	ret
