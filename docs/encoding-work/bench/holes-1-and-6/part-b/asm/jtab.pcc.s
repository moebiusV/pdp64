	.text
	.even
	.globl dense
dense:
.L251:
.L255:
	movq r0,r1
	cmp r0,#9
	bhi .L279
	; jtab
	lea .L281,r12
	jmpi (r12)(r0*8)
.L279:
	movq #-1,r0
	ret
.L261:
	movq #10,r0
	ret
.L263:
	movq #11,r0
	ret
.L265:
	movq #12,r0
	ret
.L267:
	movq #13,r0
	ret
.L269:
	movq #15,r0
	ret
.L271:
	movq #16,r0
	ret
.L273:
	movq #17,r0
	ret
.L275:
	movq #18,r0
	ret
.L277:
	movq #19,r0
.L253:
	; ret:one,out=0
	ret
	.align 8
.L281:
	.quad .L261
	.quad .L263
	.quad .L265
	.quad .L267
	.quad .L279
	.quad .L269
	.quad .L271
	.quad .L273
	.quad .L275
	.quad .L277
	.even
	.globl nodefault
nodefault:
.L285:
	movq r0,r1
.L289:
	movq #100,r0
	lea 3(r1),r2
	cmp r2,#9
	bhi .L287
	lea 3(r1),r1
	; jtab
	lea .L315,r12
	jmpi (r12)(r1*8)
.L313:
	ret
.L295:
	movq #1,r0
	ret
.L297:
	movq #2,r0
	ret
.L299:
	movq #3,r0
	ret
.L301:
	movq #4,r0
	ret
.L303:
	movq #5,r0
	ret
.L305:
	movq #6,r0
	ret
.L307:
	movq #8,r0
	ret
.L309:
	movq #9,r0
	ret
.L311:
	movq #10,r0
.L287:
	; ret:one,out=0
	ret
	.align 8
.L315:
	.quad .L295
	.quad .L297
	.quad .L299
	.quad .L301
	.quad .L303
	.quad .L305
	.quad .L313
	.quad .L307
	.quad .L309
	.quad .L311
	.even
	.globl lsw
lsw:
.L319:
.L323:
	lea -100(r0),r1
	cmp r1,#8
	bhi .L325
	lea -100(r0),r0
	; jtab
	lea .L347,r12
	jmpi (r12)(r0*8)
.L345:
.L325:
	clr r0
	ret
.L329:
	movq #1,r0
	ret
.L331:
	movq #2,r0
	ret
.L333:
	movq #3,r0
	ret
.L335:
	movq #4,r0
	ret
.L337:
	movq #6,r0
	ret
.L339:
	movq #7,r0
	ret
.L341:
	movq #8,r0
	ret
.L343:
	movq #9,r0
.L321:
	; ret:one,out=0
	ret
	.align 8
.L347:
	.quad .L329
	.quad .L331
	.quad .L333
	.quad .L335
	.quad .L345
	.quad .L337
	.quad .L339
	.quad .L341
	.quad .L343
	.even
	.globl csw
csw:
.L351:
.L355:
	movl r0,r1
	lea -97(r1),r0
	cmp r0,#8
	bhi .L357
	lea -97(r1),r0
	; jtab
	lea .L381,r12
	jmpi (r12)(r0*8)
.L379:
.L357:
	clr r0
	ret
.L361:
	movq #1,r0
	ret
.L363:
	movq #2,r0
	ret
.L365:
	movq #3,r0
	ret
.L367:
	movq #4,r0
	ret
.L369:
	movq #5,r0
	ret
.L371:
	movq #6,r0
	ret
.L373:
	movq #7,r0
	ret
.L375:
	movq #8,r0
	ret
.L377:
	movq #9,r0
.L353:
	; ret:one,out=0
	ret
	.align 8
.L381:
	.quad .L361
	.quad .L363
	.quad .L365
	.quad .L367
	.quad .L369
	.quad .L371
	.quad .L373
	.quad .L375
	.quad .L377
	.even
	.globl usw
usw:
.L385:
.L389:
	movzl r0,r1
	sub =4000000000,r1
	cbhi r1,#7,.L391
	movzl r0,r0
	sub =4000000000,r0
	; jtab
	lea .L413,r12
	jmpi (r12)(r0*8)
.L411:
.L391:
	movq #99,r0
	ret
.L395:
	movq #1,r0
	ret
.L397:
	movq #2,r0
	ret
.L399:
	movq #3,r0
	ret
.L401:
	movq #4,r0
	ret
.L403:
	movq #5,r0
	ret
.L405:
	movq #6,r0
	ret
.L407:
	movq #7,r0
	ret
.L409:
	movq #8,r0
.L387:
	; ret:one,out=0
	ret
	.align 8
.L413:
	.quad .L395
	.quad .L397
	.quad .L399
	.quad .L401
	.quad .L403
	.quad .L405
	.quad .L407
	.quad .L409
	.even
	.globl fall
fall:
.L417:
	movq r0,r1
.L421:
	clr r0
	movq r1,r2
	cmp r1,#7
	bhi .L443
	; jtab
	lea .L445,r12
	jmpi (r12)(r1*8)
.L443:
	movq #-5,r0
	ret
.L427:
	inc r0
.L429:
	add #2,r0
.L431:
	add #4,r0
.L433:
	lea 8(r0),r0
	ret
.L435:
	lea 16(r0),r0
.L437:
	lea 32(r0),r0
.L439:
	lea 64(r0),r0
.L441:
	lea 128(r0),r0
.L419:
	; ret:one,out=0
	ret
	.align 8
.L445:
	.quad .L427
	.quad .L429
	.quad .L431
	.quad .L433
	.quad .L435
	.quad .L437
	.quad .L439
	.quad .L441
	.even
	.globl vm
vm:
.L449:
	movq r0,r2
.L453:
	clr r0
	clr r5
.L459:
	cbge r5,r1,.L457
	movl (r2)(r5*4),r4
	movq r4,r3
	cmp r4,#8
	bhi .L483
	; jtab
	lea .L485,r12
	jmpi (r12)(r4*8)
.L483:
	lea 1000(r0),r0
.L455:
	inc r5
	br .L459
.L465:
	inc r0
	br .L455
.L467:
	add #2,r0
	br .L455
.L469:
	mul #3,r0
	br .L455
.L471:
	add #-4,r0
	br .L455
.L473:
	xor #5,r0
	br .L455
.L475:
	bis #8,r0
	br .L455
.L477:
	movzb r0,r0
	br .L455
.L479:
	asl r0
	movl r0,r0
	br .L455
.L481:
	asr r0
	br .L455
.L457:
	; ret:one,out=0
	ret
	.align 8
.L485:
	.quad .L465
	.quad .L467
	.quad .L469
	.quad .L471
	.quad .L473
	.quad .L475
	.quad .L477
	.quad .L479
	.quad .L481
	.text
	.align 4
.L495:
	.long 0
	.long 1
	.long 2
	.long 3
	.long 4
	.long 5
	.long 6
	.long 7
	.long 8
	.long 9
	.long 10
	.long 2
	.long 7
	.long 3
	.long 8
	.align 4
.L497:
	.long 10
	.long 11
	.long 12
	.long 13
	.long 4294967295
	.long 15
	.long 16
	.long 17
	.long 18
	.long 19
	.long 4294967295
	.long 4294967295
	.align 4
.L499:
	.long 1
	.long 2
	.long 3
	.long 4
	.long 5
	.long 6
	.long 100
	.long 8
	.long 9
	.long 10
	.long 100
	.text
	.even
	.globl test
test:
	pushm #1792
.L489:
.L493:
	clr r9
	clr r8
	br .L505
.L490:
	movcall r8,r0,dense
	lea .L497,r2
	movl (r2)(r8*4),r1
	cbeq r0,r1,.L501
	bis #1,r9
.L501:
	inc r8
.L505:
	cblt r8,#12,.L490
	movq #-1,r0
	call dense
	cbne r0,#-1,.L511
	movq #-2147483648,r0
	call dense
	cbne r0,#-1,.L511
	movq #2147483647,r0
	call dense
	cbeq r0,#-1,.L509
.L511:
	bis #2,r9
.L509:
	movq #-3,r8
	br .L517
.L492:
	movcall r8,r0,nodefault
	lea .L499,r2
	lea 3(r8),r1
	movl (r2)(r1*4),r1
	cbeq r0,r1,.L513
	bis #4,r9
.L513:
	inc r8
.L517:
	cble r8,#7,.L492
	movq #-4,r0
	call nodefault
	cbne r0,#100,.L523
	movq #1000000,r0
	call nodefault
	cbeq r0,#100,.L521
.L523:
	bis #8,r9
.L521:
	movq #99,r8
	br .L529
.L494:
	movq r8,r0
	cblt r8,#100,.L535
	cbeq r8,#104,.L535
	cble r8,#108,.L533
.L535:
	clr r10
	br .L537
.L533:
	lea -99(r8),r10
.L537:
	call lsw
	cbeq r0,r10,.L525
	bis #16,r9
.L525:
	inc r8
.L529:
	cblt r8,#111,.L494
	movq #-100,r0
	call lsw
	cbne r0,#0,.L541
	movq =9223372036854775807,r0
	call lsw
	cbeq r0,#0,.L539
.L541:
	bis #32,r9
.L539:
	movq #96,r8
	br .L547
.L496:
	movzb r8,r0
	cblt r8,#97,.L551
	cbgt r8,#105,.L551
	lea -96(r8),r10
	br .L553
.L551:
	clr r10
.L553:
	call csw
	cbeq r0,r10,.L543
	bis #64,r9
.L543:
	inc r8
.L547:
	cblt r8,#106,.L496
	clr r0
	call csw
	cbne r0,#0,.L557
	movq #255,r0
	call csw
	cbne r0,#0,.L557
	movq #97,r0
	call csw
	cbeq r0,#1,.L555
.L557:
	bis #128,r9
.L555:
	clr r8
	br .L563
.L498:
	movq r8,r0
	add #-294967297,r0
	movl r0,r0
	cblt r8,#1,.L567
	cbgt r8,#8,.L567
	movq r8,r10
	br .L569
.L567:
	movq #99,r10
.L569:
	call usw
	cbeq r0,r10,.L559
	bis #256,r9
.L559:
	inc r8
.L563:
	cblt r8,#10,.L498
	clr r0
	call usw
	cbne r0,#99,.L573
	movq #-294967297,r0
	call usw
	cbne r0,#99,.L573
	movq #-294967288,r0
	call usw
	cbeq r0,#99,.L571
.L573:
	bis #512,r9
.L571:
	clr r0
	call fall
	cbne r0,#15,.L577
	movq #1,r0
	call fall
	cbne r0,#14,.L577
	movq #3,r0
	call fall
	cbne r0,#8,.L577
	movq #4,r0
	call fall
	cbne r0,#240,.L577
	movq #7,r0
	call fall
	cbne r0,#128,.L577
	movq #8,r0
	call fall
	cbne r0,#-5,.L577
	movq #-1,r0
	call fall
	cbeq r0,#-5,.L575
.L577:
	bis #1024,r9
.L575:
	clr r8
	clr r2
.L583:
	cbge r2,#15,.L581
	lea .L495,r1
	movl (r1)(r2*4),r1
	movq r1,r0
	cmp r1,#8
	bhi .L607
	; jtab
	lea .L609,r12
	jmpi (r12)(r1*8)
.L607:
	lea 1000(r8),r8
.L579:
	inc r2
	br .L583
.L589:
	inc r8
	br .L579
.L591:
	add #2,r8
	br .L579
.L593:
	mul #3,r8
	br .L579
.L595:
	add #-4,r8
	br .L579
.L597:
	xor #5,r8
	br .L579
.L599:
	bis #8,r8
	br .L579
.L601:
	movzb r8,r8
	br .L579
.L603:
	asl r8
	movl r8,r8
	br .L579
.L605:
	asr r8
	br .L579
.L581:
	movq #15,r1
	lea .L495,r0
	call vm
	cbeq r0,r8,.L611
	bis #2048,r9
.L611:
	movl r9,r0
	popmret #1792
	; ret:one,out=0
	.align 8
.L609:
	.quad .L589
	.quad .L591
	.quad .L593
	.quad .L595
	.quad .L597
	.quad .L599
	.quad .L601
	.quad .L603
	.quad .L605
