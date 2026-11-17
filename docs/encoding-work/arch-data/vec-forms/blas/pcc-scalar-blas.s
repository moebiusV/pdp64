	.text
	.align 8
.L257:
	.long 0
	.long 0
	.text
	.even
	.globl k_ddot
k_ddot:
.L251:
	movq r0,r3
.L255:
	movq .L257,r0
	clr r4
	br .L263
.L252:
	movq (r3)(r4*8),r5
	fmul (r1)(r4*8),r5
	fadd r5,r0
	inc r4
.L263:
	cblt r4,r2,.L252
	; ret:one,out=0
	ret
	.even
	.globl k_daxpy
k_daxpy:
.L267:
.L271:
	clr r4
	br .L277
.L268:
	movq (r0)(r4*8),r6
	movq r2,r5
	fmul (r1)(r4*8),r5
	fadd r5,r6
	movq r6,(r0)(r4*8)
	inc r4
.L277:
	cblt r4,r3,.L268
	; ret:one,out=0
	ret
	.even
	.globl k_dscal
k_dscal:
.L281:
.L285:
	clr r3
	br .L291
.L282:
	movq (r0)(r3*8),r5
	fmul r1,r5
	movq r5,(r0)(r3*8)
	inc r3
.L291:
	cblt r3,r2,.L282
	; ret:one,out=0
	ret
	.text
	.align 8
.L307:
	.long 0
	.long 0
	.text
	.even
	.globl k_dgemv_n
k_dgemv_n:
.L295:
.L299:
	clr r17
	br .L305
.L298:
	movq .L307,r6
	clr r5
	br .L313
.L296:
	movq r17,r7
	mul r4,r7
	add r5,r7
	movq (r0)(r7*8),r7
	fmul (r1)(r5*8),r7
	fadd r7,r6
	inc r5
.L313:
	cblt r5,r4,.L296
	movq r6,(r2)(r17*8)
	inc r17
.L305:
	cblt r17,r3,.L298
	; ret:one,out=0
	ret
	.text
	.align 8
.L329:
	.long 0
	.long 0
	.text
	.even
	.globl k_dgemv_t
k_dgemv_t:
.L317:
.L321:
	clr r5
	br .L327
.L318:
	movq .L329,r7
	movq r7,(r2)(r5*8)
	inc r5
.L327:
	cblt r5,r4,.L318
	clr r17
	br .L335
.L322:
	clr r5
	br .L341
.L320:
	movq r17,r6
	mul r4,r6
	add r5,r6
	movq (r0)(r6*8),r16
	fmul (r1)(r17*8),r16
	movq (r2)(r5*8),r7
	fadd r16,r7
	movq r7,(r2)(r5*8)
	inc r5
.L341:
	cblt r5,r4,.L320
	inc r17
.L335:
	cblt r17,r3,.L322
	; ret:one,out=0
	ret
	.even
	.globl k_dger
k_dger:
.L345:
.L349:
	clr r17
	br .L355
.L348:
	clr r5
	br .L361
.L346:
	movq r17,r6
	mul r4,r6
	add r5,r6
	shl #3,r6
	movq r0,r18
	add r6,r18
	movq (r18),r6
	movq (r1)(r17*8),r7
	fmul (r2)(r5*8),r7
	fadd r7,r6
	movq r6,(r18)
	inc r5
.L361:
	cblt r5,r4,.L346
	inc r17
.L355:
	cblt r17,r3,.L348
	; ret:one,out=0
	ret
	.text
	.align 4
.L383:
	.long 0
	.text
	.even
	.globl k_sgemm_nt
k_sgemm_nt:
.L365:
.L369:
	clr r18
	br .L375
.L370:
	clr r17
	br .L381
.L368:
	movl .L383,r7
	clr r6
	br .L389
.L366:
	movq r18,r16
	mul r4,r16
	add r6,r16
	movl (r0)(r16*4),r16
	movq r17,r19
	mul r4,r19
	add r6,r19
	movl (r1)(r19*4),r19
	fmul32 r19,r16
	fadd32 r16,r7
	inc r6
.L389:
	cblt r6,r4,.L366
	movq r18,r6
	mul r5,r6
	add r17,r6
	movl r7,(r2)(r6*4)
	inc r17
.L381:
	cblt r17,r5,.L368
	inc r18
.L375:
	cblt r18,r3,.L370
	; ret:one,out=0
	ret
