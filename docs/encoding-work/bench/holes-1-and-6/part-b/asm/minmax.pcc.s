	.text
	.even
	.globl mx
mx:
.L251:
	mov2 r0,r2,r1,r0
.L255:
	max r2,r0,r0
.L259:
	; ret:one,out=0
	ret
	.even
	.globl mn
mn:
.L263:
	mov2 r0,r2,r1,r0
.L267:
	min r2,r0,r0
.L271:
	; ret:one,out=0
	ret
	.even
	.globl umx
umx:
.L275:
	mov2 r0,r2,r1,r0
.L279:
	maxu r2,r0,r0
.L283:
	; ret:one,out=0
	ret
	.even
	.globl umn
umn:
.L287:
	mov2 r0,r2,r1,r0
.L291:
	minu r2,r0,r0
.L295:
	; ret:one,out=0
	ret
	.even
	.globl ab
ab:
.L299:
.L303:
	abs r0,r0
.L307:
	; ret:one,out=0
	ret
	.even
	.globl iab
iab:
.L311:
.L315:
	abs r0,r0
.L319:
	; ret:one,out=0
	ret
	.even
	.globl clamp
clamp:
.L323:
.L327:
	cbge r0,r1,.L329
	movq r1,r0
.L329:
	cble r0,r2,.L331
	movq r2,r0
.L331:
	; ret:one,out=0
	ret
	.even
	.globl maxof
maxof:
.L335:
	movq r0,r2
.L339:
	movq (r2),r0
	movq #1,r3
	br .L345
.L336:
	movq (r2)(r3*8),r4
	max r4,r0,r0
.L341:
	inc r3
.L345:
	cblt r3,r1,.L336
	; ret:one,out=0
	ret
	.even
	.globl umaxof
umaxof:
.L351:
	movq r0,r2
.L355:
	movq (r2),r0
	movq #1,r3
	br .L361
.L352:
	movq (r2)(r3*8),r4
	maxu r4,r0,r0
.L357:
	inc r3
.L361:
	cblt r3,r1,.L352
	; ret:one,out=0
	ret
	.even
	.globl minof
minof:
.L367:
	movq r0,r2
.L371:
	movq (r2),r0
	movq #1,r3
	br .L377
.L368:
	movq (r2)(r3*8),r4
	min r4,r0,r0
.L373:
	inc r3
.L377:
	cblt r3,r1,.L368
	; ret:one,out=0
	ret
	.text
	.align 8
.L389:
	.quad -9223372036854775808
	.quad -100
	.quad -1
	.quad 0
	.quad 1
	.quad 7
	.quad 100
	.quad 9223372036854775807
	.text
	.even
	.globl test
test:
	pushm #117477120
.L383:
.L387:
	clr r9
	clr r10
	br .L395
.L386:
	lea .L389,r0
	movq (r0)(r10*8),r0
	lea .L389,r1
	movq (r1)(r10*8),r1
	cbge r1,#0,.L399
	lea .L389,r1
	movq (r1)(r10*8),r8
	neg r8
	br .L401
.L399:
	lea .L389,r1
	movq (r1)(r10*8),r8
.L401:
	call ab
	cbeq r0,r8,.L397
	bis #1,r9
.L397:
	lea .L389,r1
	movl (r1)(r10*8),r0
	cbge r0,#0,.L405
	movq r0,r8
	neg r8
	br .L407
.L405:
	lea .L389,r1
	movl (r1)(r10*8),r8
.L407:
	call iab
	cbeq r0,r8,.L403
	bis #2,r9
.L403:
	clr r26
	br .L413
.L384:
	lea .L389,r0
	movq (r0)(r10*8),r15
	movq (r0)(r26*8),r8
	movq r15,r24
	movq r8,r11
	cble r15,r8,.L419
	movq r15,r25
	br .L421
.L419:
	movq r8,r25
.L421:
	movq r8,r1
	movcall r15,r0,mx
	cbne r0,r25,.L417
	cbge r15,r8,.L423
	movq r15,r25
	br .L425
.L423:
	movq r8,r25
.L425:
	movq r8,r1
	movcall r15,r0,mn
	cbeq r0,r25,.L415
.L417:
	bis #4,r9
.L415:
	cblos r24,r11,.L431
	movq r24,r25
	br .L433
.L431:
	movq r11,r25
.L433:
	movq r11,r1
	movcall r24,r0,umx
	cbne r0,r25,.L429
	cbcc r24,r11,.L435
	movq r24,r25
	br .L437
.L435:
	movq r11,r25
.L437:
	movq r11,r1
	movcall r24,r0,umn
	cbeq r0,r25,.L427
.L429:
	bis #8,r9
.L427:
	cbge r15,#-50,.L441
	movq #-50,r11
	br .L443
.L441:
	cble r15,r8,.L445
	movq r8,r11
	br .L443
.L445:
	movq r15,r11
.L443:
	movq r8,r2
	movq #-50,r1
	movcall r15,r0,clamp
	cbeq r0,r11,.L409
	cblt r8,#-50,.L409
	bis #16,r9
.L409:
	inc r26
.L413:
	cblt r26,#8,.L384
	inc r10
.L395:
	cblt r10,#8,.L386
	movq #8,r1
	lea .L389,r0
	call maxof
	cmp r0,=9223372036854775807
	bne .L451
	movq #8,r1
	lea .L389,r0
	call minof
	cmp r0,=-9223372036854775808
	beq .L449
.L451:
	bis #32,r9
.L449:
	lea .L389,r0
	movq #8,r1
	call umaxof
	cbeq r0,#-1,.L453
	bis #64,r9
.L453:
	movl r9,r0
	popm #117477120
	; ret:one,out=0
	ret
