; wide immediate, displacement -32768: the farthest back the wide form reaches
	.text
1:	.space	65536
	cbeq	r1, #-1000, 1b
