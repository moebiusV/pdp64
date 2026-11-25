	.text
	.even
	.globl dense
dense:
.L251:
.L255:
	movq r0,r1
	cmp r0,#10
	bhi .L283
	; jtab
	lea .L285,r12
	jmpi (r12)(r0*8)
.L283:
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
	movq #14,r0
	ret
.L271:
	movq #15,r0
	ret
.L273:
	movq #16,r0
	ret
.L275:
	movq #17,r0
	ret
.L277:
	movq #18,r0
	ret
.L279:
	movq #19,r0
	ret
.L281:
	movq #20,r0
.L253:
	; ret:one,out=0
	ret
	.align 8
.L285:
	.quad .L261
	.quad .L263
	.quad .L265
	.quad .L267
	.quad .L269
	.quad .L271
	.quad .L273
	.quad .L275
	.quad .L277
	.quad .L279
	.quad .L281
	.even
	.globl sparse
sparse:
.L289:
.L293:
	cbgt r0,#9,.L317
	cmp r0,#-100000
	beq .L299
	cbeq r0,#-7,.L301
	cbeq r0,#0,.L303
	cbeq r0,#9,.L305
	br .L295
.L299:
	movq #1,r0
	ret
.L301:
	movq #2,r0
	ret
.L303:
	movq #3,r0
	ret
.L305:
	movq #4,r0
	ret
.L307:
	movq #5,r0
	ret
.L309:
	movq #6,r0
	ret
.L311:
	movq #7,r0
	ret
.L313:
	movq #8,r0
	ret
.L317:
	cbeq r0,#50,.L307
	cbeq r0,#1000,.L309
	cmp r0,#70000
	beq .L311
	cmp r0,#2000000000
	beq .L313
.L295:
	clr r0
.L291:
	; ret:one,out=0
	ret
	.even
	.globl fall
fall:
.L321:
	movq r0,r1
.L325:
	clr r0
	movq r1,r2
	dec r2
	cbhi r2,#8,.L323
	dec r1
	; jtab
	lea .L351,r12
	jmpi (r12)(r1*8)
.L349:
	ret
.L331:
	inc r0
.L333:
	add #2,r0
.L335:
	add #4,r0
	ret
.L337:
	lea 8(r0),r0
.L339:
	lea 16(r0),r0
	ret
.L341:
.L343:
.L345:
	lea 32(r0),r0
	ret
.L347:
	movq #99,r0
.L323:
	; ret:one,out=0
	ret
	.align 8
.L351:
	.quad .L331
	.quad .L333
	.quad .L335
	.quad .L337
	.quad .L339
	.quad .L341
	.quad .L343
	.quad .L345
	.quad .L347
	.even
	.globl u32
u32:
.L355:
.L359:
	cbhi r0,#3,.L383
	cbeq r0,#0,.L365
	cbeq r0,#1,.L367
	cbeq r0,#2,.L369
	cbeq r0,#3,.L371
	br .L361
.L365:
	movq #1,r0
	ret
.L367:
	movq #2,r0
	ret
.L369:
	movq #3,r0
	ret
.L371:
	movq #4,r0
	ret
.L373:
	movq #5,r0
	ret
.L375:
	movq #6,r0
	ret
.L377:
	movq #7,r0
	ret
.L379:
	movq #8,r0
	ret
.L383:
	cbeq r0,#7,.L377
	cbeq r0,#8,.L379
	cmp r0,#-294967296
	beq .L373
	cmp r0,#-294967295
	beq .L375
.L361:
	clr r0
.L357:
	; ret:one,out=0
	ret
	.even
	.globl l64
l64:
.L387:
.L391:
	cbgt r0,#6,.L417
	cmp r0,=-9000000000000
	beq .L397
	cbeq r0,#-1,.L399
	cbeq r0,#0,.L401
	cbeq r0,#5,.L403
	cbeq r0,#6,.L405
	br .L393
.L397:
	movq #1,r0
	ret
.L399:
	movq #2,r0
	ret
.L401:
	movq #3,r0
	ret
.L403:
	movq #4,r0
	ret
.L405:
	movq #5,r0
	ret
.L407:
	movq #6,r0
	ret
.L409:
	movq #7,r0
	ret
.L411:
	movq #8,r0
	ret
.L413:
	movq #9,r0
	ret
.L417:
	cbeq r0,#7,.L407
	cbeq r0,#8,.L409
	cmp r0,=9000000000000
	beq .L411
	cmp r0,=9000000000001
	beq .L413
.L393:
	clr r0
.L389:
	; ret:one,out=0
	ret
	.even
	.globl "ch"
"ch":
.L421:
.L425:
	movl r0,r0
	cbgt r0,#105,.L447
	cbeq r0,#32,.L443
	cbeq r0,#97,.L431
	cbeq r0,#101,.L433
	cbeq r0,#105,.L435
	br .L427
.L431:
	movq #1,r0
	ret
.L433:
	movq #2,r0
	ret
.L435:
	movq #3,r0
	ret
.L437:
	movq #4,r0
	ret
.L439:
	movq #5,r0
	ret
.L441:
	movq #6,r0
	ret
.L443:
	movq #7,r0
	ret
.L447:
	cbeq r0,#111,.L437
	cbeq r0,#117,.L439
	cbeq r0,#121,.L441
.L427:
	clr r0
.L423:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	pushm #1792
.L451:
.L455:
	clr r9
	movq #-2,r8
	br .L461
.L452:
	cblt r8,#0,.L465
	cbgt r8,#10,.L465
	lea 10(r8),r10
	br .L467
.L465:
	movq #-1,r10
.L467:
	movcall r8,r0,dense
	cbeq r0,r10,.L457
	bis #1,r9
.L457:
	inc r8
.L461:
	cble r8,#12,.L452
	movq #-100000,r0
	call sparse
	cbne r0,#1,.L471
	movq #-7,r0
	call sparse
	cbne r0,#2,.L471
	clr r0
	call sparse
	cbne r0,#3,.L471
	movq #9,r0
	call sparse
	cbne r0,#4,.L471
	movq #50,r0
	call sparse
	cbne r0,#5,.L471
	movq #1000,r0
	call sparse
	cbne r0,#6,.L471
	movq #70000,r0
	call sparse
	cbne r0,#7,.L471
	movq #2000000000,r0
	call sparse
	cbne r0,#8,.L471
	movq #1,r0
	call sparse
	cbne r0,#0,.L471
	movq #-8,r0
	call sparse
	cbne r0,#0,.L471
	movq #2000000001,r0
	call sparse
	cbeq r0,#0,.L469
.L471:
	bis #2,r9
.L469:
	movq #1,r0
	call fall
	cbne r0,#7,.L475
	movq #2,r0
	call fall
	cbne r0,#6,.L475
	movq #3,r0
	call fall
	cbne r0,#4,.L475
	movq #4,r0
	call fall
	cbne r0,#24,.L475
	movq #5,r0
	call fall
	cbne r0,#16,.L475
	movq #6,r0
	call fall
	cbne r0,#32,.L475
	movq #8,r0
	call fall
	cbne r0,#32,.L475
	movq #9,r0
	call fall
	cbne r0,#99,.L475
	clr r0
	call fall
	cbne r0,#0,.L475
	movq #10,r0
	call fall
	cbeq r0,#0,.L473
.L475:
	bis #4,r9
.L473:
	clr r0
	call u32
	cbne r0,#1,.L479
	movq #3,r0
	call u32
	cbne r0,#4,.L479
	movq #-294967296,r0
	call u32
	cbne r0,#5,.L479
	movq #-294967295,r0
	call u32
	cbne r0,#6,.L479
	movq #7,r0
	call u32
	cbne r0,#7,.L479
	movq #8,r0
	call u32
	cbne r0,#8,.L479
	movq #5,r0
	call u32
	cbne r0,#0,.L479
	movq #-1,r0
	call u32
	cbeq r0,#0,.L477
.L479:
	bis #8,r9
.L477:
	movq =-9000000000000,r0
	call l64
	cbne r0,#1,.L483
	movq #-1,r0
	call l64
	cbne r0,#2,.L483
	clr r0
	call l64
	cbne r0,#3,.L483
	movq #7,r0
	call l64
	cbne r0,#6,.L483
	movq =9000000000001,r0
	call l64
	cbne r0,#9,.L483
	movq =9000000000000,r0
	call l64
	cbne r0,#8,.L483
	movq #4,r0
	call l64
	cbne r0,#0,.L483
	movq #-2,r0
	call l64
	cbeq r0,#0,.L481
.L483:
	bis #16,r9
.L481:
	movq #97,r0
	call "ch"
	cbne r0,#1,.L487
	movq #121,r0
	call "ch"
	cbne r0,#6,.L487
	movq #32,r0
	call "ch"
	cbne r0,#7,.L487
	movq #122,r0
	call "ch"
	cbne r0,#0,.L487
	movq #105,r0
	call "ch"
	cbne r0,#3,.L487
	movq #117,r0
	call "ch"
	cbne r0,#5,.L487
	clr r0
	call "ch"
	cbeq r0,#0,.L485
.L487:
	bis #32,r9
.L485:
	movq r9,r0
	popmret #1792
	; ret:one,out=0
