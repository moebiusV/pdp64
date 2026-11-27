	.text
start:	mov r1, r2
	mov #5, r3
	mov #300, r4
	mov #70000, r5
	mov 8(sp), r6
	mov r6, 16(sp)
	mov (r2), r3
	mov.s32 4(r3), r1
	mov.s8 r1, (r2)
	mov.u8 1(r8), r2
	lea 32(sp),r1
	lea start,r2
	add r1,r2
	sub #1,r2
	and #255,r3
	shl #3,r4
	xor r8,r9
	sub r1,r2
	sub #7,r5
	push r2
	pop r3
	inc r1
	clr r2
	com r3
	neg r4
	add #16,sp
	sub #4096,sp
	mov 100000(r1), r2
	mov.s32 r2, -20(r3)
	ret
