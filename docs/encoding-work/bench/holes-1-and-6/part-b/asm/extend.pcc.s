	.data
	.globl ub
ub:
	.byte 128
	.byte 255
	.globl sb
sb:
	.byte 128
	.byte 255
	.even
	.globl ss
ss:
	.word 32768
	.word 65535
	.even
	.globl us
us:
	.word 32768
	.word 65535
	.align 4
	.globl is
is:
	.long 2147483648
	.long 4294967295
	.align 4
	.globl un
un:
	.long 2147483648
	.long 4294967295
	.text
	.even
fail:
.L263:
.L267:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	sub #16,sp
.L271:
.L275:
	movq #-1,r0
	movl r0,12(sp)
	movl r0,8(sp)
	movb r0,7(sp)
	movq #255,r0
	movb r0,6(sp)
	movq #-2,r0
	movw r0,4(sp)
	movzb ub,r0
	cbeq r0,#128,.L277
	movq #2,r0
	call fail
	br .L273
.L277:
	movb sb,r0
	cbeq r0,#-128,.L279
	movq #3,r0
	call fail
	br .L273
.L279:
	movw ss,r0
	cbeq r0,#-32768,.L281
	movq #4,r0
	call fail
	br .L273
.L281:
	movzw us,r0
	cmp r0,#32768
	beq .L283
	movq #5,r0
	call fail
	br .L273
.L283:
	movl is,r0
	cmp r0,#-2147483648
	beq .L285
	movq #6,r0
	call fail
	br .L273
.L285:
	movzl un,r0
	cmp r0,=2147483648
	beq .L287
	movq #7,r0
	call fail
	br .L273
.L287:
	movb 7(sp),r0
	cbeq r0,#-1,.L289
	movq #8,r0
	call fail
	br .L273
.L289:
	movb 7(sp),r0
	cbeq r0,#-1,.L291
	movq #9,r0
	call fail
	br .L273
.L291:
	movl 12(sp),r0
	cbeq r0,#-1,.L293
	movq #10,r0
	call fail
	br .L273
.L293:
	movzl 8(sp),r0
	cmp r0,=4294967295
	beq .L295
	movq #11,r0
	call fail
	br .L273
.L295:
	movzb 12(sp),r0
	cbeq r0,#255,.L297
	movq #12,r0
	call fail
	br .L273
.L297:
	movzw 12(sp),r0
	cmp r0,#65535
	beq .L299
	movq #13,r0
	call fail
	br .L273
.L299:
	movl 12(sp),r0
	shl #16,r0
	add #32768,r0
	movw r0,r0
	cbne r0,#0,.L301
	movq #14,r0
	call fail
	br .L273
.L301:
	movl 12(sp),r0
	cblt r0,#0,.L319
	movq #23,r0
	call fail
	br .L273
.L319:
	movzb 6(sp),r0
	cbgt r0,#0,.L321
	movq #24,r0
	call fail
	br .L273
.L321:
	movb 7(sp),r0
	cblt r0,#0,.L323
	movq #25,r0
	call fail
	br .L273
.L323:
	movl 8(sp),r0
	cbne r0,#0,.L325
	movq #26,r0
	call fail
	br .L273
.L325:
	movl is,r1
	movl is+4,r0
	cblt r1,r0,.L327
	movq #27,r0
	call fail
	br .L273
.L327:
	movl un,r1
	movl un+4,r0
	cbcs r1,r0,.L331
	movq #28,r0
	call fail
	br .L273
.L331:
	movl un,r0
	movzl r0,r0
	shr #31,r0
	cbeq r0,#1,.L335
	movq #30,r0
	call fail
	br .L273
.L335:
	movl is,r0
	sar #31,r0
	cbeq r0,#-1,.L337
	movq #31,r0
	call fail
	br .L273
.L337:
	movl 12(sp),r1
	movq #2,r0
	div r1,r0,r1
	cbeq r1,#0,.L339
	movq #32,r0
	call fail
	br .L273
.L339:
	movl 8(sp),r0
	movzl r0,r0
	shr #1,r0
	cmp r0,#2147483647
	beq .L345
	movq #34,r0
	call fail
	br .L273
.L345:
	movw 4(sp),r0
	mul r0,r0
	cbeq r0,#4,.L347
	movq #35,r0
	call fail
	br .L273
.L347:
	movw 4(sp),r0
	sub #32767,r0
	movw r0,r0
	cbeq r0,#32767,.L349
	movq #36,r0
	call fail
	br .L273
.L349:
	movzl 12(sp),r0
	cmp r0,=4294967295
	beq .L351
	movq #37,r0
	call fail
	br .L273
.L351:
	movzb 7(sp),r0
	cbeq r0,#255,.L353
	movq #38,r0
	call fail
	br .L273
.L353:
	movb 6(sp),r0
	cbeq r0,#-1,.L355
	movq #39,r0
	call fail
	br .L273
.L355:
	movq #1,r0
.L273:
	add #16,sp
	; ret:one,out=0
	ret
