; a 5-bit immediate at displacement -32769: only the long form reaches
	.text
1:	.space	65538
	cbeq	r1, #3, 1b
