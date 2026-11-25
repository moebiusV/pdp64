	.text
	.even
	.globl chase
chase:
.L251:
.L255:
	movq (r0),r0
	movq (r0),r0
	movq (r0),r0
	movq (r0),r0
	; ret:one,out=0
	ret
	.even
	.globl walk
walk:
.L259:
.L263:
	cbeq r1,#0,.Lppw0
.L260:
	movq (r0),r0
.L265:
	sob r1,.L260
.Lppw0:
	movq 8(r0),r0
	; ret:one,out=0
	ret
	.even
	.globl two
two:
.L271:
.L275:
	movq (r0),r2
	movzb 16(r2),r3
	cbeq r3,#102,.L277
	movq #-1,r0
	ret
.L277:
	movq (r0),r0
	movq (r0),r0
	movzb 16(r0),r2
	cmp r1,r2
	set gt,r1
.L281:
	movq 8(r0),r0
	add r1,r0
.L273:
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
	sub #136,sp
.L285:
.L289:
	clr r8
	movq #42,r0
	movq r0,32(sp)
	lea 32(sp),r0
	movq r0,24(sp)
	clr 112(sp)
	movq #7,r0
	movq r0,120(sp)
	movq #3,r0
	movb r0,128(sp)
	clr r0
	movb r0,129(sp)
	movb r0,130(sp)
	movb r0,131(sp)
	movb r0,132(sp)
	movb r0,133(sp)
	movb r0,134(sp)
	movb r0,135(sp)
	lea 112(sp),r0
	movq r0,88(sp)
	movq #6,r0
	movq r0,96(sp)
	movq #102,r0
	movb r0,104(sp)
	clr r0
	movb r0,105(sp)
	movb r0,106(sp)
	movb r0,107(sp)
	movb r0,108(sp)
	movb r0,109(sp)
	movb r0,110(sp)
	movb r0,111(sp)
	lea 88(sp),r0
	movq r0,64(sp)
	movq #5,r0
	movq r0,72(sp)
	movq #1,r0
	movb r0,80(sp)
	clr r0
	movb r0,81(sp)
	movb r0,82(sp)
	movb r0,83(sp)
	movb r0,84(sp)
	movb r0,85(sp)
	movb r0,86(sp)
	movb r0,87(sp)
	lea 64(sp),r0
	movq r0,40(sp)
	movq #4,r0
	movq r0,48(sp)
	clr r0
	movb r0,56(sp)
	movb r0,57(sp)
	movb r0,58(sp)
	movb r0,59(sp)
	movb r0,60(sp)
	movb r0,61(sp)
	movb r0,62(sp)
	movb r0,63(sp)
	lea 24(sp),r0
	movq r0,16(sp)
	lea 16(sp),r0
	movq r0,(sp)
	movq r0,8(sp)
	movcall sp,r0,chase
	cbeq r0,#42,.L291
	bis #1,r8
.L291:
	lea 40(sp),r0
	movq #3,r1
	call walk
	cbne r0,#7,.L295
	lea 40(sp),r0
	movq #1,r1
	call walk
	cbeq r0,#5,.L293
.L295:
	bis #2,r8
.L293:
	lea 64(sp),r0
	clr r1
	call two
	cbne r0,#7,.L299
	lea 64(sp),r0
	movq #9,r1
	call two
	cbne r0,#8,.L299
	lea 40(sp),r0
	clr r1
	call two
	cbeq r0,#-1,.L297
.L299:
	bis #4,r8
.L297:
	movl r8,r0
	add #136,sp
	popret r8
	; ret:one,out=0
