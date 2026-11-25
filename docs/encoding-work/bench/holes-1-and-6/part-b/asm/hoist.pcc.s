	.text
	.even
	.globl id
id:
.L251:
.L255:
	; ret:one,out=0
	ret
	.even
	.globl many
many:
	pushm #117477120
.L259:
	movq r1,r24
	movq r2,r15
	movq r3,r11
	movq r4,r9
	movq r5,r8
.L263:
	clr r10
	call id
	movq r0,r25
	movcall r24,r0,id
	movq r0,r24
	movcall r15,r0,id
	movq r0,r15
	movcall r11,r0,id
	movq r0,r11
	movcall r9,r0,id
	mov2 r0,r9,r8,r0
	call id
	movq r0,r8
	movq 72(sp),r0
	call id
	movq r0,r26
	movq 80(sp),r0
	call id
	movq r0,r1
	clr r0
	br .L269
.L260:
	movq r25,r2
	mul r0,r2
	add r24,r2
	sub r15,r2
	movq r11,r3
	movq r0,r4
	and #3,r4
	mul r4,r3
	add r9,r3
	sub r8,r3
	add r3,r2
	movq r26,r3
	add r1,r3
	xor r3,r2
	add r2,r10
	inc r0
.L269:
	cmp r0,88(sp)
	blt .L260
	movq r10,r0
	add r25,r0
	add r24,r0
	add r15,r0
	add r11,r0
	add r9,r0
	add r8,r0
	add r26,r0
	add r1,r0
	popm #117477120
	; ret:one,out=0
	ret
	.even
	.globl stores
stores:
	pushm #16813824
.L273:
	movq r1,r24
	movq r2,r15
	movq r3,r10
	movq r4,r9
	movq r5,r8
.L277:
	call id
	movq r0,r11
	movcall r24,r0,id
	movq r0,r24
	movcall r15,r0,id
	movq r0,r15
	movcall r10,r0,id
	mov2 r0,r10,r9,r0
	call id
	movq r0,r1
	clr r0
	clr r3
	br .L283
.L274:
	movq r11,r2
	add r24,r2
	add r15,r2
	add r10,r2
	add r1,r2
	add r0,r2
	movq r2,r0
	add r3,r11
	movq r3,r2
	and #1,r2
	beq .L279
	dec r10
.L279:
	inc r3
.L283:
	cblt r3,r8,.L274
	add r11,r0
	add r10,r0
	popm #16813824
	; ret:one,out=0
	ret
	.even
	.globl nested
nested:
	pushm #50368256
.L289:
	movq r0,r15
	movq r1,r11
	mov2 r2,r10,r3,r0
	movq r4,r9
	movq r5,r8
.L293:
	clr r25
	call id
	movq r0,r24
	movcall r9,r0,id
	mov2 r0,r9,r8,r0
	call id
	movq r0,r8
	movq 64(sp),r0
	call id
	movq r0,r1
	clr r3
	br .L299
.L292:
	clr r0
	br .L305
.L290:
	movq (r15)(r0*8),r2
	mul r24,r2
	add r9,r2
	sub r8,r2
	add r1,r2
	add r3,r2
	add r25,r2
	movq r2,r25
	inc r0
.L305:
	cblt r0,r10,.L290
	inc r3
.L299:
	cblt r3,r11,.L292
	movq r25,r0
	add r24,r0
	add r9,r0
	add r8,r0
	add r1,r0
	popm #50368256
	; ret:one,out=0
	ret
	.data
	.align 8
.L315:
	.quad 1
	.quad 2
	.quad 3
	.quad 4
	.quad 5
	.quad 6
	.text
	.even
	.globl test
test:
	pushm #3840
	sub #72,sp
.L309:
.L313:
	clr r8
	lea 24(sp),r1
	lea .L315,r2
	lea 48(r1),r0
.L317:
	movl (r2)+,r3
	movl r3,(r1)+
	cbcs r1,r0,.L317
	clr r9
	clr r0
	br .L323
.L310:
	movq r0,r1
	mul #3,r1
	dec r1
	movq r0,r2
	and #3,r2
	mul #7,r2
	dec r2
	add r2,r1
	xor #15,r1
	add r1,r9
	inc r0
.L323:
	cblt r0,#7,.L310
	movq #7,r0
	movq r0,16(sp)
	movq #8,r0
	movq r0,8(sp)
	movq #7,r0
	movq r0,(sp)
	movq #6,r5
	movq #5,r4
	movq #7,r3
	movq #3,r2
	movq #2,r1
	movq #3,r0
	call many
	lea 41(r9),r1
	cbeq r0,r1,.L325
	bis #1,r8
.L325:
	movq #1,r11
	movq #2,r4
	movq #3,r3
	movq #4,r9
	movq #5,r2
	clr r10
	clr r1
	br .L331
.L312:
	movq r11,r0
	add r4,r0
	add r3,r0
	add r9,r0
	add r2,r0
	add r10,r0
	movq r0,r10
	add r1,r11
	movq r1,r0
	and #1,r0
	beq .L327
	dec r9
.L327:
	inc r1
.L331:
	cblt r1,#6,.L312
	movq #6,r5
	movq #5,r4
	movq #4,r3
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call stores
	add r11,r10
	add r9,r10
	cbeq r0,r10,.L335
	bis #2,r8
.L335:
	clr r9
	clr r2
	br .L341
.L316:
	clr r0
	br .L347
.L314:
	movq 24(sp)(r0*8),r1
	asl r1
	add #4,r1
	add r2,r1
	add r9,r1
	movq r1,r9
	inc r0
.L347:
	cblt r0,#4,.L314
	inc r2
.L341:
	cblt r2,#3,.L316
	lea 24(sp),r0
	movq #5,r1
	movq r1,(sp)
	movq #4,r5
	movq #3,r4
	movq #2,r3
	movq #4,r2
	movq #3,r1
	call nested
	lea 14(r9),r1
	cbeq r0,r1,.L349
	bis #4,r8
.L349:
	movl r8,r0
	add #72,sp
	popmret #3840
	; ret:one,out=24
