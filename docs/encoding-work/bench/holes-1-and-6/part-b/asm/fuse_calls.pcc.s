	.text
	.even
	.globl id3
id3:
.L251:
.L255:
	mul #100,r0
	mul #10,r1
	add r1,r0
	add r2,r0
	; ret:one,out=0
	ret
	.even
	.globl swap2
swap2:
.L259:
	mov2 r0,r3,r1,r0
.L263:
	movq r3,r2
	sub r0,r2
	movq r3,r1
	; ret:one,out=0
	jmp id3
	.even
	.globl keep
keep:
	pushm #3840
.L267:
	mov2 r0,r10,r1,r9
	movq r2,r8
.L271:
	call id3
	movq r0,r11
	mov2 r9,r2,r10,r1
	movcall r8,r0,id3
	sub r0,r11
	movq r11,r0
	popmret #3840
	; ret:one,out=0
	.even
	.globl many
many:
.L275:
.L279:
	asl r1
	add r1,r0
	mul #3,r2
	add r2,r0
	shl #2,r3
	add r3,r0
	lea (r4)(r4*4),r4
	add r4,r0
	mul #6,r5
	add r5,r0
	movq 8(sp),r1
	mul #7,r1
	add r1,r0
	movq 16(sp),r1
	shl #3,r1
	add r1,r0
	; ret:one,out=0
	ret
	.even
	.globl chain
chain:
	sub #16,sp
.L283:
	movq r0,r6
	movq r2,r0
.L287:
	movq r0,8(sp)
	movq r1,(sp)
	movq r6,r5
	movq r0,r4
	movq r1,r3
	movcall r6,r2,many
	add #16,sp
	; ret:one,out=16
	ret
	.even
	.globl leafone
leafone:
.L291:
.L295:
	inc r0
	; ret:one,out=0
	ret
	.even
	.globl deep
deep:
	push r8
.L299:
	movq r0,r8
.L303:
	cbne r8,#0,.L305
	clr r0
	br .L301
.L305:
	lea -1(r8),r0
	call deep
	add r0,r8
	movq r8,r0
.L301:
	popret r8
	; ret:one,out=0
	.even
	.globl tail
tail:
.L309:
	mov2 r0,r2,r1,r0
.L313:
	; ret:one,out=0
	jmp id3
	.even
	.globl regs
regs:
	pushm #50368256
.L317:
	movq r0,r15
	movq r1,r11
	mov2 r2,r10,r3,r9
	movq r4,r8
.L321:
	call id3
	movq r0,r24
	movq r15,r2
	mov2 r8,r1,r9,r0
	call id3
	movq r0,r25
	mov2 r8,r2,r9,r1
	movcall r11,r0,id3
	add r25,r24
	add r0,r24
	add r15,r24
	add r11,r24
	add r10,r24
	add r9,r24
	add r8,r24
	movq r24,r0
	popm #50368256
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
.L325:
.L329:
	clr r8
	movq #2,r1
	movq #1,r0
	call swap2
	cbeq r0,#209,.L331
	bis #1,r8
.L331:
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call keep
	cbeq r0,#-189,.L333
	bis #2,r8
.L333:
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call chain
	cbeq r0,#77,.L335
	bis #4,r8
.L335:
	movq #41,r0
	call leafone
	cbeq r0,#42,.L337
	bis #8,r8
.L337:
	movq #10,r0
	call deep
	cbeq r0,#55,.L339
	bis #16,r8
.L339:
	movq #6,r1
	movq #5,r0
	call tail
	cbeq r0,#665,.L341
	movq #6,r1
	movq #5,r0
	call tail
	cbeq r0,#665,.L341
	bis #32,r8
.L341:
	movq #5,r4
	movq #4,r3
	movq #3,r2
	movq #2,r1
	movq #1,r0
	call regs
	cbeq r0,#834,.L343
	bis #64,r8
.L343:
	movl r8,r0
	popret r8
	; ret:one,out=0
