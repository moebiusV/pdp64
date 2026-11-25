	.text
	.even
	.globl f1
f1:
.L251:
.L255:
	cbge r0,r1,.L257
	cbge r1,r2,.L257
	movq #1,r0
	br .L259
.L257:
	clr r0
.L259:
	tst r0
	set ne,r0
.L253:
	; ret:one,out=0
	ret
	.even
	.globl f2
f2:
.L265:
.L269:
	cblt r0,r1,.L273
	cbge r1,r2,.L271
.L273:
	br .L277
.L271:
.L275:
	movq #1,r0
	ret
.L277:
	clr r0
.L267:
	; ret:one,out=0
	ret
	.even
	.globl f3
f3:
.L281:
.L285:
	cbeq r0,#0,.L287
	cble r1,#3,.L295
.L282:
	movq #1,r0
	br .L293
.L287:
	cblt r1,#0,.L282
.L295:
	clr r0
.L293:
	cbeq r0,#0,.L299
	movq #10,r0
	ret
.L299:
	movq #20,r0
.L301:
	; ret:one,out=0
	ret
	.even
	.globl f4
f4:
.L305:
	movq r0,r1
.L309:
	clr r3
	clr r0
	br .L311
.L306:
	movq r3,r2
	mul #3,r2
	cbne r2,#12,.L315
	cbge r0,#2,.L313
.L315:
	add r3,r0
	inc r3
.L311:
	cblt r3,r1,.L306
.L313:
	mul #100,r0
	add r3,r0
	; ret:one,out=0
	ret
	.even
	.globl f5
f5:
.L319:
	movq r0,r2
.L323:
	cmp r2,r1
	set ne,r0
.L327:
	cbeq r0,#0,.L329
	cbcc r2,r1,.L329
	movq #1,r0
	ret
.L329:
	clr r0
.L331:
	; ret:one,out=0
	ret
	.even
	.globl f6
f6:
.L335:
	movq r0,r2
.L339:
	clr r0
	clr r4
	br .L345
.L336:
	movl (r2)(r4*4),r3
	cbeq r3,#0,.L343
	inc r0
	inc r4
.L345:
	cblt r4,r1,.L336
.L343:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	pushm #768
	sub #24,sp
.L349:
.L353:
	clr r8
	movq #1,r0
	movl r0,4(sp)
	movq #2,r0
	movl r0,8(sp)
	movq #3,r0
	movl r0,12(sp)
	clr r0
	movl r0,16(sp)
	movq #5,r0
	movl r0,20(sp)
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call f1
	cbne r0,#1,.L357
	movq #1,r2
	movq #2,r1
	movq #3,r0
	call f1
	cbne r0,#0,.L357
	movq #2,r2
	movq #2,r1
	movq #1,r0
	call f1
	cbeq r0,#0,.L355
.L357:
	movq #1,r8
.L355:
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call f2
	cbne r0,#0,.L361
	movq #1,r2
	movq #2,r1
	movq #3,r0
	call f2
	cbne r0,#1,.L361
	movq #5,r2
	movq #2,r1
	movq #3,r0
	call f2
	cbeq r0,#0,.L359
.L361:
	bis #2,r8
.L359:
	movq #4,r1
	movq #1,r0
	call f3
	cbne r0,#10,.L365
	movq #3,r1
	movq #1,r0
	call f3
	cbne r0,#20,.L365
	movq #-1,r1
	clr r0
	call f3
	cbne r0,#10,.L365
	movq #1,r1
	clr r0
	call f3
	cbeq r0,#20,.L363
.L365:
	bis #4,r8
.L363:
	movq #10,r0
	call f4
	cbeq r0,#604,.L367
	movq #10,r0
	call f4
	movq r0,r9
	movq #10,r0
	call f4
	cbeq r9,r0,.L367
	bis #8,r8
.L367:
	movq #3,r0
	call f4
	cbeq r0,#303,.L369
	bis #8,r8
.L369:
	movq #4,r1
	movq #3,r0
	call f5
	cbne r0,#1,.L373
	movq #3,r1
	movq #4,r0
	call f5
	cbne r0,#0,.L373
	movq #3,r1
	movq #3,r0
	call f5
	cbeq r0,#0,.L371
.L373:
	bis #16,r8
.L371:
	lea 4(sp),r0
	movq #5,r1
	call f6
	cbne r0,#3,.L377
	lea 4(sp),r0
	movq #2,r1
	call f6
	cbeq r0,#2,.L375
.L377:
	bis #32,r8
.L375:
	movq r8,r0
	add #24,sp
	popmret #768
	; ret:one,out=0
