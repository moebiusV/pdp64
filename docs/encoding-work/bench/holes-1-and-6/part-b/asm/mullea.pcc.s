	.text
	.even
	.globl m3
m3:
.L251:
.L255:
	mul #3,r0
	; ret:one,out=0
	ret
	.even
	.globl m5
m5:
.L259:
.L263:
	lea (r0)(r0*4),r0
	; ret:one,out=0
	ret
	.even
	.globl m9
m9:
.L267:
.L271:
	lea (r0)(r0*8),r0
	; ret:one,out=0
	ret
	.even
	.globl m3a
m3a:
.L275:
.L279:
	lea 7(r0)(r0*2),r0
	; ret:one,out=0
	ret
	.even
	.globl m5a
m5a:
.L283:
.L287:
	lea (r0)(r0*4),r0
	lea -100(r0),r0
	; ret:one,out=0
	ret
	.even
	.globl m9a
m9a:
.L291:
.L295:
	lea 100000(r0)(r0*8),r0
	; ret:one,out=0
	ret
	.even
	.globl im5
im5:
.L299:
.L303:
	lea (r0)(r0*4),r0
	inc r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl idx
idx:
.L307:
.L311:
	lea (r1)(r1*4),r1
	movq 16(r0)(r1*8),r0
	; ret:one,out=0
	ret
	.text
	.align 8
.L321:
	.quad 0
	.quad 1
	.quad -1
	.quad 2
	.quad -7
	.quad 1000
	.quad -1000
	.quad 3000000000
	.quad -3000000000
	.quad 4611686018427387903
	.text
	.even
	.globl test
test:
	pushm #1792
	sub #160,sp
.L315:
.L319:
	clr r10
	clr r8
	br .L327
.L316:
	lea .L321,r0
	movq (r0)(r8*8),r9
	movcall r9,r0,m3
	movq r9,r1
	add r9,r1
	add r9,r1
	cbne r0,r1,.L331
	movcall r9,r0,m5
	movq r9,r1
	shl #2,r1
	add r9,r1
	cbne r0,r1,.L331
	movcall r9,r0,m9
	movq r9,r1
	shl #3,r1
	add r9,r1
	cbeq r0,r1,.L329
.L331:
	bis #1,r10
.L329:
	movcall r9,r0,m3a
	movq r9,r1
	lea 7(r1)(r1*2),r1
	cbne r0,r1,.L335
	movcall r9,r0,m5a
	movq r9,r1
	lea (r1)(r1*4),r1
	lea -100(r1),r1
	cbne r0,r1,.L335
	movcall r9,r0,m9a
	movq r9,r1
	lea 100000(r1)(r1*8),r1
	cbeq r0,r1,.L333
.L335:
	bis #2,r10
.L333:
	movl r9,r0
	call im5
	movl r9,r1
	lea (r1)(r1*4),r1
	inc r1
	movl r1,r1
	cbeq r0,r1,.L323
	bis #4,r10
.L323:
	inc r8
.L327:
	cblt r8,#10,.L316
	clr r8
	br .L343
.L318:
	movq r8,r0
	mul #100,r0
	movq r0,(sp)(r8*8)
	inc r8
.L343:
	cblt r8,#20,.L318
	movq #3,r1
	movcall sp,r0,idx
	cbne r0,#1700,.L347
	clr r1
	movcall sp,r0,idx
	cbeq r0,#200,.L345
.L347:
	bis #8,r10
.L345:
	movl r10,r0
	add #160,sp
	popmret #1792
	; ret:one,out=0
