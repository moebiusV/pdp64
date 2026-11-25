	.text
	.even
	.globl cpy
cpy:
.L251:
.L255:
	cbeq r2,#0,.Lppw0
.L252:
	movb (r1)+,r3
	movb r3,(r0)+
.L257:
	sob r2,.L252
.Lppw0:
	; ret:one,out=0
	ret
	.even
	.globl len
len:
.L263:
	movq r0,r1
.L267:
	br .L269
.L264:
	inc r0
.L269:
	movb (r0),r2
	cbne r2,#0,.L264
	sub r1,r0
	; ret:one,out=0
	ret
	.even
	.globl cpyz
cpyz:
.L275:
.L279:
.L281:
	movb (r1)+,r2
	movb r2,(r0)+
	cbne r2,#0,.L281
	; ret:one,out=0
	ret
	.even
	.globl sumi
sumi:
.L287:
	movq r0,r2
.L291:
	clr r0
	cbeq r1,#0,.Lppw1
.L288:
	movl (r2)+,r4
	add r4,r0
.L293:
	sob r1,.L288
.Lppw1:
	; ret:one,out=0
	ret
	.even
	.globl sums
sums:
.L299:
	movq r0,r2
.L303:
	clr r0
	clr r3
	br .L309
.L300:
	movw (r2)+,r5
	add r5,r0
	inc r3
.L309:
	cblt r3,r1,.L300
	; ret:one,out=0
	ret
	.even
	.globl suml
suml:
.L313:
	movq r0,r2
.L317:
	clr r0
	clr r3
	br .L323
.L314:
	add (r2),r0
	lea 8(r2),r2
	inc r3
.L323:
	cblt r3,r1,.L314
	; ret:one,out=0
	ret
	.even
	.globl sumr
sumr:
.L327:
	movq r0,r2
.L331:
	clr r0
	movq r1,r3
	shl #2,r3
	add r3,r2
	cbeq r1,#0,.Lppw2
.L328:
	add #-4,r2
	movl (r2),r3
	add r3,r0
.L333:
	sob r1,.L328
.Lppw2:
	; ret:one,out=0
	ret
	.even
	.globl sumst
sumst:
.L339:
	movq r0,r2
.L343:
	clr r0
	clr r3
	br .L349
.L340:
	movl 4(r2),r4
	add r4,r0
	lea 12(r2),r2
	inc r3
.L349:
	cblt r3,r1,.L340
	; ret:one,out=0
	ret
	.even
	.globl sums3
sums3:
.L353:
	movq r0,r2
.L357:
	clr r0
	clr r3
	br .L363
.L354:
	movb (r2)+3,r4
	add r4,r0
	inc r3
.L363:
	cblt r3,r1,.L354
	; ret:one,out=0
	ret
	.even
	.globl after
after:
.L367:
.L371:
	movb (r0)+,r2
	movb r2,(r1)
	; ret:one,out=0
	ret
	.even
	.globl both
both:
.L375:
	movq r0,r1
.L379:
	movl (r1)+,r0
	movl (r1)+,r2
	mul #10,r0
	add r2,r0
	movl (r1),r2
	add r2,r0
	; ret:one,out=0
	ret
	.even
	.globl rev
rev:
.L383:
.L387:
	add r2,r1
	cbeq r2,#0,.Lppw3
.L384:
	movb -(r1),r4
	movb r4,(r0)+
.L389:
	sob r2,.L384
.Lppw3:
	; ret:one,out=0
	ret
	.even
	.globl ubytes
ubytes:
.L395:
.L399:
	movzb (r0)+,r2
	movzb (r0)+,r4
	shl #8,r2
	add r4,r2
	movq r2,(r1)
	; ret:one,out=0
	ret
	.data
	.align 4
.L409:
	.long 1
	.long 2
	.long 3
	.long 4
	.long 5
	.long 6
	.long 7
	.long 8
	.long 9
	.text
	.even
	.globl test
test:
	push r8
	sub #144,sp
.L403:
.L407:
	clr r8
	movq #1,r0
	movl r0,88(sp)
	movq #2,r0
	movl r0,92(sp)
	movq #3,r0
	movl r0,96(sp)
	movq #4,r0
	movl r0,100(sp)
	movq #5,r0
	movl r0,104(sp)
	movq #6,r0
	movl r0,108(sp)
	movq #10,r0
	movw r0,80(sp)
	movq #20,r0
	movw r0,82(sp)
	movq #30,r0
	movw r0,84(sp)
	movq #40,r0
	movw r0,86(sp)
	movq #100,r0
	movq r0,56(sp)
	movq #200,r0
	movq r0,64(sp)
	movq #300,r0
	movq r0,72(sp)
	lea 20(sp),r1
	lea .L409,r2
	lea 36(r1),r0
.L411:
	movl (r2)+,r3
	movl r3,(r1)+
	cbcs r1,r0,.L411
	movq #1,r0
	movb r0,11(sp)
	movq #2,r0
	movb r0,12(sp)
	movq #3,r0
	movb r0,13(sp)
	movq #4,r0
	movb r0,14(sp)
	movq #5,r0
	movb r0,15(sp)
	movq #6,r0
	movb r0,16(sp)
	movq #7,r0
	movb r0,17(sp)
	movq #8,r0
	movb r0,18(sp)
	movq #9,r0
	movb r0,19(sp)
	movq #18,r0
	movb r0,8(sp)
	movq #254,r0
	movb r0,9(sp)
	movq #7,r0
	movb r0,10(sp)
	clr r0
	br .L417
.L404:
	lea 1(r0),r2
	movb r2,128(sp)(r0)
	inc r0
.L417:
	cblt r0,#16,.L404
	lea 112(sp),r0
	lea 128(sp),r1
	movq #16,r2
	call cpy
	clr r0
	br .L423
.L406:
	movb 112(sp)(r0),r2
	lea 1(r0),r1
	cbeq r2,r1,.L419
	bis #1,r8
.L419:
	inc r0
.L423:
	cblt r0,#16,.L406
	lea .L427,r0
	call len
	cbeq r0,#5,.L429
	bis #2,r8
.L429:
	lea 112(sp),r0
	lea .L431,r1
	call cpyz
	movb 112(sp),r0
	cbne r0,#97,.L435
	movb 114(sp),r0
	cbne r0,#99,.L435
	movb 115(sp),r0
	cbeq r0,#0,.L433
.L435:
	bis #4,r8
.L433:
	lea 88(sp),r0
	movq #6,r1
	call sumi
	cbeq r0,#21,.L437
	bis #8,r8
.L437:
	lea 80(sp),r0
	movq #4,r1
	call sums
	cbeq r0,#100,.L439
	bis #16,r8
.L439:
	lea 56(sp),r0
	movq #3,r1
	call suml
	cbeq r0,#600,.L441
	bis #32,r8
.L441:
	lea 88(sp),r0
	movq #6,r1
	call sumr
	cbeq r0,#21,.L443
	bis #64,r8
.L443:
	lea 20(sp),r0
	movq #3,r1
	call sumst
	cbeq r0,#15,.L445
	bis #128,r8
.L445:
	lea 11(sp),r0
	movq #3,r1
	call sums3
	cbeq r0,#12,.L447
	bis #256,r8
.L447:
	lea 128(sp),r0
	lea 112(sp),r1
	call after
	lea 129(sp),r1
	cbne r0,r1,.L451
	movb 112(sp),r0
	cbeq r0,#1,.L449
.L451:
	bis #512,r8
.L449:
	lea 88(sp),r0
	call both
	cbeq r0,#15,.L453
	bis #1024,r8
.L453:
	lea 112(sp),r0
	lea 128(sp),r1
	movq #5,r2
	call rev
	movb 112(sp),r0
	cbne r0,#5,.L457
	movb 116(sp),r0
	cbeq r0,#1,.L455
.L457:
	bis #2048,r8
.L455:
	lea 8(sp),r0
	movcall sp,r1,ubytes
	lea 10(sp),r1
	cbne r0,r1,.L461
	movq (sp),r0
	cbeq r0,#4862,.L459
.L461:
	bis #4096,r8
.L459:
	movl r8,r0
	add #144,sp
	popret r8
	; ret:one,out=0
	.text
	.even
	.even
.L431:
	.byte 97,98,99,0
	.even
	.even
.L427:
	.byte 104,101,108,108,111,0
