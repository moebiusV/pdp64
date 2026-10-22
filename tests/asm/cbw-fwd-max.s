; wide immediate, displacement 32767: the farthest forward the wide form reaches
	.text
	cbeq	r1, #1000, 1f
	.space	65528
1:	ret
