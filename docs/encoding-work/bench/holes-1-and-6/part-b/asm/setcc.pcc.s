	.text
	.even
	.globl lt
lt:
.L251:
.L255:
	cmp r0,r1
	set lt,r0
.L259:
	; ret:one,out=0
	ret
	.even
	.globl le
le:
.L263:
.L267:
	cmp r0,r1
	set le,r0
.L271:
	; ret:one,out=0
	ret
	.even
	.globl gt
gt:
.L275:
.L279:
	cmp r0,r1
	set gt,r0
.L283:
	; ret:one,out=0
	ret
	.even
	.globl ge
ge:
.L287:
.L291:
	cmp r0,r1
	set ge,r0
.L295:
	; ret:one,out=0
	ret
	.even
	.globl eq
eq:
.L299:
.L303:
	cmp r0,r1
	set eq,r0
.L307:
	; ret:one,out=0
	ret
	.even
	.globl ne
ne:
.L311:
.L315:
	cmp r0,r1
	set ne,r0
.L319:
	; ret:one,out=0
	ret
	.even
	.globl ult
ult:
.L323:
.L327:
	cmp r0,r1
	set cs,r0
.L331:
	; ret:one,out=0
	ret
	.even
	.globl ule
ule:
.L335:
.L339:
	cmp r0,r1
	set los,r0
.L343:
	; ret:one,out=0
	ret
	.even
	.globl ugt
ugt:
.L347:
.L351:
	cmp r0,r1
	set hi,r0
.L355:
	; ret:one,out=0
	ret
	.even
	.globl uge
uge:
.L359:
.L363:
	cmp r0,r1
	set cc,r0
.L367:
	; ret:one,out=0
	ret
	.even
	.globl lt0
lt0:
.L371:
.L375:
	tst r0
	set lt,r0
.L379:
	; ret:one,out=0
	ret
	.even
	.globl eq0
eq0:
.L383:
.L387:
	tst r0
	set eq,r0
.L391:
	; ret:one,out=0
	ret
	.even
	.globl gt5
gt5:
.L395:
.L399:
	cmp r0,#5
	set gt,r0
.L403:
	; ret:one,out=0
	ret
	.even
	.globl ne7
ne7:
.L407:
.L411:
	cmp r0,#7
	set ne,r0
.L415:
	; ret:one,out=0
	ret
	.even
	.globl ilt
ilt:
.L419:
.L423:
	cmp r0,r1
	set lt,r0
.L427:
	; ret:one,out=0
	ret
	.even
	.globl sgn
sgn:
.L431:
	movq r0,r1
.L435:
	tst r1
	set gt,r0
.L439:
	tst r1
	set lt,r1
.L443:
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl cnt
cnt:
.L447:
	movq r0,r3
.L451:
	clr r0
	clr r4
	br .L457
.L448:
	movq (r3)(r4*8),r5
	cmp r5,r2
	set gt,r5
.L461:
	add r5,r0
	inc r4
.L457:
	cblt r4,r1,.L448
	; ret:one,out=0
	ret
	.even
	.globl both
both:
.L465:
	movq r0,r2
.L469:
	cmp r2,r1
	set lt,r0
.L473:
	cmp r2,r1
	set gt,r1
.L477:
	mul #10,r0
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl nest
nest:
.L481:
	movq r0,r3
.L485:
	cmp r3,r1
	set lt,r0
.L489:
	cmp r1,r2
	set lt,r4
.L493:
	cmp r3,r2
	set eq,r1
.L497:
	asl r4
	movl r4,r4
	add r4,r0
	shl #2,r1
	movl r1,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl st
st:
.L501:
.L505:
	cmp r1,#3
	set lt,r1
.L509:
	movq r1,(r0)
	; ret:one,out=0
	ret
	.text
	.align 8
.L519:
	.quad -5
	.quad -1
	.quad 0
	.quad 1
	.quad 3
	.quad 5
	.quad 6
	.quad 7
	.quad 100
	.text
	.even
	.globl test
test:
	pushm #117477120
	sub #72,sp
.L513:
.L517:
	clr r10
	clr r9
	br .L525
.L516:
	lea .L519,r0
	movq (r0)(r9*8),r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	tst r1
	set lt,r8
.L533:
	call lt0
	cbne r0,r8,.L529
	lea .L519,r0
	movq (r0)(r9*8),r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	tst r1
	set eq,r8
.L537:
	call eq0
	cbne r0,r8,.L529
	lea .L519,r0
	movq (r0)(r9*8),r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	cmp r1,#5
	set gt,r8
.L541:
	call gt5
	cbne r0,r8,.L529
	lea .L519,r0
	movq (r0)(r9*8),r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	cmp r1,#7
	set ne,r8
.L545:
	call ne7
	cbeq r0,r8,.L527
.L529:
	bis #1,r10
.L527:
	lea .L519,r0
	movq (r0)(r9*8),r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	cble r1,#0,.L549
	movq #1,r8
	br .L551
.L549:
	lea .L519,r1
	movq (r1)(r9*8),r1
	cbge r1,#0,.L553
	movq #-1,r8
	br .L551
.L553:
	clr r8
.L551:
	call sgn
	cbeq r0,r8,.L547
	bis #2,r10
.L547:
	clr r25
	br .L561
.L514:
	lea .L519,r0
	movq (r0)(r9*8),r15
	movq (r0)(r25*8),r8
	movq r15,r24
	movq r8,r11
	cmp r15,r8
	set lt,r26
.L569:
	movq r8,r1
	movcall r15,r0,lt
	cbne r0,r26,.L565
	cmp r15,r8
	set le,r26
.L573:
	movq r8,r1
	movcall r15,r0,le
	cbne r0,r26,.L565
	cmp r15,r8
	set gt,r26
.L577:
	movq r8,r1
	movcall r15,r0,gt
	cbne r0,r26,.L565
	cmp r15,r8
	set ge,r26
.L581:
	movq r8,r1
	movcall r15,r0,ge
	cbne r0,r26,.L565
	cmp r15,r8
	set eq,r26
.L585:
	movq r8,r1
	movcall r15,r0,eq
	cbne r0,r26,.L565
	cmp r15,r8
	set ne,r26
.L589:
	movq r8,r1
	movcall r15,r0,ne
	cbeq r0,r26,.L563
.L565:
	bis #4,r10
.L563:
	cmp r24,r11
	set cs,r26
.L597:
	movq r11,r1
	movcall r24,r0,ult
	cbne r0,r26,.L593
	cmp r24,r11
	set los,r26
.L601:
	movq r11,r1
	movcall r24,r0,ule
	cbne r0,r26,.L593
	cmp r24,r11
	set hi,r26
.L605:
	movq r11,r1
	movcall r24,r0,ugt
	cbne r0,r26,.L593
	cmp r24,r11
	set cc,r26
.L609:
	movq r11,r1
	movcall r24,r0,uge
	cbeq r0,r26,.L591
.L593:
	bis #8,r10
.L591:
	movl r15,r0
	movl r8,r1
	movl r15,r3
	movl r8,r2
	cmp r3,r2
	set lt,r11
.L615:
	call ilt
	cbeq r0,r11,.L611
	bis #16,r10
.L611:
	cmp r15,r8
	set lt,r11
.L621:
	cmp r15,r8
	set gt,r24
.L625:
	movq r8,r1
	movcall r15,r0,both
	mul #10,r11
	add r24,r11
	cbeq r0,r11,.L617
	bis #32,r10
.L617:
	movq r9,r0
	add r25,r0
	movq #9,r1
	mod r0,r1,r2
	lea .L519,r0
	movq (r0)(r2*8),r2
	cmp r15,r8
	set lt,r11
.L631:
	movq r9,r0
	add r25,r0
	movq #9,r1
	mod r0,r1,r3
	lea .L519,r0
	cmp r8,(r0)(r3*8)
	bge .L633
	movq #1,r24
	br .L635
.L633:
	clr r24
.L635:
	movq r9,r0
	add r25,r0
	movq #9,r1
	mod r0,r1,r3
	lea .L519,r0
	cmp r15,(r0)(r3*8)
	bne .L637
	movq #1,r26
	br .L639
.L637:
	clr r26
.L639:
	movq r8,r1
	movcall r15,r0,nest
	asl r24
	movl r24,r24
	add r24,r11
	shl #2,r26
	movl r26,r26
	add r26,r11
	cbeq r0,r11,.L557
	bis #64,r10
.L557:
	inc r25
.L561:
	cblt r25,#9,.L514
	movq #99,r0
	movq r0,(sp)(r9*8)
	mov2 sp,r0,r9,r1
	shl #3,r1
	add r1,r0
	lea .L519,r1
	movq (r1)(r9*8),r1
	call st
	lea .L519,r0
	movq (r0)(r9*8),r0
	cmp r0,#3
	set lt,r0
.L645:
	movq (sp)(r9*8),r1
	cbeq r1,r0,.L521
	bis #128,r10
.L521:
	inc r9
.L525:
	cblt r9,#9,.L516
	clr r2
	movq #9,r1
	movcall sp,r0,cnt
	cbne r0,#4,.L649
	movq #2,r2
	movq #9,r1
	lea .L519,r0
	call cnt
	cbeq r0,#5,.L647
.L649:
	bis #256,r10
.L647:
	movl r10,r0
	add #72,sp
	popm #117477120
	; ret:one,out=0
	ret
