	.text
	.even
	.globl fb
fb:
.L251:
.L255:
	movl (r0),r0
	extzb r0,#3,#5,r0
	; ret:one,out=0
	ret
	.even
	.globl fc
fc:
.L259:
.L263:
	movl (r0),r0
	extzb r0,#8,#9,r0
	; ret:one,out=0
	ret
	.even
	.globl fd
fd:
.L267:
.L271:
	movl (r0),r0
	shl #11,r0
	movl r0,r0
	sar #28,r0
	; ret:one,out=0
	ret
	.even
	.globl ff
ff:
.L275:
.L279:
	movl 4(r0),r0
	shl #27,r0
	movl r0,r0
	sar #27,r0
	; ret:one,out=0
	ret
	.even
	.globl fe
fe:
.L283:
.L287:
	movl (r0),r0
	extzb r0,#21,#7,r0
	; ret:one,out=0
	ret
	.even
	.globl sb
sb:
.L291:
.L295:
	movl (r0),r2
	insb r1,#3,#5,r2
	movl r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl sc
sc:
.L299:
.L303:
	movl (r0),r2
	insb r1,#8,#9,r2
	movl r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl sd
sd:
.L307:
.L311:
	movl (r0),r2
	insb r1,#17,#4,r2
	movl r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl sf
sf:
.L315:
.L319:
	lea 4(r0),r2
	movl (r2),r0
	insb r1,#0,#5,r0
	movl r0,(r2)
	; ret:one,out=0
	ret
	.even
	.globl sa
sa:
.L323:
.L327:
	movl (r0),r2
	insb r1,#0,#3,r2
	movl r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl qb
qb:
.L331:
.L335:
	movq (r0),r0
	extzb r0,#5,#40,r0
	; ret:one,out=0
	ret
	.even
	.globl qd
qd:
.L339:
.L343:
	movq 8(r0),r0
	extb r0,#0,#8,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl qsb
qsb:
.L347:
.L351:
	movq (r0),r2
	and =-35184372088801,r2
	and =1099511627775,r1
	shl #5,r1
	bis r1,r2
	movq r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl qsc
qsc:
.L355:
.L359:
	movq (r0),r2
	and =35184372088831,r2
	and #524287,r1
	shl #45,r1
	bis r1,r2
	movq r2,(r0)
	; ret:one,out=0
	ret
	.even
	.globl qsd
qsd:
.L363:
.L367:
	lea 8(r0),r2
	movq (r2),r0
	and #-256,r0
	movzb r1,r1
	bis r1,r0
	movq r0,(r2)
	; ret:one,out=0
	ret
	.even
	.globl ex
ex:
.L371:
.L375:
	extzb r0,#3,#5,r0
	; ret:one,out=0
	ret
	.even
	.globl ex2
ex2:
.L379:
.L383:
	extzb r0,#11,#12,r0
	; ret:one,out=0
	ret
	.even
	.globl ex3
ex3:
.L387:
.L391:
	shl #4,r0
	shr #9,r0
	; ret:one,out=0
	ret
	.even
	.globl ex4
ex4:
.L395:
.L399:
	shl #4,r0
	sar #9,r0
	; ret:one,out=0
	ret
	.even
	.globl ex5
ex5:
.L403:
.L407:
	extzb r0,#23,#4,r0
	; ret:one,out=0
	ret
	.even
	.globl ex6
ex6:
.L411:
.L415:
	shl #5,r0
	movl r0,r0
	sar #28,r0
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	pushm #16813824
	sub #24,sp
.L419:
.L423:
	clr r8
	lea 16(sp),r0
	clr r1
	movl r1,(r0)
	movl r1,4(r0)
	lea 16(sp),r0
	movq #5,r1
	call sa
	lea 16(sp),r0
	movq #19,r1
	call sb
	lea 16(sp),r0
	movq #300,r1
	call sc
	lea 16(sp),r0
	movq #-3,r1
	call sd
	lea 16(sp),r0
	movq #-9,r1
	call sf
	lea 16(sp),r2
	movl (r2),r0
	and #-266338305,r0
	movq #100,r1
	shl #21,r1
	bis r1,r0
	movl r0,(r2)
	movl 16(sp),r0
	extzb r0,#0,#3,r0
	cbne r0,#5,.L427
	lea 16(sp),r0
	call fb
	cbne r0,#19,.L427
	lea 16(sp),r0
	call fc
	cbne r0,#300,.L427
	lea 16(sp),r0
	call fd
	cbne r0,#-3,.L427
	lea 16(sp),r0
	call ff
	cbne r0,#-9,.L427
	lea 16(sp),r0
	call fe
	cbeq r0,#100,.L425
.L427:
	movq #1,r8
.L425:
	lea 16(sp),r0
	movq #255,r1
	call sb
	lea 16(sp),r0
	call fb
	cbne r0,#31,.L431
	movl 16(sp),r0
	extzb r0,#0,#3,r0
	cbne r0,#5,.L431
	lea 16(sp),r0
	call fc
	cbne r0,#300,.L431
	lea 16(sp),r0
	call fd
	cbeq r0,#-3,.L429
.L431:
	bis #2,r8
.L429:
	lea 16(sp),r0
	movq #7,r1
	call sd
	lea 16(sp),r0
	call fd
	cbne r0,#7,.L435
	lea 16(sp),r0
	call fc
	cbeq r0,#300,.L433
.L435:
	bis #4,r8
.L433:
	lea 16(sp),r0
	movq #8,r1
	call sd
	lea 16(sp),r0
	call fd
	cbeq r0,#-8,.L437
	bis #8,r8
.L437:
	lea 16(sp),r0
	movq #15,r1
	call sf
	lea 16(sp),r0
	call ff
	cbeq r0,#15,.L439
	bis #16,r8
.L439:
	lea 16(sp),r0
	movq #16,r1
	call sf
	lea 16(sp),r0
	call ff
	cbne r0,#-16,.L443
	lea 16(sp),r0
	call fe
	cbeq r0,#100,.L441
.L443:
	bis #32,r8
.L441:
	lea 16(sp),r0
	movq #511,r1
	call sc
	lea 16(sp),r0
	call fc
	cbne r0,#511,.L447
	lea 16(sp),r0
	call fb
	cbne r0,#31,.L447
	lea 16(sp),r0
	call fd
	cbeq r0,#-8,.L445
.L447:
	bis #64,r8
.L445:
	lea 16(sp),r0
	movq #512,r1
	call sc
	lea 16(sp),r0
	call fc
	cbne r0,#0,.L451
	lea 16(sp),r0
	call fb
	cbeq r0,#31,.L449
.L451:
	bis #128,r8
.L449:
	movq sp,r1
	movq (r1),r0
	and #-32,r0
	bis #0,r0
	movq r0,(r1)
	movq sp,r2
	movq (r2),r0
	and =-35184372088801,r0
	clr r1
	shl #5,r1
	bis r1,r0
	movq r0,(r2)
	movq sp,r2
	movq (r2),r0
	and =35184372088831,r0
	clr r1
	shl #45,r1
	bis r1,r0
	movq r0,(r2)
	lea 8(sp),r1
	movq (r1),r0
	and #-256,r0
	bis #0,r0
	movq r0,(r1)
	movq =78187493530,r1
	movcall sp,r0,qsb
	movq #524287,r1
	movcall sp,r0,qsc
	movq #-100,r1
	movcall sp,r0,qsd
	movq sp,r1
	movq (r1),r0
	and #-32,r0
	bis #17,r0
	movq r0,(r1)
	movcall sp,r0,qb
	cmp r0,=78187493530
	bne .L455
	movcall sp,r0,qd
	cbne r0,#-100,.L455
	movq (sp),r0
	shr #45,r0
	movl r0,r0
	cmp r0,#524287
	bne .L455
	movq (sp),r0
	extzb r0,#0,#5,r0
	movl r0,r0
	cbeq r0,#17,.L453
.L455:
	bis #256,r8
.L453:
	movq #-1,r1
	movcall sp,r0,qsb
	movcall sp,r0,qb
	cmp r0,=1099511627775
	bne .L459
	movq (sp),r0
	shr #45,r0
	movl r0,r0
	cmp r0,#524287
	bne .L459
	movq (sp),r0
	extzb r0,#0,#5,r0
	movl r0,r0
	cbeq r0,#17,.L457
.L459:
	bis #512,r8
.L457:
	clr r11
	br .L465
.L420:
	movq r11,r10
	mul #4369,r10
	add #-559038737,r10
	movl r10,r10
	lea 1(r11),r9
	mul =-81985529216486896,r9
	movq r9,r24
	movq r10,r15
	movcall r10,r0,ex
	movzl r10,r1
	extzb r1,#3,#5,r1
	cbeq r0,r1,.L467
	bis #1024,r8
.L467:
	movcall r9,r0,ex2
	movq r9,r1
	extzb r1,#11,#12,r1
	cbeq r0,r1,.L469
	bis #2048,r8
.L469:
	movcall r9,r0,ex3
	shl #4,r9
	shr #9,r9
	cbeq r0,r9,.L471
	bis #4096,r8
.L471:
	movcall r24,r0,ex4
	shl #4,r24
	sar #9,r24
	cbeq r0,r24,.L473
	bis #8192,r8
.L473:
	movcall r10,r0,ex5
	extzb r10,#23,#4,r10
	cbeq r0,r10,.L475
	bis #16384,r8
.L475:
	movcall r15,r0,ex6
	shl #5,r15
	movl r15,r15
	sar #28,r15
	cbeq r0,r15,.L461
	bis #32768,r8
.L461:
	inc r11
.L465:
	cblt r11,#4,.L420
	movl r8,r0
	add #24,sp
	popm #16813824
	; ret:one,out=0
	ret
