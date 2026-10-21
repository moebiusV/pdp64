	.text
3dfx:	ret
	bne	3dfx
1:	sob	r2, 1b
	br	2f
	ret
2:	movq	#0x3d, r1
	movq	#0b101, r2
	movq	#10, r3
	movq	#0o17, r4
	br	1f
	.globl	0x
0x:	ret
1:
