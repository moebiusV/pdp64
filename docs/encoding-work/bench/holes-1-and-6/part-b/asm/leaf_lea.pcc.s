	.text
	.even
	.globl off1
off1:
.L251:
	movq r0,r1
.L255:
	movq 40(r1),r0
	add 800(r1),r0
	add -24(r1),r0
	; ret:one,out=0
	ret
	.even
	.globl off2
off2:
.L259:
	movq r0,r1
.L263:
	movq 8(r1),r0
	add 56(r1),r0
	movl 4(r1),r2
	add r2,r0
	movb (r1),r2
	add r2,r0
	; ret:one,out=0
	ret
	.even
	.globl addr
addr:
.L267:
.L271:
	add #4000,r0
	; ret:one,out=0
	ret
	.even
	.globl diff
diff:
.L275:
	mov2 r0,r2,r1,r0
.L279:
	sub r2,r0
	sar #3,r0
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
	sub #1664,sp
.L283:
.L287:
	clr r8
	clr r0
	br .L293
.L284:
	movq r0,r1
	mul #3,r1
	movq r1,64(sp)(r0*8)
	inc r0
.L293:
	cblt r0,#200,.L284
	lea 144(sp),r0
	call off1
	cbeq r0,#396,.L295
	bis #1,r8
.L295:
	movq #-2,r0
	movb r0,(sp)
	movq #40,r0
	movl r0,4(sp)
	movq #500,r0
	movq r0,8(sp)
	movq #6000,r0
	movq r0,56(sp)
	movcall sp,r0,off2
	cbeq r0,#6538,.L297
	bis #2,r8
.L297:
	clr r0
	call addr
	cbeq r0,#4000,.L299
	bis #4,r8
.L299:
	lea 88(sp),r0
	lea 464(sp),r1
	call diff
	cbeq r0,#47,.L301
	bis #8,r8
.L301:
	movl r8,r0
	add #1664,sp
	popret r8
	; ret:one,out=0
