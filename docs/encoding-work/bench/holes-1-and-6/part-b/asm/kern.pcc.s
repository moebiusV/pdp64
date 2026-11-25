	.text
	.even
user_ok:
.L251:
.L255:
	cbcs r0,#4096,.L257
	cmp r1,=549755813887
	bhi .L257
	add r1,r0
	cmp r0,=549755813887
	bhi .L257
	movq #1,r0
	ret
.L257:
	clr r0
.L259:
	; ret:one,out=0
	ret
	.even
	.globl sys_null
sys_null:
.L263:
.L267:
	clr r0
	; ret:one,out=0
	ret
	.even
	.globl sys_getpid
sys_getpid:
.L271:
.L275:
	movq 24(r0),r0
	; ret:one,out=0
	ret
	.even
	.globl copyin_bytes
copyin_bytes:
	pushm #1792
.L279:
	mov2 r0,r9,r1,r0
	movq r2,r8
.L283:
	mov2 r0,r10,r8,r1
	call user_ok
	cbne r0,#0,.L285
	movq #-14,r0
	br .L281
.L285:
	clr r0
	br .L291
.L280:
	movzb (r10)(r0),r1
	movb r1,(r9)(r0)
	inc r0
.L291:
	cbcs r0,r8,.L280
	movq r8,r0
.L281:
	popmret #1792
	; ret:one,out=0
	.even
	.globl copyout_words
copyout_words:
	pushm #1792
.L295:
	mov2 r1,r9,r2,r8
.L299:
	mov2 r0,r10,r8,r1
	call user_ok
	cbeq r0,#0,.L303
	movq r8,r0
	and #7,r0
	beq .L301
.L303:
	movq #-14,r0
	br .L297
.L301:
	clr r0
	br .L309
.L296:
	movq (r9)(r0*8),r1
	movq r1,(r10)(r0*8)
	inc r0
.L309:
	movq r8,r1
	shr #3,r1
	cbcs r0,r1,.L296
	movq r8,r0
.L297:
	popmret #1792
	; ret:one,out=0
	.even
	.globl sys_dup
sys_dup:
.L315:
.L319:
	cbcs r0,#64,.L321
.L316:
	movq #-9,r0
	ret
.L321:
	lea fdtab,r1
	movq (r1)(r0*8),r1
	cbeq r1,#0,.L316
	inc (r1)
	movq 24(r1),r0
.L317:
	; ret:one,out=0
	ret
	.even
	.globl hash_lookup
hash_lookup:
.L329:
.L333:
	movq r0,r1
	mul =-7046029254386353131,r1
	shr #56,r1
	clr r3
	br .L339
.L332:
	movzl r1,r2
	shl #4,r2
	lea htab,r4
	movq (r4)(r2),r2
	cbne r2,r0,.L341
	movzl r1,r0
	shl #4,r0
	lea htab+8,r1
	movq (r1)(r0),r0
	ret
.L341:
	movzl r1,r2
	shl #4,r2
	lea htab,r4
	movq (r4)(r2),r2
	cbeq r2,#0,.L330
	inc r3
	inc r1
	movzb r1,r1
.L339:
	cblt r3,#256,.L332
.L330:
	movq #-2,r0
.L331:
	; ret:one,out=0
	ret
	.even
	.globl checksum
checksum:
.L347:
.L351:
	clr r2
	br .L353
.L348:
	movzb (r0),r3
	movzb 1(r0),r4
	shl #8,r4
	bis r4,r3
	add r3,r2
	add #2,r0
	add #-2,r1
.L353:
	cbhi r1,#1,.L348
	cbeq r1,#0,.L359
	movzb (r0),r1
	add r1,r2
	br .L359
.L350:
	movzw r2,r0
	shr #16,r2
	add r2,r0
	movq r0,r2
.L359:
	movq r2,r0
	shr #16,r0
	cbne r0,#0,.L350
	com r2
	movzw r2,r0
	; ret:one,out=0
	ret
	.even
	.globl crc32
crc32:
.L365:
.L369:
	movq #-1,r2
	clr r5
	br .L375
.L368:
	movzb (r0)(r5),r3
	xor r3,r2
	clr r3
	br .L381
.L366:
	movzl r2,r4
	shr #1,r4
	and #1,r2
	neg r2
	and #-306674912,r2
	xor r2,r4
	movq r4,r2
	inc r3
.L381:
	cblt r3,#8,.L366
	inc r5
.L375:
	cbcs r5,r1,.L368
	com r2
	movzl r2,r0
	; ret:one,out=0
	ret
	.even
	.globl chacha_block
chacha_block:
	sub #64,sp
.L385:
.L389:
	clr r1
	br .L395
.L386:
	movl (r0)(r1*4),r3
	movl r3,(sp)(r1*4)
	inc r1
.L395:
	cblt r1,#16,.L386
	clr r1
	br .L401
.L388:
	movl (sp),r2
	movl 16(sp),r3
	add r3,r2
	movl r2,(sp)
	movl 48(sp),r2
	movl (sp),r3
	xor r3,r2
	movl r2,48(sp)
	movl 48(sp),r2
	rori32 r2,#16,r2
	movl r2,48(sp)
	movl 32(sp),r2
	movl 48(sp),r3
	add r3,r2
	movl r2,32(sp)
	movl 16(sp),r2
	movl 32(sp),r3
	xor r3,r2
	movl r2,16(sp)
	movl 16(sp),r2
	rori32 r2,#20,r2
	movl r2,16(sp)
	movl (sp),r2
	movl 16(sp),r3
	add r3,r2
	movl r2,(sp)
	movl 48(sp),r2
	movl (sp),r3
	xor r3,r2
	movl r2,48(sp)
	movl 48(sp),r2
	rori32 r2,#24,r2
	movl r2,48(sp)
	movl 32(sp),r2
	movl 48(sp),r3
	add r3,r2
	movl r2,32(sp)
	movl 16(sp),r2
	movl 32(sp),r3
	xor r3,r2
	movl r2,16(sp)
	movl 16(sp),r2
	rori32 r2,#25,r2
	movl r2,16(sp)
	movl 4(sp),r2
	movl 20(sp),r3
	add r3,r2
	movl r2,4(sp)
	movl 52(sp),r2
	movl 4(sp),r3
	xor r3,r2
	movl r2,52(sp)
	movl 52(sp),r2
	rori32 r2,#16,r2
	movl r2,52(sp)
	movl 36(sp),r2
	movl 52(sp),r3
	add r3,r2
	movl r2,36(sp)
	movl 20(sp),r2
	movl 36(sp),r3
	xor r3,r2
	movl r2,20(sp)
	movl 20(sp),r2
	rori32 r2,#20,r2
	movl r2,20(sp)
	movl 4(sp),r2
	movl 20(sp),r3
	add r3,r2
	movl r2,4(sp)
	movl 52(sp),r2
	movl 4(sp),r3
	xor r3,r2
	movl r2,52(sp)
	movl 52(sp),r2
	rori32 r2,#24,r2
	movl r2,52(sp)
	movl 36(sp),r2
	movl 52(sp),r3
	add r3,r2
	movl r2,36(sp)
	movl 20(sp),r2
	movl 36(sp),r3
	xor r3,r2
	movl r2,20(sp)
	movl 20(sp),r2
	rori32 r2,#25,r2
	movl r2,20(sp)
	movl 8(sp),r2
	movl 24(sp),r3
	add r3,r2
	movl r2,8(sp)
	movl 56(sp),r2
	movl 8(sp),r3
	xor r3,r2
	movl r2,56(sp)
	movl 56(sp),r2
	rori32 r2,#16,r2
	movl r2,56(sp)
	movl 40(sp),r2
	movl 56(sp),r3
	add r3,r2
	movl r2,40(sp)
	movl 24(sp),r2
	movl 40(sp),r3
	xor r3,r2
	movl r2,24(sp)
	movl 24(sp),r2
	rori32 r2,#20,r2
	movl r2,24(sp)
	movl 8(sp),r2
	movl 24(sp),r3
	add r3,r2
	movl r2,8(sp)
	movl 56(sp),r2
	movl 8(sp),r3
	xor r3,r2
	movl r2,56(sp)
	movl 56(sp),r2
	rori32 r2,#24,r2
	movl r2,56(sp)
	movl 40(sp),r2
	movl 56(sp),r3
	add r3,r2
	movl r2,40(sp)
	movl 24(sp),r2
	movl 40(sp),r3
	xor r3,r2
	movl r2,24(sp)
	movl 24(sp),r2
	rori32 r2,#25,r2
	movl r2,24(sp)
	movl 12(sp),r2
	movl 28(sp),r3
	add r3,r2
	movl r2,12(sp)
	movl 60(sp),r2
	movl 12(sp),r3
	xor r3,r2
	movl r2,60(sp)
	movl 60(sp),r2
	rori32 r2,#16,r2
	movl r2,60(sp)
	movl 44(sp),r2
	movl 60(sp),r3
	add r3,r2
	movl r2,44(sp)
	movl 28(sp),r2
	movl 44(sp),r3
	xor r3,r2
	movl r2,28(sp)
	movl 28(sp),r2
	rori32 r2,#20,r2
	movl r2,28(sp)
	movl 12(sp),r2
	movl 28(sp),r3
	add r3,r2
	movl r2,12(sp)
	movl 60(sp),r2
	movl 12(sp),r3
	xor r3,r2
	movl r2,60(sp)
	movl 60(sp),r2
	rori32 r2,#24,r2
	movl r2,60(sp)
	movl 44(sp),r2
	movl 60(sp),r3
	add r3,r2
	movl r2,44(sp)
	movl 28(sp),r2
	movl 44(sp),r3
	xor r3,r2
	movl r2,28(sp)
	movl 28(sp),r2
	rori32 r2,#25,r2
	movl r2,28(sp)
	movl (sp),r2
	movl 20(sp),r3
	add r3,r2
	movl r2,(sp)
	movl 60(sp),r2
	movl (sp),r3
	xor r3,r2
	movl r2,60(sp)
	movl 60(sp),r2
	rori32 r2,#16,r2
	movl r2,60(sp)
	movl 40(sp),r2
	movl 60(sp),r3
	add r3,r2
	movl r2,40(sp)
	movl 20(sp),r2
	movl 40(sp),r3
	xor r3,r2
	movl r2,20(sp)
	movl 20(sp),r2
	rori32 r2,#20,r2
	movl r2,20(sp)
	movl (sp),r2
	movl 20(sp),r3
	add r3,r2
	movl r2,(sp)
	movl 60(sp),r2
	movl (sp),r3
	xor r3,r2
	movl r2,60(sp)
	movl 60(sp),r2
	rori32 r2,#24,r2
	movl r2,60(sp)
	movl 40(sp),r2
	movl 60(sp),r3
	add r3,r2
	movl r2,40(sp)
	movl 20(sp),r2
	movl 40(sp),r3
	xor r3,r2
	movl r2,20(sp)
	movl 20(sp),r2
	rori32 r2,#25,r2
	movl r2,20(sp)
	movl 4(sp),r2
	movl 24(sp),r3
	add r3,r2
	movl r2,4(sp)
	movl 48(sp),r2
	movl 4(sp),r3
	xor r3,r2
	movl r2,48(sp)
	movl 48(sp),r2
	rori32 r2,#16,r2
	movl r2,48(sp)
	movl 44(sp),r2
	movl 48(sp),r3
	add r3,r2
	movl r2,44(sp)
	movl 24(sp),r2
	movl 44(sp),r3
	xor r3,r2
	movl r2,24(sp)
	movl 24(sp),r2
	rori32 r2,#20,r2
	movl r2,24(sp)
	movl 4(sp),r2
	movl 24(sp),r3
	add r3,r2
	movl r2,4(sp)
	movl 48(sp),r2
	movl 4(sp),r3
	xor r3,r2
	movl r2,48(sp)
	movl 48(sp),r2
	rori32 r2,#24,r2
	movl r2,48(sp)
	movl 44(sp),r2
	movl 48(sp),r3
	add r3,r2
	movl r2,44(sp)
	movl 24(sp),r2
	movl 44(sp),r3
	xor r3,r2
	movl r2,24(sp)
	movl 24(sp),r2
	rori32 r2,#25,r2
	movl r2,24(sp)
	movl 8(sp),r2
	movl 28(sp),r3
	add r3,r2
	movl r2,8(sp)
	movl 52(sp),r2
	movl 8(sp),r3
	xor r3,r2
	movl r2,52(sp)
	movl 52(sp),r2
	rori32 r2,#16,r2
	movl r2,52(sp)
	movl 32(sp),r2
	movl 52(sp),r3
	add r3,r2
	movl r2,32(sp)
	movl 28(sp),r2
	movl 32(sp),r3
	xor r3,r2
	movl r2,28(sp)
	movl 28(sp),r2
	rori32 r2,#20,r2
	movl r2,28(sp)
	movl 8(sp),r2
	movl 28(sp),r3
	add r3,r2
	movl r2,8(sp)
	movl 52(sp),r2
	movl 8(sp),r3
	xor r3,r2
	movl r2,52(sp)
	movl 52(sp),r2
	rori32 r2,#24,r2
	movl r2,52(sp)
	movl 32(sp),r2
	movl 52(sp),r3
	add r3,r2
	movl r2,32(sp)
	movl 28(sp),r2
	movl 32(sp),r3
	xor r3,r2
	movl r2,28(sp)
	movl 28(sp),r2
	rori32 r2,#25,r2
	movl r2,28(sp)
	movl 12(sp),r2
	movl 16(sp),r3
	add r3,r2
	movl r2,12(sp)
	movl 56(sp),r2
	movl 12(sp),r3
	xor r3,r2
	movl r2,56(sp)
	movl 56(sp),r2
	rori32 r2,#16,r2
	movl r2,56(sp)
	movl 36(sp),r2
	movl 56(sp),r3
	add r3,r2
	movl r2,36(sp)
	movl 16(sp),r2
	movl 36(sp),r3
	xor r3,r2
	movl r2,16(sp)
	movl 16(sp),r2
	rori32 r2,#20,r2
	movl r2,16(sp)
	movl 12(sp),r2
	movl 16(sp),r3
	add r3,r2
	movl r2,12(sp)
	movl 56(sp),r2
	movl 12(sp),r3
	xor r3,r2
	movl r2,56(sp)
	movl 56(sp),r2
	rori32 r2,#24,r2
	movl r2,56(sp)
	movl 36(sp),r2
	movl 56(sp),r3
	add r3,r2
	movl r2,36(sp)
	movl 16(sp),r2
	movl 36(sp),r3
	xor r3,r2
	movl r2,16(sp)
	movl 16(sp),r2
	rori32 r2,#25,r2
	movl r2,16(sp)
	inc r1
.L401:
	cblt r1,#10,.L388
	clr r3
	clr r1
	br .L407
.L390:
	movl (sp)(r1*4),r2
	movl (r0)(r1*4),r4
	add r4,r2
	add r3,r2
	movl r2,r3
	inc r1
.L407:
	cblt r1,#16,.L390
	movzl r3,r0
	add #64,sp
	; ret:one,out=0
	ret
	.even
	.globl dispatch
dispatch:
.L411:
	movq r0,r4
	mov2 r1,r0,r2,r1
	movq r3,r2
.L415:
	cbeq r4,#0,.L421
	cbeq r4,#1,.L423
	cbeq r4,#2,.L425
	cbeq r4,#3,.L427
	cbeq r4,#4,.L429
	cbeq r4,#5,.L431
	movq #-38,r0
	ret
.L421:
	jmp sys_null
.L423:
	jmp sys_getpid
.L425:
	jmp sys_dup
.L427:
	jmp hash_lookup
.L429:
	jmp checksum
.L431:
	call copyin_bytes
.L413:
	; ret:one,out=0
	ret
	.comm fdtab,512
	.comm htab,4096
