	.text
	insb	r1, $60, $4, r2
	insb	r30, $60, $4, r31
	mov	$0, r12
	insb	r12, $60, $4, r3
	mov	$5, r12
	insb	r12, $60, $4, r3
	mov	$15, r12
	insb	r12, $60, $4, r4
	extb	r1, $0, $60, r2
	extb	r7, $0, $60, r7
	extb	r31, $0, $60, r16
