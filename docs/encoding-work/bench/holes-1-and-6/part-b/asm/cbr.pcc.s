	.text
	.even
	.globl lt
lt:
.L251:
.L255:
	cmp r0,r1
	set lt,r0
.L253:
	; ret:one,out=0
	ret
	.even
	.globl le
le:
.L261:
.L265:
	cmp r0,r1
	set le,r0
.L263:
	; ret:one,out=0
	ret
	.even
	.globl gt
gt:
.L271:
.L275:
	cmp r0,r1
	set gt,r0
.L273:
	; ret:one,out=0
	ret
	.even
	.globl ge
ge:
.L281:
.L285:
	cmp r0,r1
	set ge,r0
.L283:
	; ret:one,out=0
	ret
	.even
	.globl eq
eq:
.L291:
.L295:
	cmp r0,r1
	set eq,r0
.L293:
	; ret:one,out=0
	ret
	.even
	.globl ne
ne:
.L301:
.L305:
	cmp r0,r1
	set ne,r0
.L303:
	; ret:one,out=0
	ret
	.even
	.globl ult
ult:
.L311:
.L315:
	cmp r0,r1
	set cs,r0
.L313:
	; ret:one,out=0
	ret
	.even
	.globl ule
ule:
.L321:
.L325:
	cmp r0,r1
	set los,r0
.L323:
	; ret:one,out=0
	ret
	.even
	.globl ugt
ugt:
.L331:
.L335:
	cmp r0,r1
	set hi,r0
.L333:
	; ret:one,out=0
	ret
	.even
	.globl uge
uge:
.L341:
.L345:
	cmp r0,r1
	set cc,r0
.L343:
	; ret:one,out=0
	ret
	.even
	.globl ilt
ilt:
.L351:
.L355:
	cmp r0,r1
	set lt,r0
.L353:
	; ret:one,out=0
	ret
	.even
	.globl ult32
ult32:
.L361:
.L365:
	cmp r0,r1
	set cs,r0
.L363:
	; ret:one,out=0
	ret
	.even
	.globl three
three:
.L371:
.L375:
	cbne r0,r1,.L377
	clr r0
	ret
.L377:
	cbge r0,r1,.L379
	movq #-1,r0
	ret
.L379:
	movq #1,r0
.L373:
	; ret:one,out=0
	ret
	.even
	.globl loop
loop:
.L383:
	movq r0,r1
.L387:
	clr r0
	clr r2
	br .L393
.L384:
	add r2,r0
	inc r2
.L393:
	cblt r2,r1,.L384
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	pushm #1792
.L397:
.L401:
	movq =-9223372036854775808,r10
	movq =9223372036854775807,r9
	movq #-1,r8
	movq #2,r1
	movq #1,r0
	call lt
	cbne r0,#1,.L405
	movq #1,r1
	movq #2,r0
	call lt
	cbne r0,#0,.L405
	movq #1,r1
	movq #1,r0
	call lt
	cbeq r0,#0,.L403
.L405:
	movq #2,r0
	br .L399
.L403:
	movq =9223372036854775807,r1
	movq =-9223372036854775808,r0
	call lt
	cbne r0,#1,.L409
	mov2 r10,r1,r9,r0
	call lt
	cbne r0,#0,.L409
	mov2 r10,r1,r10,r0
	call lt
	cbeq r0,#0,.L407
.L409:
	movq #3,r0
	br .L399
.L407:
	movq =9223372036854775807,r1
	movq =-9223372036854775808,r0
	call le
	cbne r0,#1,.L413
	mov2 r10,r1,r9,r0
	call le
	cbne r0,#0,.L413
	mov2 r9,r1,r9,r0
	call le
	cbeq r0,#1,.L411
.L413:
	movq #4,r0
	br .L399
.L411:
	movq =-9223372036854775808,r1
	movq =9223372036854775807,r0
	call gt
	cbne r0,#1,.L417
	mov2 r9,r1,r10,r0
	call gt
	cbne r0,#0,.L417
	movq #-1,r1
	clr r0
	call gt
	cbeq r0,#1,.L415
.L417:
	movq #5,r0
	br .L399
.L415:
	movq =9223372036854775807,r1
	movq =-9223372036854775808,r0
	call ge
	cbne r0,#0,.L421
	mov2 r10,r1,r9,r0
	call ge
	cbne r0,#1,.L421
	mov2 r10,r1,r10,r0
	call ge
	cbeq r0,#1,.L419
.L421:
	movq #6,r0
	br .L399
.L419:
	movq =-9223372036854775808,r1
	movq =-9223372036854775808,r0
	call eq
	cbne r0,#1,.L425
	mov2 r9,r1,r10,r0
	call eq
	cbne r0,#0,.L425
	mov2 r9,r1,r10,r0
	call ne
	cbne r0,#1,.L425
	mov2 r9,r1,r9,r0
	call ne
	cbeq r0,#0,.L423
.L425:
	movq #7,r0
	br .L399
.L423:
	movq #2,r1
	movq #1,r0
	call ult
	cbne r0,#1,.L429
	clr r1
	movcall r8,r0,ult
	cbne r0,#0,.L429
	clr r0
	movcall r8,r1,ult
	cbne r0,#1,.L429
	mov2 r8,r1,r8,r0
	call ult
	cbeq r0,#0,.L427
.L429:
	movq #8,r0
	br .L399
.L427:
	movq #-1,r1
	movq #-1,r0
	call ule
	cbne r0,#1,.L433
	clr r1
	movcall r8,r0,ule
	cbne r0,#0,.L433
	clr r0
	movcall r8,r1,ule
	cbeq r0,#1,.L431
.L433:
	movq #9,r0
	br .L399
.L431:
	clr r1
	movq #-1,r0
	call ugt
	cbne r0,#1,.L437
	clr r0
	movcall r8,r1,ugt
	cbne r0,#0,.L437
	movq #5,r1
	movq #5,r0
	call ugt
	cbeq r0,#0,.L435
.L437:
	movq #10,r0
	br .L399
.L435:
	movq #-1,r1
	clr r0
	call uge
	cbne r0,#0,.L441
	clr r1
	movcall r8,r0,uge
	cbne r0,#1,.L441
	movq #7,r1
	movq #7,r0
	call uge
	cbeq r0,#1,.L439
.L441:
	movq #11,r0
	br .L399
.L439:
	movq #1,r1
	movq =-9223372036854775808,r0
	call ult
	cbne r0,#0,.L445
	movq =-9223372036854775808,r1
	movq #1,r0
	call ult
	cbeq r0,#1,.L443
.L445:
	movq #12,r0
	br .L399
.L443:
	movq #2147483647,r1
	movq #-2147483648,r0
	call ilt
	cbne r0,#1,.L449
	movq #-2147483648,r1
	movq #2147483647,r0
	call ilt
	cbeq r0,#0,.L447
.L449:
	movq #13,r0
	br .L399
.L447:
	movq #1,r1
	movq #-2147483648,r0
	call ult32
	cbne r0,#0,.L453
	movq #-1,r1
	movq #1,r0
	call ult32
	cbne r0,#1,.L453
	movq #-1,r1
	movq #-1,r0
	call ult32
	cbeq r0,#0,.L451
.L453:
	movq #14,r0
	br .L399
.L451:
	movq #1,r1
	movq #1,r0
	call three
	cbne r0,#0,.L457
	movq #2,r1
	movq #1,r0
	call three
	cbne r0,#-1,.L457
	movq #1,r1
	movq #2,r0
	call three
	cbne r0,#1,.L457
	mov2 r9,r1,r10,r0
	call three
	cbne r0,#-1,.L457
	mov2 r10,r1,r9,r0
	call three
	cbeq r0,#1,.L455
.L457:
	movq #15,r0
	br .L399
.L455:
	movq #10,r0
	call loop
	cbne r0,#45,.L461
	clr r0
	call loop
	cbeq r0,#0,.L459
.L461:
	movq #16,r0
	br .L399
.L459:
	movq #1,r0
.L399:
	popmret #1792
	; ret:one,out=0
