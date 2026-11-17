	.text
	.even
	.globl k_prep8
k_prep8:
.L255:
.L259:
	clr r3
	br .L265
.L256:
	movzb (r1)(r3),r5
	shl #4,r5
	movw r5,(r0)(r3*2)
	inc r3
.L265:
	cblt r3,r2,.L256
	; ret:one,out=0
	ret
	.even
	.globl k_put8h
k_put8h:
.L269:
.L273:
	clr r7
	br .L279
.L270:
	movb (r3),r4
	lea -3(r7),r5
	movzb (r1)(r5),r6
	mul r6,r4
	movb 1(r3),r5
	lea -2(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	movb 2(r3),r5
	lea -1(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	movb 3(r3),r5
	movzb (r1)(r7),r16
	mul r16,r5
	add r5,r4
	movb 4(r3),r5
	lea 1(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	movb 5(r3),r5
	lea 2(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	movb 6(r3),r5
	lea 3(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	movb 7(r3),r5
	lea 4(r7),r6
	movzb (r1)(r6),r16
	mul r16,r5
	add r5,r4
	lea 32(r4),r4
	sar #6,r4
	cbge r4,#0,.L281
	clr r4
	br .L283
.L281:
	cble r4,#255,.L283
	movq #255,r4
.L283:
	movb r4,(r0)(r7)
	inc r7
.L279:
	cblt r7,r2,.L270
	; ret:one,out=0
	ret
	.even
	.globl k_dctop_sum
k_dctop_sum:
.L291:
	movq r0,r2
.L295:
	movq r1,r0
	asr r0
	clr r3
	br .L301
.L292:
	movzb (r2)(r3),r5
	add r5,r0
	inc r3
.L301:
	cblt r3,r1,.L292
	clr r3
	br .L305
.L294:
	movq r1,r2
	and #1,r2
	bne .L303
	asr r1
	inc r3
.L305:
	cblt r3,#32,.L294
.L303:
	movzl r0,r0
	shr r3,r0
	movl r0,r0
	; ret:one,out=0
	ret
	.even
	.globl k_dctop_fill
k_dctop_fill:
.L311:
.L315:
	clr r7
	br .L321
.L314:
	clr r5
	br .L327
.L312:
	movb r4,(r0)(r5)
	inc r5
.L327:
	cblt r5,r2,.L312
	add r1,r0
	inc r7
.L321:
	cblt r7,r3,.L314
	; ret:one,out=0
	ret
	.even
	.globl k_fmac
k_fmac:
.L331:
.L335:
	clr r4
	br .L341
.L332:
	movl (r0)(r4*4),r6
	movl (r1)(r4*4),r5
	fmul32 r2,r5
	fadd32 r5,r6
	movl r6,(r0)(r4*4)
	inc r4
.L341:
	cblt r4,r3,.L332
	; ret:one,out=0
	ret
	.even
	.globl k_sad
k_sad:
	pushm #251694848
.L345:
	movq r0,r24
	movq r1,r15
	movq r2,r11
	movq r3,r10
	movq r4,r9
	movq r5,r8
.L349:
	clr r26
	clr r25
	br .L355
.L348:
	clr r27
	br .L361
.L346:
	movzb (r24)(r27),r0
	movzb (r11)(r27),r2
	sub r2,r0
	call abs
	add r0,r26
	inc r27
.L361:
	cblt r27,r9,.L346
	add r15,r24
	add r10,r11
	inc r25
.L355:
	cblt r25,r8,.L348
	movq r26,r0
	popm #251694848
	; ret:one,out=0
	ret
	.even
	.globl k_hist
k_hist:
.L365:
.L369:
	br .L375
.L366:
	movl (r1)(r2*4),r7
	movzb (r0)(r7),r16
	asl r16
	movzl r16,r6
	shl #3,r6
	movq 8(sp),r7
	add r6,r7
	movl (r4)(r2*4),r6
	fcvtsd r6,r17
	movq (r7),r6
	fadd r17,r6
	movq r6,(r7)
	lea 1(r16),r6
	movzl r6,r6
	shl #3,r6
	movq 8(sp),r7
	add r6,r7
	movl (r5)(r2*4),r6
	fcvtsd r6,r16
	movq (r7),r6
	fadd r16,r6
	movq r6,(r7)
	inc r2
.L375:
	cblt r2,r3,.L366
	; ret:one,out=0
	ret
	.text
	.align 4
.L385:
	.long 0
	.text
	.even
	.globl k_ssm
k_ssm:
	pushm #117477120
.L379:
	movq r0,r24
	movq r1,r15
	movq r2,r11
	movq r3,r10
	movq r4,r9
	movq r5,r8
.L383:
	movl .L385,r25
	clr r26
	br .L391
.L380:
	movl (r11)(r26*4),r1
	movq r15,r0
	fmul32 r1,r0
	call expf
	movl (r10)(r26*4),r1
	movq r15,r2
	fmul32 r1,r2
	movl (r24)(r26*4),r1
	fmul32 r0,r1
	movq r8,r0
	fmul32 r2,r0
	fadd32 r0,r1
	movl r1,(r24)(r26*4)
	movl (r9)(r26*4),r0
	fmul32 r0,r1
	fadd32 r1,r25
	inc r26
.L391:
	movl 80(sp),r0
	cblt r26,r0,.L380
	movq 72(sp),r0
	movl r25,(r0)
	popm #117477120
	; ret:one,out=0
	ret
