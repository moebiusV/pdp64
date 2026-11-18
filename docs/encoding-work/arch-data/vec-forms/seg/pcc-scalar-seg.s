	.text
	.even
	.globl k_gray
k_gray:
.L251:
.L255:
	clr r3
	br .L261
.L252:
	movzb (r1)(r3*4),r5
	mul #77,r5
	movq r3,r6
	shl #2,r6
	movl r6,r6
	inc r6
	movzb (r1)(r6),r4
	mul #150,r4
	add r4,r5
	movq r3,r4
	shl #2,r4
	movl r4,r4
	lea 2(r4),r6
	movzb (r1)(r6),r4
	mul #29,r4
	add r4,r5
	sar #8,r5
	movb r5,(r0)(r3)
	inc r3
.L261:
	cblt r3,r2,.L252
	; ret:one,out=0
	ret
	.even
	.globl k_split
k_split:
.L265:
.L269:
	clr r4
	br .L275
.L266:
	movq r4,r5
	asl r5
	movl r5,r5
	movw (r2)(r5*2),r6
	movq r4,r5
	movw r6,(r0)(r4*2)
	asl r5
	movl r5,r5
	inc r5
	movw (r2)(r5*2),r6
	movw r6,(r1)(r4*2)
	inc r4
.L275:
	cblt r4,r3,.L266
	; ret:one,out=0
	ret
	.even
	.globl k_vtxaos
k_vtxaos:
.L279:
.L283:
	clr r4
	br .L289
.L280:
	movq r4,r5
	shl #2,r5
	movl r5,r5
	movl (r1)(r5*4),r17
	movq r4,r5
	shl #2,r5
	movl r5,r5
	inc r5
	movl (r1)(r5*4),r16
	movq r4,r5
	shl #2,r5
	movl r5,r5
	add #2,r5
	movl (r1)(r5*4),r7
	movl (r2),r6
	fmul32 r17,r6
	movl 4(r2),r5
	fmul32 r16,r5
	fadd32 r5,r6
	movl 8(r2),r5
	fmul32 r7,r5
	fadd32 r5,r6
	movl 12(r2),r5
	fadd32 r5,r6
	movq r4,r5
	shl #2,r5
	movl r5,r5
	movl r6,(r0)(r5*4)
	movl 16(r2),r6
	fmul32 r17,r6
	movl 20(r2),r5
	fmul32 r16,r5
	fadd32 r5,r6
	movl 24(r2),r5
	fmul32 r7,r5
	fadd32 r5,r6
	movl 28(r2),r5
	fadd32 r5,r6
	movq r4,r5
	shl #2,r5
	movl r5,r5
	inc r5
	movl r6,(r0)(r5*4)
	movl 32(r2),r6
	fmul32 r17,r6
	movl 36(r2),r5
	fmul32 r16,r5
	fadd32 r5,r6
	movl 40(r2),r5
	fmul32 r7,r5
	fadd32 r5,r6
	movl 44(r2),r5
	fadd32 r5,r6
	movq r4,r5
	shl #2,r5
	movl r5,r5
	add #2,r5
	movl r6,(r0)(r5*4)
	movq r4,r5
	shl #2,r5
	movl r5,r5
	add #3,r5
	movl (r1)(r5*4),r6
	movq r4,r5
	shl #2,r5
	movl r5,r5
	add #3,r5
	movl r6,(r0)(r5*4)
	inc r4
.L289:
	cblt r4,r3,.L280
	; ret:one,out=0
	ret
	.even
	.globl k_cmul
k_cmul:
.L293:
.L297:
	clr r4
	br .L303
.L294:
	movq r4,r5
	asl r5
	movl r5,r5
	movl (r1)(r5*4),r6
	movq r4,r5
	asl r5
	movl r5,r5
	inc r5
	movl (r1)(r5*4),r5
	movq r4,r7
	asl r7
	movl r7,r7
	movl (r2)(r7*4),r16
	movq r4,r7
	asl r7
	movl r7,r7
	inc r7
	movl (r2)(r7*4),r18
	movq r6,r17
	fmul32 r16,r17
	movq r5,r7
	fmul32 r18,r7
	fsub32 r7,r17
	movq r4,r7
	asl r7
	movl r7,r7
	movl r17,(r0)(r7*4)
	fmul32 r18,r6
	fmul32 r16,r5
	fadd32 r5,r6
	movq r4,r5
	asl r5
	movl r5,r5
	inc r5
	movl r6,(r0)(r5*4)
	inc r4
.L303:
	cblt r4,r3,.L294
	; ret:one,out=0
	ret
