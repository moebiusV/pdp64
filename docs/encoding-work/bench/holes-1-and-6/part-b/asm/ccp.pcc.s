	.text
	.even
	.globl a1
a1:
.L253:
.L257:
	inc r0
	mul #3,r0
	; ret:one,out=0
	ret
	.even
	.globl a2
a2:
.L265:
	movq r0,r1
.L269:
	clr r0
	movq #4,r4
	clr r2
	br .L275
.L266:
	movq r4,r3
	asl r3
	add r3,r0
	inc r2
.L275:
	cblt r2,r1,.L266
	; ret:one,out=0
	ret
	.even
	.globl a3
a3:
.L279:
.L283:
	cbeq r0,#0,.L285
.L285:
	movq #11,r0
	; ret:one,out=0
	ret
	.even
	.globl a4
a4:
.L291:
	movq r0,r1
.L295:
	clr r0
	movq #10,r2
	br .L297
.L292:
	dec r2
	add #2,r0
.L297:
	cbgt r2,#0,.L292
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl a5
a5:
.L303:
.L307:
	cble r0,#5,.L309
	movq #7,r0
	ret
.L309:
	movq #9,r0
.L311:
	; ret:one,out=0
	ret
	.even
	.globl a6
a6:
.L315:
.L319:
	movq #15,r0
	; ret:one,out=0
	ret
	.even
	.globl a7
a7:
.L323:
.L327:
	movq #-56,r0
	; ret:one,out=0
	ret
	.even
	.globl a8
a8:
.L331:
.L335:
	movq #4,r0
	; ret:one,out=0
	ret
	.even
	.globl a9
a9:
.L339:
.L343:
	movq #5,r0
	; ret:one,out=0
	ret
	.even
	.globl a10
a10:
.L349:
	movq r0,r1
.L353:
.L359:
	clr r0
	add r1,r0
	clr r2
	cbne r2,#0,.L359
	; ret:one,out=0
	ret
	.even
	.globl a11
a11:
.L367:
.L371:
	movq r0,r0
	lea 16(r0),r0
	; ret:one,out=0
	ret
	.even
	.globl a12
a12:
.L375:
.L379:
	movq #1,r1
	br .L381
.L376:
	cble r0,#3,.L385
	clr r1
	br .L381
.L385:
	inc r0
.L381:
	cbne r1,#0,.L376
	; ret:one,out=0
	ret
	.even
	.globl a13
a13:
.L391:
.L395:
	clr r0
	clr r2
	clr r1
	br .L401
.L392:
	mov2 r2,r0,r1,r2
	inc r1
.L401:
	cblt r1,#3,.L392
	mul #10,r0
	add r2,r0
	; ret:one,out=0
	ret
	.even
	.globl a14
a14:
.L405:
.L409:
	movq #-5,r0
	; ret:one,out=0
	ret
	.even
	.globl a15
a15:
.L413:
.L417:
	clr r1
	cbne r1,r0,.L419
	movq #1,r0
	ret
.L419:
	movq #2,r0
.L415:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
.L423:
.L427:
	clr r8
	movq #5,r0
	call a1
	cbeq r0,#18,.L429
	bis #1,r8
.L429:
	movq #3,r0
	call a2
	cbne r0,#24,.L433
	clr r0
	call a2
	cbeq r0,#0,.L431
.L433:
	bis #2,r8
.L431:
	clr r0
	call a3
	cbne r0,#11,.L437
	movq #1,r0
	call a3
	cbeq r0,#11,.L435
.L437:
	bis #4,r8
.L435:
	movq #5,r0
	call a4
	cbeq r0,#25,.L439
	bis #8,r8
.L439:
	movq #9,r0
	call a5
	cbne r0,#7,.L443
	movq #1,r0
	call a5
	cbeq r0,#9,.L441
.L443:
	bis #16,r8
.L441:
	call a6
	cbeq r0,#15,.L445
	bis #32,r8
.L445:
	call a7
	cbeq r0,#-56,.L447
	bis #64,r8
.L447:
	call a8
	cbeq r0,#4,.L449
	bis #128,r8
.L449:
	movq #1,r0
	call a9
	cbeq r0,#5,.L451
	bis #256,r8
.L451:
	movq #6,r0
	call a10
	cbeq r0,#6,.L453
	bis #512,r8
.L453:
	movq #2,r0
	call a11
	cbeq r0,#18,.L455
	bis #1024,r8
.L455:
	clr r0
	call a12
	cbeq r0,#4,.L457
	bis #2048,r8
.L457:
	call a13
	cbeq r0,#12,.L459
	bis #4096,r8
.L459:
	clr r0
	call a14
	cbeq r0,#-5,.L461
	bis #8192,r8
.L461:
	clr r0
	call a15
	cbne r0,#1,.L467
	lea .L463,r0
	call a15
	cbeq r0,#2,.L465
.L467:
	bis #16384,r8
.L465:
	movl r8,r0
	popret r8
	; ret:one,out=0
	.comm zero,8
	.text
	.even
	.even
.L463:
	.byte 120,0
