	.text
	movq -8(r5), r2
	movq -8(sp), r3
	movq 8(r5), r4
	mov (r1).8, r2
	mov (r1).16, r2
	mov r2, 4(r1).32
	movq (r1), r2
	movq (r1), r2
	movq (r1), r2
	mov r1.8, r2
	movq (r1)+, r2
	fadd r1, r2
	fcvt r1.64, r2
	fcvt r1, r2.64
	aadd r1, (r2), r3
	aadd r1, (r2).32, r3
	lea "buf.8", r1
	lea buf, r1
