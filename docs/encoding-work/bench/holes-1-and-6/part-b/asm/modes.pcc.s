	.text
	.even
	.globl inc1
inc1:
.L261:
.L265:
	inc (r0)
	; ret:one,out=0
	ret
	.even
	.globl dec1
dec1:
.L269:
.L273:
	dec (r0)
	; ret:one,out=0
	ret
	.even
	.globl neg1
neg1:
.L277:
.L281:
	neg (r0)
	; ret:one,out=0
	ret
	.even
	.globl com1
com1:
.L285:
.L289:
	com (r0)
	; ret:one,out=0
	ret
	.even
	.globl add2
add2:
.L293:
.L297:
	addm r1,(r0)
	; ret:one,out=0
	ret
	.even
	.globl sub2
sub2:
.L301:
.L305:
	subm r1,(r0)
	; ret:one,out=0
	ret
	.even
	.globl or2
or2:
.L309:
.L313:
	bism r1,(r0)
	; ret:one,out=0
	ret
	.even
	.globl clr2
clr2:
.L317:
.L321:
	movq (r0),r2
	bic r1,r2
	movq r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl idx
idx:
.L325:
.L329:
	movq (r0)(r1*8),r3
	add r2,r3
	movq r3,(r0)(r1*8)
	inc 8(r0)(r1*8)
	; ret:one,out=0
	ret
	.even
	.globl incg
incg:
.L333:
.L337:
	inc g
	movl gi,r0
	inc r0
	movl r0,gi
	movw gs,r0
	inc r0
	movw r0,gs
	movb gc,r0
	inc r0
	movb r0,gc
	; ret:one,out=0
	ret
	.even
	.globl flds
flds:
.L341:
.L345:
	addm r1,(r0)
	subm r1,8(r0)
	movl 16(r0),r2
	add #3,r2
	movl r2,16(r0)
	bism r1,40(r0)
	dec 32(r0)
	; ret:one,out=0
	ret
	.even
	.globl andn
andn:
.L349:
.L353:
	bic r1,r0
	; ret:one,out=0
	ret
	.even
	.globl andn2
andn2:
.L357:
	movq r0,r2
.L361:
	movq r1,r3
	bic r3,r0
	bic r2,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl andn3
andn3:
.L365:
.L369:
	bic r1,r0
	; ret:one,out=0
	ret
	.even
	.globl loop1
loop1:
.L373:
	movq r0,r1
.L377:
	clr r0
.L383:
	add r1,r0
	sob r1,.L383
	; ret:one,out=0
	ret
	.even
	.globl loop2
loop2:
.L387:
	movq r0,r2
.L391:
	clr r0
.L397:
	add -8(r1)(r2*8),r0
	sob r2,.L397
	; ret:one,out=0
	ret
	.even
	.globl loop3
loop3:
.L401:
	movq r0,r1
.L405:
	clr r0
	br .L407
.L402:
	inc r0
	dec r1
.L407:
	cbne r1,#0,.L402
	; ret:one,out=0
	ret
	.even
	.globl loop4
loop4:
.L413:
	movq r0,r2
.L417:
	clr r0
.L423:
	add r1,r0
	inc r1
	dec r2
	cble r2,#0,.L425
	br .L423
.L425:
.L427:
	; ret:one,out=0
	ret
	.even
	.globl loop5
loop5:
.L431:
	movq r0,r1
.L435:
	clr r0
.L441:
	add #2,r0
	sob r1,.L441
	; ret:one,out=0
	ret
	.even
	.globl w1
w1:
.L445:
	movq r0,r3
.L449:
	clr r0
	cbeq r2,#0,.Lppw0
.L446:
	movb (r1)+,r4
	movb r4,(r3)+
	inc r0
.L451:
	sob r2,.L446
.Lppw0:
	; ret:one,out=0
	ret
	.even
	.globl w2
w2:
.L457:
	movq r0,r2
.L461:
	clr r0
	cbeq r2,#0,.Lppw1
.L458:
	movq (r1)+,r3
	cbeq r3,#3,.L463
	inc r0
.L463:
	sob r2,.L458
.Lppw1:
	; ret:one,out=0
	ret
	.even
	.globl w3
w3:
.L471:
	movq r0,r1
.L475:
	clr r0
	cbeq r1,#0,.Lppw2
.L472:
	cbeq r0,#4,.L479
	inc r0
.L477:
	sob r1,.L472
.Lppw2:
.L479:
	; ret:one,out=0
	ret
	.even
	.globl w4
w4:
.L485:
	movq r0,r1
.L489:
	clr r0
	br .L491
.L486:
	add r1,r0
.L491:
	movq r1,r2
	dec r1
	cbne r2,#0,.L486
	; ret:one,out=0
	ret
	.even
	.globl w5
w5:
.L497:
	movq r0,r1
.L501:
	clr r0
	br .L503
.L498:
	inc r0
.L503:
	movq r1,r2
	dec r1
	cbne r2,#0,.L498
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl w6
w6:
.L509:
	movq r0,r1
.L513:
	clr r0
.L515:
	movq r1,r2
	dec r1
	cbeq r2,#0,.L517
	add #2,r0
	cble r0,#20,.L515
.L517:
	; ret:one,out=0
	ret
	.data
	.align 8
.L529:
	.quad 1
	.quad 2
	.quad 3
	.quad 4
	.quad 5
	.quad 6
	.align 8
.L533:
	.quad 10
	.quad 20
	.long 30
	.space 4
	.quad 1
	.quad 2
	.quad 3
	.quad 4
	.align 8
.L581:
	.quad 1
	.quad 3
	.quad 3
	.quad 4
	.quad 5
	.text
	.even
	.globl test
test:
	push r8
	sub #168,sp
.L523:
.L527:
	clr r8
	lea 120(sp),r1
	lea .L529,r2
	lea 48(r1),r0
.L531:
	movl (r2)+,r3
	movl r3,(r1)+
	cbcs r1,r0,.L531
	lea 64(sp),r1
	lea .L533,r2
	lea 56(r1),r0
.L535:
	movl (r2)+,r3
	movl r3,(r1)+
	cbcs r1,r0,.L535
	movq #5,r0
	movq r0,(sp)
	movcall sp,r0,inc1
	movq (sp),r0
	cbeq r0,#6,.L537
	bis #1,r8
.L537:
	movcall sp,r0,dec1
	movcall sp,r0,dec1
	movq (sp),r0
	cbeq r0,#4,.L539
	bis #2,r8
.L539:
	movcall sp,r0,neg1
	movq (sp),r0
	cbeq r0,#-4,.L541
	bis #4,r8
.L541:
	movcall sp,r0,com1
	movq (sp),r0
	cbeq r0,#3,.L543
	bis #8,r8
.L543:
	movq #100,r1
	movcall sp,r0,add2
	movq (sp),r0
	cbeq r0,#103,.L545
	bis #16,r8
.L545:
	movq #3,r1
	movcall sp,r0,sub2
	movq (sp),r0
	cbeq r0,#100,.L547
	bis #32,r8
.L547:
	movq #3,r1
	movcall sp,r0,or2
	movq (sp),r0
	cbeq r0,#103,.L549
	bis #64,r8
.L549:
	movq #96,r1
	movcall sp,r0,clr2
	movq (sp),r0
	cbeq r0,#7,.L551
	bis #128,r8
.L551:
	lea 120(sp),r0
	movq #10,r2
	movq #2,r1
	call idx
	movq 136(sp),r0
	cbne r0,#13,.L555
	movq 144(sp),r0
	cbeq r0,#5,.L553
.L555:
	bis #256,r8
.L553:
	movq #1,r0
	movq r0,g
	movq #-1,r0
	movl r0,gi
	movq #32767,r0
	movw r0,gs
	movq #127,r0
	movb r0,gc
	call incg
	movq g,r0
	cbne r0,#2,.L559
	movl gi,r0
	cbne r0,#0,.L559
	movw gs,r0
	cbne r0,#-32768,.L559
	movb gc,r0
	cbeq r0,#-128,.L557
.L559:
	bis #512,r8
.L557:
	lea 64(sp),r0
	movq #5,r1
	call flds
	movq 64(sp),r0
	cbne r0,#15,.L563
	movq 72(sp),r0
	cbne r0,#15,.L563
	movl 80(sp),r0
	cbne r0,#33,.L563
	movq 104(sp),r0
	cbne r0,#7,.L563
	movq 96(sp),r0
	cbeq r0,#1,.L561
.L563:
	bis #1024,r8
.L561:
	movq #15,r1
	movq #255,r0
	call andn
	cbne r0,#240,.L567
	movq #10,r1
	movq #12,r0
	call andn2
	cbne r0,#6,.L567
	movq #4080,r1
	movq #65280,r0
	call andn3
	cmp r0,#61440
	beq .L565
.L567:
	bis #2048,r8
.L565:
	movq #5,r0
	call loop1
	cbeq r0,#15,.L569
	bis #4096,r8
.L569:
	lea 120(sp),r1
	movq #6,r0
	call loop2
	cbeq r0,#32,.L571
	bis #8192,r8
.L571:
	movq #7,r0
	call loop3
	cbeq r0,#7,.L573
	bis #16384,r8
.L573:
	movq #10,r1
	movq #3,r0
	call loop4
	cbeq r0,#33,.L575
	bis #32768,r8
.L575:
	movq #4,r0
	call loop5
	cbeq r0,#8,.L577
	bis #65536,r8
.L577:
	movq #97,r0
	movb r0,56(sp)
	movq #98,r0
	movb r0,57(sp)
	movq #99,r0
	movb r0,58(sp)
	movq #100,r0
	movb r0,59(sp)
	movq #101,r0
	movb r0,60(sp)
	movq #102,r0
	movb r0,61(sp)
	movq #103,r0
	movb r0,62(sp)
	clr r0
	movb r0,63(sp)
	lea 8(sp),r1
	lea .L581,r2
	lea 40(r1),r0
.L583:
	movl (r2)+,r3
	movl r3,(r1)+
	cbcs r1,r0,.L583
	lea 48(sp),r0
	lea 56(sp),r1
	movq #7,r2
	call w1
	cbne r0,#7,.L587
	movb 54(sp),r0
	cbne r0,#103,.L587
	movb 48(sp),r0
	cbeq r0,#97,.L585
.L587:
	bis #131072,r8
.L585:
	lea 48(sp),r0
	lea 56(sp),r1
	clr r2
	call w1
	cbeq r0,#0,.L589
	bis #131072,r8
.L589:
	lea 8(sp),r1
	movq #5,r0
	call w2
	cbne r0,#3,.L593
	lea 8(sp),r1
	clr r0
	call w2
	cbeq r0,#0,.L591
.L593:
	bis #262144,r8
.L591:
	movq #10,r0
	call w3
	cbne r0,#4,.L597
	movq #3,r0
	call w3
	cbne r0,#3,.L597
	clr r0
	call w3
	cbeq r0,#0,.L595
.L597:
	bis #524288,r8
.L595:
	movq #5,r0
	call w4
	cbeq r0,#10,.L599
	bis #1048576,r8
.L599:
	movq #3,r0
	call w5
	cbne r0,#2,.L603
	clr r0
	call w5
	cbeq r0,#-1,.L601
.L603:
	bis #2097152,r8
.L601:
	movq #100,r0
	call w6
	cbne r0,#22,.L607
	movq #2,r0
	call w6
	cbne r0,#4,.L607
	clr r0
	call w6
	cbeq r0,#0,.L605
.L607:
	bis #4194304,r8
.L605:
	movl r8,r0
	add #168,sp
	popret r8
	; ret:one,out=0
	.comm g,8
	.comm gi,4
	.comm gs,2
	.comm gc,1
	.comm rr,56
