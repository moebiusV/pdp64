; a 5-bit immediate at displacement 32768: only the long form (27-bit displacement) reaches
	.text
	cbeq	r1, #3, 1f
	.space	65530
1:	ret
