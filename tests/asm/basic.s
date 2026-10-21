	.text
	.globl	start
start:	movq	8(r5), r3
	add	r1, r2
	movq	#-5, r3
	movq	#100000, r4
loop:	bne	loop
	sob	r2, start
	movq	r3, -8(fp)
	movq	(sp)+, r0
	call	start
	clr	r7
	ret
	.data
msg:	.byte	"hi", 0
	.even
tab:	.quad	start, 1, 2
	.long	3
