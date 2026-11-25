	.text
	.even
	.globl id
id:
.L251:
.L255:
	; ret:one,out=0
	ret
	.even
	.globl pressure
pressure:
	pushm #4278226688
	sub #32,sp
.L259:
.L263:
	lea 1(r0),r30
	lea 2(r0),r1
	movq r1,(sp)
	lea 3(r0),r1
	movq r1,8(sp)
	lea 4(r0),r1
	movq r1,16(sp)
	lea 5(r0),r1
	movq r1,24(sp)
	lea 6(r0),r29
	lea 7(r0),r28
	lea 8(r0),r27
	lea 9(r0),r26
	lea 10(r0),r25
	lea 11(r0),r24
	lea 12(r0),r15
	lea 13(r0),r11
	lea 14(r0),r10
	lea 15(r0),r9
	lea 16(r0),r8
	call id
	movq r0,r31
	movq r30,r0
	add r8,r0
	call id
	add r30,r31
	movq (sp),r1
	asl r1
	add r1,r31
	movq 8(sp),r1
	mul #3,r1
	add r1,r31
	movq 16(sp),r1
	shl #2,r1
	add r1,r31
	movq 24(sp),r1
	lea (r1)(r1*4),r1
	add r1,r31
	mul #6,r29
	add r29,r31
	mul #7,r28
	add r28,r31
	shl #3,r27
	add r27,r31
	lea (r26)(r26*8),r26
	add r26,r31
	mul #10,r25
	add r25,r31
	mul #11,r24
	add r24,r31
	mul #12,r15
	add r15,r31
	mul #13,r11
	add r11,r31
	mul #14,r10
	add r10,r31
	mul #15,r9
	add r9,r31
	shl #4,r8
	add r8,r31
	add r0,r31
	movq r31,r0
	add #32,sp
	popm #4278226688
	; ret:one,out=0
	ret
	.even
	.globl test
test:
	push r8
.L267:
.L271:
	movq #100,r3
	movq #100,r8
	movq #1,r0
	br .L277
.L268:
	movq r3,r2
	add r0,r2
	movq r0,r1
	mul r2,r1
	add r1,r8
	inc r0
.L277:
	cble r0,#16,.L268
	movq #217,r0
	add r8,r0
	movq r0,r8
	movq #100,r0
	call pressure
	cmp r0,r8
	set ne,r0
.L281:
	popret r8
	; ret:one,out=0
