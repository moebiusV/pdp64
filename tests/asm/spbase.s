; sp and fp as the register of a based or indexed operand with no displacement
	.text
	movq	r0, (sp)
	movq	(fp), r1
	movq	(sp)(r8*8), r9
	movq	4(sp)(r8*2), r1
