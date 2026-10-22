; a 5-bit immediate at displacement 32767: both six-byte forms fit, the wide one is chosen
	.text
	cbeq	r1, #3, 1f
	.space	65528
1:	ret
