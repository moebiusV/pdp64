	.text
start:	movq r1,r2
	movq #5,r3
	movq #300,r4
	movq #70000,r5
	movq 8(sp),r6
	movq r6,16(sp)
	movq (r2),r3
	movl 4(r3),r1
	movb r1,(r2)
	movzb 1(r8),r2
	lea 32(sp),r1
	lea start,r2
	add r1,r2
	sub #1,r2
	and #255,r3
	shl #3,r4
	xor r8,r9
	cmp r1,r2
	cmp r5,#7
	push r2
	pop r3
	inc r1
	clr r2
	tst r3
	neg r4
	add #16,sp
	sub #4096,sp
	movq 100000(r1),r2
	movl r2,-20(r3)
	ret
