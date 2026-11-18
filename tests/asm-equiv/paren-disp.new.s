; a displacement that is itself an expression in parentheses (errata 166): the old evaluator took the first ( for the base register and dropped the displacement
	.text
	movq	('a')(r2), r1
	movq	(1+2)*3(r2), r1
	movq	r1, (4+4)(r5)
	movq	-(3)(r2), r1
