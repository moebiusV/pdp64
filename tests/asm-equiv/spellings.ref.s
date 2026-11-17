N = 4
M = 3
	.text
start:
	movq 8(r5), r1
	movq -8(r5), r1
	movq #5, r2
	add #N+1, r1
	movq (r1)(r2*4), r3
	movq 4(r1)(r2*8), r3
	movq (r1)(r2), r3
	movq #(1+2)*3, r4
	movq #M|~N, r6
	movq #0x12, r7
	movq #0x34, r8
	movq r1, r2
	add r3, sp
	.data
	.byte 1, 2, 3
	.word 1000
	.byte "ab", 0
