	.text
	.even
	.globl d3
d3:
.L251:
.L255:
	movq r0,r1
	mul =2863311531,r1
	sar #33,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d5
d5:
.L259:
.L263:
	movq r0,r1
	mul =3435973837,r1
	sar #34,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d7
d7:
.L267:
.L271:
	movq r0,r1
	mul =2454267027,r1
	sar #34,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d10
d10:
.L275:
.L279:
	movq r0,r1
	mul =3435973837,r1
	sar #35,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d100
d100:
.L283:
.L287:
	movq r0,r1
	mul =2748779070,r1
	sar #38,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d1000
d1000:
.L291:
.L295:
	movq r0,r1
	mul =2199023256,r1
	sar #41,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d12345
d12345:
.L299:
.L303:
	movq r0,r1
	mul =2850090895,r1
	sar #45,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl dbig
dbig:
.L307:
.L311:
	movq r0,r1
	mul =2147483650,r1
	sar #62,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl d641
d641:
.L315:
.L319:
	movq r0,r1
	mul =3430613504,r1
	sar #41,r1
	shr #63,r0
	add r0,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl m3
m3:
.L323:
.L327:
	movq r0,r1
	mul =2863311531,r1
	sar #33,r1
	movq r0,r2
	shr #63,r2
	add r2,r1
	mul #3,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl m10
m10:
.L331:
.L335:
	movq r0,r1
	mul =3435973837,r1
	sar #35,r1
	movq r0,r2
	shr #63,r2
	add r2,r1
	mul #10,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl m60
m60:
.L339:
.L343:
	movq r0,r1
	mul =2290649225,r1
	sar #37,r1
	movq r0,r2
	shr #63,r2
	add r2,r1
	mul #60,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl m65521
m65521:
.L347:
.L351:
	movq r0,r1
	mul =2147975281,r1
	sar #47,r1
	movq r0,r2
	shr #63,r2
	add r2,r1
	mul #65521,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl mbig
mbig:
.L355:
.L359:
	movq r0,r1
	mul =2305842994,r1
	sar #61,r1
	movq r0,r2
	shr #63,r2
	add r2,r1
	mul #1000000007,r1
	sub r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl dm10
dm10:
.L363:
	movq r0,r1
.L367:
	mul =3435973837,r0
	sar #35,r0
	movq r1,r2
	shr #63,r2
	add r2,r0
	movl r0,r0
	movq r1,r2
	mul =3435973837,r2
	sar #35,r2
	movq r1,r3
	shr #63,r3
	add r3,r2
	mul #10,r2
	sub r2,r1
	movl r1,r1
	mul #100,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl e1
e1:
.L371:
	movq r0,r2
.L375:
	mul r1,r0
	lea 7(r0),r3
	sub r1,r2
	movq r3,r0
	mul =3435973837,r0
	sar #35,r0
	shr #63,r3
	add r3,r0
	movl r0,r0
	movq r2,r1
	mul =2863311531,r1
	sar #35,r1
	movq r2,r3
	shr #63,r3
	add r3,r1
	mul #12,r1
	sub r1,r2
	movl r2,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl e2
e2:
.L379:
	movq r0,r1
.L383:
	lea 1(r1),r2
	lea (r1)(r1*4),r1
	movq r2,r0
	mul =2863311531,r0
	sar #33,r0
	shr #63,r2
	add r2,r0
	movl r0,r0
	movq r1,r2
	mul =2454267027,r2
	sar #34,r2
	movq r1,r3
	shr #63,r3
	add r3,r2
	mul #7,r2
	sub r2,r1
	movl r1,r1
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl ref
ref:
.L387:
.L391:
	cbge r0,#0,.L393
	movq r0,r3
	neg r3
	br .L395
.L393:
	movq r0,r3
.L395:
	clr r7
	movq r3,r4
	clr r5
	br .L397
.L388:
	asl r1
	inc r5
.L397:
	movq r1,r6
	asl r6
	cble r6,r3,.L388
	br .L405
.L390:
	cblt r4,r1,.L401
	sub r1,r4
	movq #1,r3
	shl r5,r3
	add r3,r7
.L401:
	dec r5
	movq r1,r3
	sar #63,r1
	shr #63,r1
	add r1,r3
	asr r3
	movq r3,r1
.L405:
	cbge r5,#0,.L390
	cbge r0,#0,.L409
	neg r7
	neg r4
.L409:
	cbeq r2,#0,.L411
	movl r4,r0
	ret
.L411:
	movl r7,r0
.L413:
	; ret:one,out=0
	ret
	.text
	.align 4
.L423:
	.long 0
	.long 1
	.long 4294967295
	.long 2
	.long 3
	.long 4294967293
	.long 5
	.long 9
	.long 10
	.long 11
	.long 99
	.long 100
	.long 101
	.long 4294967197
	.long 4294967196
	.long 4294967195
	.long 999
	.long 1000
	.long 1001
	.long 12344
	.long 12345
	.long 12346
	.long 65520
	.long 65521
	.long 65522
	.long 1000000006
	.long 1000000007
	.long 1000000008
	.long 2147483646
	.long 2147483647
	.long 2147483649
	.long 2147483648
	.long 2147483650
	.long 641
	.long 640
	.long 642
	.long 1234567890
	.long 3060399406
	.text
	.even
	.globl test
test:
	pushm #36608
.L417:
.L421:
	clr r10
	movq #12345,r8
	clr r9
	br .L429
.L418:
	lea .L423,r1
	movl (r1)(r9*4),r11
	movcall r11,r0,d3
	movq r0,r15
	clr r2
	movq #3,r1
	movcall r11,r0,ref
	cbne r15,r0,.L433
	movcall r11,r0,d5
	movq r0,r15
	clr r2
	movq #5,r1
	movcall r11,r0,ref
	cbne r15,r0,.L433
	movcall r11,r0,d7
	movq r0,r15
	clr r2
	movq #7,r1
	movcall r11,r0,ref
	cbne r15,r0,.L433
	movcall r11,r0,d10
	movq r0,r15
	clr r2
	movq #10,r1
	movcall r11,r0,ref
	cbne r15,r0,.L433
	movcall r11,r0,d100
	movq r0,r15
	clr r2
	movq #100,r1
	movcall r11,r0,ref
	cbeq r15,r0,.L431
.L433:
	bis #1,r10
.L431:
	movcall r11,r0,d1000
	movq r0,r15
	clr r2
	movq #1000,r1
	movcall r11,r0,ref
	cbne r15,r0,.L437
	movcall r11,r0,d12345
	movq r0,r15
	clr r2
	movq #12345,r1
	movcall r11,r0,ref
	cbne r15,r0,.L437
	movcall r11,r0,dbig
	movq r0,r15
	clr r2
	movq #2147483647,r1
	movcall r11,r0,ref
	cbne r15,r0,.L437
	movcall r11,r0,d641
	movq r0,r15
	clr r2
	movq #641,r1
	movcall r11,r0,ref
	cbeq r15,r0,.L435
.L437:
	bis #2,r10
.L435:
	movcall r11,r0,m3
	movq r0,r15
	movq #1,r2
	movq #3,r1
	movcall r11,r0,ref
	cbne r15,r0,.L441
	movcall r11,r0,m10
	movq r0,r15
	movq #1,r2
	movq #10,r1
	movcall r11,r0,ref
	cbne r15,r0,.L441
	movcall r11,r0,m60
	movq r0,r15
	movq #1,r2
	movq #60,r1
	movcall r11,r0,ref
	cbne r15,r0,.L441
	movcall r11,r0,m65521
	movq r0,r15
	movq #1,r2
	movq #65521,r1
	movcall r11,r0,ref
	cbne r15,r0,.L441
	movcall r11,r0,mbig
	movq r0,r15
	movq #1,r2
	movq #1000000007,r1
	movcall r11,r0,ref
	cbeq r15,r0,.L439
.L441:
	bis #4,r10
.L439:
	clr r2
	movq #10,r1
	movcall r11,r0,ref
	movq r0,r15
	movq #1,r2
	movq #10,r1
	movcall r11,r0,ref
	mul #100,r0
	add r0,r15
	movcall r11,r0,dm10
	cbeq r0,r15,.L425
	bis #8,r10
.L425:
	inc r9
.L429:
	cblt r9,#38,.L418
	clr r9
.L449:
	cbge r9,#3000,.L447
	mul #1103515245,r8
	add #12345,r8
	movq r8,r0
	and #1073741824,r0
	beq .L451
	clr r0
	br .L453
.L451:
	movq #1073741824,r0
.L453:
	movzl r8,r11
	shr #1,r11
	sub r0,r11
	movq r9,r0
	and #1,r0
	beq .L455
	neg r11
.L455:
	movcall r11,r0,d10
	movq r0,r15
	clr r2
	movq #10,r1
	movcall r11,r0,ref
	cbne r15,r0,.L459
	movcall r11,r0,m10
	movq r0,r15
	movq #1,r2
	movq #10,r1
	movcall r11,r0,ref
	cbne r15,r0,.L459
	movcall r11,r0,d7
	movq r0,r15
	clr r2
	movq #7,r1
	movcall r11,r0,ref
	cbne r15,r0,.L459
	movcall r11,r0,m60
	movq r0,r15
	movq #1,r2
	movq #60,r1
	movcall r11,r0,ref
	cbne r15,r0,.L459
	movcall r11,r0,d12345
	movq r0,r15
	clr r2
	movq #12345,r1
	movcall r11,r0,ref
	cbeq r15,r0,.L445
.L459:
	bis #16,r10
.L447:
	movq #-50,r8
	br .L465
.L420:
	movq #-30,r9
.L471:
	cbge r9,#40,.L461
	movq r8,r0
	mul r9,r0
	add #7,r0
	movq r8,r15
	sub r9,r15
	clr r2
	movq #10,r1
	call ref
	movq r0,r11
	movq #1,r2
	movq #12,r1
	movcall r15,r0,ref
	add r0,r11
	mov2 r9,r1,r8,r0
	call e1
	cbeq r0,r11,.L467
	bis #32,r10
.L467:
	add #5,r9
	br .L471
.L445:
	inc r9
	br .L449
.L461:
	add #7,r8
.L465:
	cblt r8,#50,.L420
	movq #-1000,r8
	br .L479
.L422:
	lea 1(r8),r0
	movq r8,r11
	lea (r11)(r11*4),r11
	clr r2
	movq #3,r1
	call ref
	movq r0,r9
	movq #1,r2
	movq #7,r1
	movcall r11,r0,ref
	sub r0,r9
	movcall r8,r0,e2
	cbeq r0,r9,.L475
	bis #64,r10
.L475:
	lea 13(r8),r8
.L479:
	cblt r8,#1000,.L422
	movl r10,r0
	popmret #36608
	; ret:one,out=0
