	.text
	.even
	.globl d2
d2:
.L251:
.L255:
	movq r0,r1
	sar #63,r0
	shr #63,r0
	add r0,r1
	asr r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d8
d8:
.L259:
.L263:
	movq r0,r1
	sar #63,r0
	shr #61,r0
	add r0,r1
	sar #3,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl m8
m8:
.L267:
.L271:
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #61,r2
	add r2,r1
	sar #3,r1
	shl #3,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl m2
m2:
.L275:
.L279:
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #63,r2
	add r2,r1
	asr r1
	asl r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl ld4
ld4:
.L283:
	movq r0,r1
.L287:
	sar #63,r1
	shr #62,r1
	add r1,r0
	sar #2,r0
	; ret:one,out=0
	ret
	.even
	.globl lm16
lm16:
.L291:
.L295:
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #60,r2
	add r2,r1
	sar #4,r1
	shl #4,r1
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl ld1k
ld1k:
.L299:
	movq r0,r1
.L303:
	sar #63,r1
	shr #54,r1
	add r1,r0
	sar #10,r0
	; ret:one,out=0
	ret
	.even
	.globl lm1k
lm1k:
.L307:
.L311:
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #54,r2
	add r2,r1
	sar #10,r1
	shl #10,r1
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl ld1g
ld1g:
.L315:
	movq r0,r1
.L319:
	sar #63,r1
	shr #34,r1
	add r1,r0
	sar #30,r0
	; ret:one,out=0
	ret
	.even
	.globl sd8
sd8:
.L323:
.L327:
	movl r0,r1
	movq r1,r0
	sar #63,r1
	shr #61,r1
	add r1,r0
	sar #3,r0
	movw r0,r0
	; ret:one,out=0
	ret
	.even
	.globl cm4
cm4:
.L331:
.L335:
	movl r0,r0
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #62,r2
	add r2,r1
	sar #2,r1
	shl #2,r1
	sub r1,r0
	movb r0,r0
	; ret:one,out=0
	ret
	.even
	.globl lld32
lld32:
.L339:
	movq r0,r1
.L343:
	sar #63,r1
	shr #59,r1
	add r1,r0
	sar #5,r0
	; ret:one,out=0
	ret
	.even
	.globl dnoreg
dnoreg:
.L347:
.L351:
	movl (r0),r0
	movq #4,r1
	div r0,r1,r0
	; ret:one,out=0
	ret
	.even
	.globl fsum
fsum:
.L355:
	movq r0,r1
.L359:
	clr r0
	movq r1,r2
	neg r2
	br .L365
.L356:
	movq r2,r3
	movq r2,r4
	sar #63,r4
	shr #62,r4
	add r4,r3
	sar #2,r3
	movl r3,r3
	movq r2,r5
	movq r2,r4
	sar #63,r4
	shr #62,r4
	add r4,r5
	sar #2,r5
	shl #2,r5
	movq r2,r4
	sub r5,r4
	movl r4,r4
	mul #10,r4
	add r4,r3
	add r0,r3
	movq r3,r0
	inc r2
.L365:
	cble r2,r1,.L356
	; ret:one,out=0
	ret
	.even
	.globl pdi
pdi:
.L369:
.L373:
	sub r1,r0
	sar #2,r0
	; ret:one,out=0
	ret
	.even
	.globl pdl
pdl:
.L377:
.L381:
	sub r1,r0
	sar #3,r0
	; ret:one,out=0
	ret
	.even
	.globl pdc
pdc:
.L385:
.L389:
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl pds
pds:
.L393:
	mov2 r0,r2,r1,r0
.L397:
	sub r2,r0
	asr r0
	; ret:one,out=0
	ret
	.even
	.globl e1
e1:
.L401:
	movq r0,r2
.L405:
	mul r1,r0
	lea 7(r0),r3
	sub r1,r2
	movq r3,r0
	sar #63,r3
	shr #61,r3
	add r3,r0
	sar #3,r0
	movl r0,r0
	mov2 r2,r1,r2,r3
	sar #63,r3
	shr #62,r3
	add r3,r1
	sar #2,r1
	shl #2,r1
	sub r1,r2
	movl r2,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl e2
e2:
.L409:
.L413:
	mul #3,r0
	lea -5(r0),r1
	movq r1,r0
	sar #63,r1
	shr #60,r1
	add r1,r0
	sar #4,r0
	; ret:one,out=0
	ret
	.text
	.align 8
.L423:
	.quad 0
	.quad 1
	.quad -1
	.quad 2
	.quad -2
	.quad 3
	.quad -3
	.quad 7
	.quad -7
	.quad 8
	.quad -8
	.quad 9
	.quad -9
	.quad 15
	.quad -15
	.quad 16
	.quad -16
	.quad 17
	.quad -17
	.quad 1023
	.quad -1023
	.quad 1024
	.quad -1024
	.quad 1025
	.quad -1025
	.quad 2147483647
	.quad -2147483648
	.quad 4611686018427387903
	.quad -4611686018427387904
	.quad 9223372036854775807
	.quad -9223372036854775808
	.text
	.even
	.globl test
test:
	pushm #16813824
	sub #160,sp
.L417:
.L421:
	clr r10
	clr r9
	br .L429
.L418:
	lea .L423,r1
	movq (r1)(r9*8),r11
	movl r11,r8
	movcall r11,r0,ld4
	movq r11,r1
	movq r11,r2
	sar #63,r2
	shr #62,r2
	add r2,r1
	sar #2,r1
	cbne r0,r1,.L433
	movcall r11,r0,lm16
	movq r11,r2
	movq r11,r1
	sar #63,r1
	shr #60,r1
	add r1,r2
	sar #4,r2
	shl #4,r2
	movq r11,r1
	sub r2,r1
	cbne r0,r1,.L433
	movq r11,r15
	movq r11,r0
	sar #63,r0
	shr #54,r0
	add r0,r15
	sar #10,r15
	movcall r11,r0,ld1k
	cbne r0,r15,.L433
	movcall r11,r0,lm1k
	movq r11,r1
	shl #10,r15
	sub r15,r1
	cbne r0,r1,.L433
	movcall r11,r0,ld1g
	movq r11,r1
	movq r11,r2
	sar #63,r2
	shr #34,r2
	add r2,r1
	sar #30,r1
	cbeq r0,r1,.L431
.L433:
	bis #1,r10
.L431:
	movq r8,r15
	movq r8,r0
	sar #63,r0
	shr #63,r0
	add r0,r15
	asr r15
	movcall r8,r0,d2
	movl r15,r1
	cbne r0,r1,.L437
	movq r8,r24
	movq r8,r0
	sar #63,r0
	shr #61,r0
	add r0,r24
	sar #3,r24
	movcall r8,r0,d8
	movl r24,r1
	cbne r0,r1,.L437
	movcall r8,r0,m8
	movq r8,r1
	shl #3,r24
	sub r24,r1
	movl r1,r1
	cbne r0,r1,.L437
	movcall r8,r0,m2
	movq r8,r1
	asl r15
	sub r15,r1
	movl r1,r1
	cbeq r0,r1,.L435
.L437:
	bis #2,r10
.L435:
	movw r11,r0
	call sd8
	movw r11,r1
	movq #8,r2
	div r1,r2,r1
	cbne r0,r1,.L441
	movb r11,r0
	call cm4
	movb r11,r1
	movq #4,r2
	mod r1,r2,r1
	cbeq r0,r1,.L439
.L441:
	bis #4,r10
.L439:
	movcall r11,r0,lld32
	movq r11,r1
	sar #63,r11
	shr #59,r11
	add r11,r1
	sar #5,r1
	cbeq r0,r1,.L443
	bis #8,r10
.L443:
	movl r8,4(sp)
	lea 4(sp),r0
	call dnoreg
	movq r8,r1
	sar #63,r8
	shr #62,r8
	add r8,r1
	sar #2,r1
	movl r1,r1
	cbeq r0,r1,.L425
	bis #16,r10
.L425:
	inc r9
.L429:
	cblt r9,#31,.L418
	movq #10,r0
	call fsum
	movq r0,r8
	movq #10,r0
	call fsum
	cbeq r8,r0,.L447
	bis #32,r10
.L447:
	clr r8
	movq #-10,r0
	br .L453
.L420:
	mov2 r0,r1,r0,r2
	sar #63,r2
	shr #62,r2
	add r2,r1
	sar #2,r1
	movl r1,r1
	mov2 r0,r3,r0,r2
	sar #63,r2
	shr #62,r2
	add r2,r3
	sar #2,r3
	shl #2,r3
	movq r0,r2
	sub r3,r2
	movl r2,r2
	mul #10,r2
	add r2,r1
	add r8,r1
	movq r1,r8
	inc r0
.L453:
	cble r0,#10,.L420
	movq #10,r0
	call fsum
	cbne r0,r8,.L457
	cbeq r8,r8,.L455
.L457:
	bis #64,r10
.L455:
	lea 156(sp),r0
	lea 128(sp),r1
	call pdi
	cbne r0,#7,.L461
	lea 124(sp),r0
	lea 152(sp),r1
	call pdi
	cbeq r0,#-7,.L459
.L461:
	bis #128,r10
.L459:
	lea 112(sp),r0
	lea 56(sp),r1
	call pdl
	cbne r0,#7,.L465
	lea 48(sp),r0
	lea 104(sp),r1
	call pdl
	cbeq r0,#-7,.L463
.L465:
	bis #256,r10
.L463:
	lea 39(sp),r0
	lea 32(sp),r1
	call pdc
	cbne r0,#7,.L469
	lea 31(sp),r0
	lea 38(sp),r1
	call pdc
	cbeq r0,#-7,.L467
.L469:
	bis #512,r10
.L467:
	lea 28(sp),r0
	lea 14(sp),r1
	call pds
	cbne r0,#-7,.L473
	lea 12(sp),r0
	lea 26(sp),r1
	call pds
	cbeq r0,#7,.L471
.L473:
	bis #1024,r10
.L471:
	movq #-50,r8
	br .L479
.L424:
	movq #-30,r9
	br .L485
.L422:
	mov2 r9,r1,r8,r0
	call e1
	movq r8,r1
	mul r9,r1
	add #7,r1
	movq #8,r2
	div r1,r2,r1
	movq r8,r2
	sub r9,r2
	movq #4,r3
	mod r2,r3,r2
	add r2,r1
	cbeq r0,r1,.L481
	bis #2048,r10
.L481:
	add #5,r9
.L485:
	cblt r9,#40,.L422
	add #7,r8
.L479:
	cblt r8,#50,.L424
	movq #-1000,r8
	br .L493
.L426:
	movcall r8,r0,e2
	movq r8,r1
	lea -5(r1)(r1*2),r1
	movq #16,r2
	div r1,r2,r1
	cbeq r0,r1,.L489
	bis #4096,r10
.L489:
	lea 13(r8),r8
.L493:
	cblt r8,#1000,.L426
	movl r10,r0
	add #160,sp
	popm #16813824
	; ret:one,out=0
	ret
