	.data
	.align 4
	.globl g1
g1:
	.long 5
	.align 8
	.globl g2
g2:
	.quad 7
	.text
	.even
	.globl bump
bump:
.L259:
.L263:
	movl calls,r0
	inc r0
	movl r0,calls
	movl g1,r0
	lea 100(r0),r0
	movl r0,g1
	movl g1,r0
	; ret:one,out=0
	ret
	.even
	.globl twice
twice:
.L267:
	movq r0,r1
.L271:
	movl (r1),r0
	add r0,r0
	; ret:one,out=0
	ret
	.even
	.globl between
between:
.L275:
	movq r0,r2
.L279:
	movl (r2),r0
	movq #9,r3
	movl r3,(r1)
	movl (r2),r1
	mul #1000,r0
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl acall
acall:
	push r8
.L283:
.L287:
	movl g1,r8
	call bump
	movl g1,r0
	sub r8,r0
	popret r8
	; ret:one,out=0
	.even
	.globl vtwice
vtwice:
.L291:
.L295:
	movl vol,r0
	add r0,r0
	; ret:one,out=0
	ret
	.even
	.globl narrow
narrow:
.L299:
.L303:
	movq #-3,r4
	movq #-300,r3
	movq #-70000,r1
	movq =-5000000000,r5
	movq r4,r0
	add r3,r0
	add r1,r0
	add r5,r0
	movzb r4,r1
	add r1,r0
	movzw r3,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl fwd
fwd:
	sub #32,sp
.L307:
.L311:
	movq r0,8(sp)
	inc r0
	movq r0,16(sp)
	movq 8(sp),r0
	add 16(sp),r0
	add #32,sp
	; ret:one,out=0
	ret
	.even
	.globl cloop
cloop:
.L315:
	movq r0,r1
.L319:
	clr r0
	clr r2
	br .L325
.L316:
	movl g1,r3
	add r3,r0
	inc r2
.L325:
	cblt r2,r1,.L316
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
	sub #8,sp
.L329:
.L333:
	movq #4,r0
	movl r0,4(sp)
	movl r0,(sp)
	clr r8
	lea 4(sp),r0
	call twice
	cbeq r0,#8,.L335
	bis #1,r8
.L335:
	lea 4(sp),r0
	lea 4(sp),r1
	call between
	cbeq r0,#4009,.L337
	lea 4(sp),r0
	movcall sp,r1,between
	cbeq r0,#4009,.L337
	bis #2,r8
.L337:
	movq #5,r0
	movl r0,g1
	call acall
	cbeq r0,#100,.L339
	bis #4,r8
.L339:
	movq #6,r0
	movl r0,vol
	call vtwice
	cbeq r0,#12,.L341
	bis #8,r8
.L341:
	call narrow
	cmp r0,=-5000004814
	beq .L343
	bis #16,r8
.L343:
	movq #10,r0
	call fwd
	cbeq r0,#21,.L345
	bis #32,r8
.L345:
	movq #3,r0
	movl r0,g1
	movq #5,r0
	call cloop
	cbeq r0,#15,.L347
	bis #64,r8
.L347:
	movl r8,r0
	add #8,sp
	popret r8
	; ret:one,out=0
	.comm vol,4
	.bss
	.align 4
calls:
	.space 4
	.text
