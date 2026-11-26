	.text
	movq r5-8, r2
	movq sp-8, r3
	movq r5+8, r4
	mov (r1).s8, r2
	mov (r1).s16, r2
	mov r2, 4(r1).s32
	mov (r1).64, r2
	mov (r1).s64, r2
	mov (r1), r2
	mov r1.s8, r2
	mov (r1)+.64, r2
	fadd r1.64, r2.64
	fcvt r1.64, r2.s64
	fcvt r1.s64, r2.64
	aadd r1, (r2).64, r3
	aadd r1, (r2).s32, r3
	lea "buf.8", r1
	lea buf, r1
