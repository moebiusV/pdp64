	.text
	.even
	.globl k_q8dot
k_q8dot:
.L255:
	movq r0,r3
.L259:
	clr r0
	clr r4
	br .L265
.L256:
	movb (r3)(r4),r5
	movb (r1)(r4),r7
	mul r7,r5
	add r5,r0
	inc r4
.L265:
	cblt r4,r2,.L256
	; ret:one,out=0
	ret
	.even
	.globl k_q4dot
k_q4dot:
.L269:
	movq r0,r3
.L273:
	clr r0
	clr r4
	br .L279
.L270:
	movzb (r3)(r4),r5
	and #15,r5
	add #-8,r5
	movb (r1)(r4),r7
	mul r7,r5
	add r5,r0
	movq r4,r5
	add r2,r5
	movb (r1)(r5),r7
	movzb (r3)(r4),r5
	sar #4,r5
	add #-8,r5
	mul r7,r5
	add r5,r0
	inc r4
.L279:
	cblt r4,r2,.L270
	; ret:one,out=0
	ret
	.text
	.align 4
.L289:
	.long 0
	.align 4
.L297:
	.long 925353388
	.align 4
.L299:
	.long 1065353216
	.text
	.even
	.globl k_rmsnorm
k_rmsnorm:
	pushm #3840
.L283:
	movq r0,r11
	mov2 r1,r10,r2,r9
	movq r3,r8
.L287:
	movl .L289,r0
	clr r1
	br .L295
.L284:
	movl (r10)(r1*4),r2
	fmul32 r2,r2
	fadd32 r2,r0
	inc r1
.L295:
	cblt r1,r8,.L284
	fcvtls r8,r1
	fdiv32 r1,r0
	movl .L297,r1
	fadd32 r1,r0
	call sqrtf
	movl .L299,r1
	fdiv32 r0,r1
	movq r1,r0
	clr r1
	br .L305
.L286:
	movl (r10)(r1*4),r2
	movq r0,r3
	fmul32 r2,r3
	movl (r9)(r1*4),r2
	fmul32 r2,r3
	movl r3,(r11)(r1*4)
	inc r1
.L305:
	cblt r1,r8,.L286
	popmret #3840
	; ret:one,out=0
	.text
	.align 4
.L315:
	.long 0
	.text
	.even
	.globl k_softmax
k_softmax:
	pushm #36608
.L309:
	mov2 r0,r9,r1,r8
.L313:
	movl (r9),r11
	movl .L315,r10
	movq #1,r1
	br .L321
.L310:
	movl (r9)(r1*4),r0
	fcmp32 r0,r11
	ble .L317
	movq r0,r11
.L317:
	inc r1
.L321:
	cblt r1,r8,.L310
	clr r15
	br .L329
.L312:
	movl (r9)(r15*4),r0
	fsub32 r11,r0
	call expf
	movl r0,(r9)(r15*4)
	movl (r9)(r15*4),r0
	fadd32 r0,r10
	inc r15
.L329:
	cblt r15,r8,.L312
	clr r0
	br .L335
.L314:
	movl (r9)(r0*4),r2
	fdiv32 r10,r2
	movl r2,(r9)(r0*4)
	inc r0
.L335:
	cblt r0,r8,.L314
	popmret #36608
	; ret:one,out=0
	.even
	.globl k_blend
k_blend:
.L339:
.L343:
	clr r4
	br .L349
.L340:
	movzb (r2)(r4),r16
	movzb (r0)(r4),r7
	movq #255,r5
	sub r16,r5
	mul r5,r7
	movzb (r1)(r4),r5
	mul r16,r5
	add r7,r5
	lea 128(r5),r5
	movq r5,r6
	movzl r5,r5
	shr #8,r5
	add r5,r6
	movzl r6,r6
	shr #8,r6
	movb r6,(r0)(r4)
	inc r4
.L349:
	cblt r4,r3,.L340
	; ret:one,out=0
	ret
	.even
	.globl k_mix16
k_mix16:
.L353:
.L357:
	clr r6
	br .L363
.L354:
	movw (r1)(r6*2),r4
	movw (r2)(r6*2),r7
	add r7,r4
	cble r4,#32767,.L365
	movq #32767,r4
	br .L367
.L365:
	cbge r4,#-32768,.L367
	movq #-32768,r4
.L367:
	movw r4,(r0)(r6*2)
	inc r6
.L363:
	cblt r6,r3,.L354
	; ret:one,out=0
	ret
	.even
	.globl k_vtx
k_vtx:
.L375:
.L379:
	clr r6
	br .L385
.L376:
	movq 8(sp),r7
	movl (r7),r16
	movl (r3)(r6*4),r7
	fmul32 r7,r16
	movq 8(sp),r7
	movl 4(r7),r7
	movl (r4)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 8(r7),r7
	movl (r5)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 12(r7),r7
	fadd32 r7,r16
	movl r16,(r0)(r6*4)
	movq 8(sp),r7
	movl 16(r7),r16
	movl (r3)(r6*4),r7
	fmul32 r7,r16
	movq 8(sp),r7
	movl 20(r7),r7
	movl (r4)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 24(r7),r7
	movl (r5)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 28(r7),r7
	fadd32 r7,r16
	movl r16,(r1)(r6*4)
	movq 8(sp),r7
	movl 32(r7),r16
	movl (r3)(r6*4),r7
	fmul32 r7,r16
	movq 8(sp),r7
	movl 36(r7),r7
	movl (r4)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 40(r7),r7
	movl (r5)(r6*4),r17
	fmul32 r17,r7
	fadd32 r7,r16
	movq 8(sp),r7
	movl 44(r7),r7
	fadd32 r7,r16
	movl r16,(r2)(r6*4)
	inc r6
.L385:
	movl 16(sp),r7
	cblt r6,r7,.L376
	; ret:one,out=0
	ret
