	.text
	.even
	.globl rl7
rl7:
.L251:
.L255:
	rori32 r0,#25,r0
	; ret:one,out=0
	ret
	.even
	.globl rr3
rr3:
.L259:
.L263:
	rori32 r0,#3,r0
	; ret:one,out=0
	ret
	.even
	.globl mix
mix:
.L267:
.L271:
	rori32 r0,#27,r0
	add r1,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl less
less:
.L275:
.L279:
	rori32 r0,#21,r0
	cmp r0,r1
	set cs,r0
.L283:
	; ret:one,out=0
	ret
	.even
	.globl wide
wide:
.L287:
.L291:
	rori32 r0,#31,r0
	movzl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl store
store:
.L297:
.L301:
	rori32 r0,#16,r1
	movl r1,st
	rori32 r0,#8,r0
	movl r0,st+4
	; ret:one,out=0
	ret
	.even
	.globl top
top:
.L305:
.L309:
	rori32 r0,#28,r0
	; ret:one,out=0
	ret
	.even
	.globl topcmp
topcmp:
.L313:
.L317:
	call top
	cmp r0,#2147483647
	blos .L319
	movq #1,r0
	ret
.L319:
	clr r0
.L321:
	; ret:one,out=0
	ret
	.even
	.globl topwide
topwide:
.L325:
.L329:
	call top
	movzl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl topshr
topshr:
.L333:
.L337:
	call top
	movzl r0,r0
	shr #1,r0
	; ret:one,out=0
	ret
	.even
	.globl topdiv
topdiv:
.L341:
.L345:
	call top
	movq #3,r2
	movzl r0,r1
	movzl r2,r3
	divu r1,r3,r1
	movl r1,r0
	; ret:one,out=0
	ret
	.even
	.globl test
test:
.L349:
.L353:
	movq #-2147483647,r0
	call rl7
	cbeq r0,#192,.L355
	movq #2,r0
	ret
.L355:
	movq #-2147483647,r0
	call rr3
	cmp r0,#805306368
	beq .L357
	movq #3,r0
	ret
.L357:
	movq #1,r1
	movq #305419896,r0
	call mix
	cmp r0,#1183502083
	beq .L359
	movq #4,r0
	ret
.L359:
	movq #-1,r1
	movq #-2147483647,r0
	call less
	cbne r0,#0,.L361
	movq #5,r0
	ret
.L361:
	movq #5,r1
	movq #-1,r0
	call less
	cbeq r0,#0,.L363
	movq #6,r0
	ret
.L363:
	movq #-1073741824,r0
	call wide
	cmp r0,=2147483649
	beq .L365
	movq #7,r0
	ret
.L365:
	movq #-2147483648,r0
	call wide
	cbeq r0,#1,.L367
	movq #8,r0
	ret
.L367:
	movq #305419896,r0
	call store
	movl st,r0
	cmp r0,#1450709556
	bne .L371
	movl st+4,r0
	cmp r0,#2014458966
	beq .L369
.L371:
	movq #9,r0
	ret
.L369:
	clr r0
	call rl7
	cbne r0,#0,.L375
	movq #-1,r0
	call rr3
	cbeq r0,#-1,.L373
.L375:
	movq #10,r0
	ret
.L373:
	movq #134217728,r0
	call top
	cmp r0,#-2147483648
	beq .L377
	movq #11,r0
	ret
.L377:
	movq #134217728,r0
	call topcmp
	cbne r0,#0,.L379
	movq #12,r0
	ret
.L379:
	movq #1,r0
	call topcmp
	cbeq r0,#0,.L381
	movq #13,r0
	ret
.L381:
	movq #134217728,r0
	call topwide
	cmp r0,=2147483648
	beq .L383
	movq #14,r0
	ret
.L383:
	movq #134217728,r0
	call topshr
	cmp r0,#1073741824
	beq .L385
	movq #15,r0
	ret
.L385:
	movq #268435455,r0
	call topdiv
	cmp r0,#1431655760
	beq .L387
	movq #16,r0
	ret
.L387:
	movq #1,r0
.L351:
	; ret:one,out=0
	ret
	.comm st,8
