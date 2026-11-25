	.text
	.even
	.globl f1
f1:
.L251:
.L255:
	movl 4(r0)(r1*4),r0
	; ret:one,out=0
	ret
	.even
	.globl f2
f2:
.L259:
.L263:
	movl -4(r0)(r1*4),r0
	; ret:one,out=0
	ret
	.even
	.globl f3
f3:
.L267:
.L271:
	movq 24(r0)(r1*8),r0
	; ret:one,out=0
	ret
	.even
	.globl f4
f4:
.L275:
.L279:
	movzw 4(r0)(r1*2),r0
	; ret:one,out=0
	ret
	.even
	.globl f5
f5:
.L283:
.L287:
	add #5,r1
	movzb (r0)(r1),r0
	; ret:one,out=0
	ret
	.even
	.globl f6
f6:
.L291:
	movq r0,r2
.L295:
	lea 1(r1),r0
	shl #4,r0
	movq 8(r2)(r0),r0
	shl #4,r1
	movl (r2)(r1),r3
	add r3,r0
	; ret:one,out=0
	ret
	.even
	.globl st
st:
.L299:
.L303:
	movl r2,8(r0)(r1*4)
	inc r2
	movl r2,(r0)(r1*4)
	; ret:one,out=0
	ret
	.even
	.globl f7
f7:
.L307:
.L311:
	inc r1
	shl #4,r1
	add r1,r0
	lea 1(r2),r1
	shl #2,r1
	add r1,r0
	movl (r0),r0
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
	sub #336,sp
.L315:
.L319:
	clr r8
	clr r0
	br .L325
.L316:
	movq r0,r1
	mul #3,r1
	inc r1
	movl r1,272(sp)(r0*4)
	movq r0,r1
	lea 2(r1)(r1*4),r1
	movq r1,144(sp)(r0*8)
	movq r0,r1
	mul #7,r1
	add #3,r1
	movw r1,112(sp)(r0*2)
	movq r0,r1
	mul #11,r1
	add #4,r1
	movb r1,96(sp)(r0)
	inc r0
.L325:
	cbcs r0,#16,.L316
	clr r0
	br .L331
.L318:
	movq r0,r1
	shl #4,r1
	movl r0,(sp)(r1)
	movq r0,r2
	shl #4,r2
	lea 100(r0),r1
	movq r1,8(sp)(r2)
	inc r0
.L331:
	cbcs r0,#6,.L318
	lea 272(sp),r0
	movq #4,r1
	call f1
	movl 292(sp),r1
	cbne r0,r1,.L335
	lea 272(sp),r0
	movq #4,r1
	call f2
	movl 284(sp),r1
	cbeq r0,r1,.L333
.L335:
	movq #1,r8
.L333:
	lea 144(sp),r0
	movq #5,r1
	call f3
	cmp r0,208(sp)
	beq .L337
	bis #2,r8
.L337:
	lea 112(sp),r0
	movq #6,r1
	call f4
	movzw 128(sp),r1
	cbeq r0,r1,.L339
	bis #4,r8
.L339:
	lea 96(sp),r0
	movq #3,r1
	call f5
	movzb 104(sp),r1
	cbeq r0,r1,.L341
	bis #8,r8
.L341:
	movq #2,r1
	movcall sp,r0,f6
	cbeq r0,#105,.L343
	bis #16,r8
.L343:
	lea 272(sp),r0
	movq #40,r2
	movq #7,r1
	call st
	movl 308(sp),r0
	cbne r0,#40,.L347
	movl 300(sp),r0
	cbeq r0,#41,.L345
.L347:
	bis #32,r8
.L345:
	lea 272(sp),r0
	movq #1,r2
	movq #1,r1
	call f7
	movl 312(sp),r1
	cbeq r0,r1,.L349
	bis #64,r8
.L349:
	movl r8,r0
	add #336,sp
	popret r8
	; ret:one,out=0
