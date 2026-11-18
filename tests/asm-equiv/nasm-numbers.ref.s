; the same: as64's own spellings of the numbers
	.text
1:	nop
	br	1b
	movq	#5, r1
	movq	#0xa5, r2
	movq	#0xff, r3
	movq	#0xff, r4
	movq	#255, r5
	movq	#10, r6
	movq	#0xa6, r7
	movq	#9, r8
10:	br	10b
