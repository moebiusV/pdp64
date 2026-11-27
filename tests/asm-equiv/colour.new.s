; the colour insert and strip are the bit-field words with fixed fields, and a constant colour goes through r12
	.text
	colset	r1, r2
	colset	r30, r31
	colset	$0, r3
	colset	$5, r3
	colset	$15, r4
	colstrip r1, r2
	colstrip r7
	colstrip r31, r16
