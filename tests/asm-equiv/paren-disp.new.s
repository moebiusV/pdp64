; a displacement that is itself an expression in parentheses (errata 166): the old evaluator took the first ( for the base register and dropped the displacement
	.text
	mov	('a')(r2), r1
	mov	(1+2)*3(r2), r1
	mov	r1, (4+4)(r5)
	mov	-(3)(r2), r1
