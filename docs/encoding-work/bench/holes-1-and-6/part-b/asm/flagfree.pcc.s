	.data
	.align 8
	.globl g
g:
	.quad 0
	.quad 5
	.quad -3
	.quad 0
	.text
	.even
	.globl ld
ld:
.L253:
.L257:
	movq (r0)(r1*8),r0
	tst r0
	set ne,r0
.L255:
	; ret:one,out=0
	ret
	.even
	.globl ldneg
ldneg:
.L263:
.L267:
	movq (r0)(r1*8),r0
	cbge r0,#0,.L269
	movq #-1,r0
	ret
.L269:
	tst r0
	set gt,r0
.L265:
	; ret:one,out=0
	ret
	.even
	.globl sh
sh:
.L275:
.L279:
	shl r1,r0
	cbne r0,#0,.L281
	clr r0
	ret
.L281:
	cbge r0,#0,.L283
	movq #-1,r0
	ret
.L283:
	movq #1,r0
.L277:
	; ret:one,out=0
	ret
	.even
	.globl shr
shr:
.L287:
.L291:
	shr r1,r0
	tst r0
	set ne,r0
.L289:
	; ret:one,out=0
	ret
	.even
	.globl three
three:
.L297:
.L301:
	cbne r0,r1,.L303
	clr r0
	ret
.L303:
	cbge r0,r1,.L305
	movq #-1,r0
	ret
.L305:
	movq #1,r0
.L299:
	; ret:one,out=0
	ret
	.even
	.globl chain
chain:
.L309:
.L313:
	cbne r0,#1,.L315
	movq #10,r0
	ret
.L315:
	cbge r0,#1,.L317
	movq #20,r0
	ret
.L317:
	cble r0,#7,.L319
	movq #30,r0
	ret
.L319:
	movq #40,r0
.L311:
	; ret:one,out=0
	ret
	.even
	.globl ext
ext:
.L323:
.L327:
	movzb (r0),r1
	cbne r1,#0,.L329
	clr r0
	ret
.L329:
	movq #1,r0
.L325:
	; ret:one,out=0
	ret
	.even
	.globl usub
usub:
.L333:
.L337:
	sub r1,r0
	movl r0,r0
	cbne r0,#0,.L339
	clr r0
	ret
.L339:
	movq #1,r0
.L335:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	sub #8,sp
.L343:
.L347:
	clr r0
	movb r0,6(sp)
	movq #9,r0
	movb r0,7(sp)
	clr r1
	lea g,r0
	call ld
	cbne r0,#0,.L351
	movq #1,r1
	lea g,r0
	call ld
	cbne r0,#1,.L351
	movq #2,r1
	lea g,r0
	call ld
	cbne r0,#1,.L351
	movq #3,r1
	lea g,r0
	call ld
	cbeq r0,#0,.L349
.L351:
	movq #2,r0
	br .L345
.L349:
	clr r1
	lea g,r0
	call ldneg
	cbne r0,#0,.L355
	movq #1,r1
	lea g,r0
	call ldneg
	cbne r0,#1,.L355
	movq #2,r1
	lea g,r0
	call ldneg
	cbeq r0,#-1,.L353
.L355:
	movq #3,r0
	br .L345
.L353:
	clr r1
	clr r0
	call sh
	cbne r0,#0,.L359
	clr r1
	movq #-4,r0
	call sh
	cbne r0,#-1,.L359
	clr r1
	movq #4,r0
	call sh
	cbne r0,#1,.L359
	movq #63,r1
	movq #1,r0
	call sh
	cbne r0,#-1,.L359
	movq #1,r1
	movq #1,r0
	call sh
	cbeq r0,#1,.L357
.L359:
	movq #4,r0
	br .L345
.L357:
	clr r1
	clr r0
	call shr
	cbne r0,#0,.L363
	clr r1
	movq #8,r0
	call shr
	cbne r0,#1,.L363
	movq #4,r1
	movq #8,r0
	call shr
	cbne r0,#0,.L363
	movq #3,r1
	movq #8,r0
	call shr
	cbeq r0,#1,.L361
.L363:
	movq #5,r0
	br .L345
.L361:
	movq #4,r1
	movq #4,r0
	call three
	cbne r0,#0,.L367
	movq #4,r1
	movq #3,r0
	call three
	cbne r0,#-1,.L367
	movq #4,r1
	movq #5,r0
	call three
	cbeq r0,#1,.L365
.L367:
	movq #6,r0
	br .L345
.L365:
	movq #1,r0
	call chain
	cbne r0,#10,.L371
	clr r0
	call chain
	cbne r0,#20,.L371
	movq #8,r0
	call chain
	cbne r0,#30,.L371
	movq #5,r0
	call chain
	cbeq r0,#40,.L369
.L371:
	movq #7,r0
	br .L345
.L369:
	lea 6(sp),r0
	call ext
	cbne r0,#0,.L375
	lea 7(sp),r0
	call ext
	cbeq r0,#1,.L373
.L375:
	movq #8,r0
	br .L345
.L373:
	movq #5,r1
	movq #5,r0
	call usub
	cbne r0,#0,.L379
	movq #4,r1
	movq #5,r0
	call usub
	cbne r0,#1,.L379
	movq #1,r1
	clr r0
	call usub
	cbeq r0,#1,.L377
.L379:
	movq #9,r0
	br .L345
.L377:
	movq #1,r0
.L345:
	add #8,sp
	; ret:one,out=0
	ret
