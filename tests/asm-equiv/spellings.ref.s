N = 4
M = 3
	.text
start:
	mov 8(r5), r1
	mov -8(r5), r1
	mov #5, r2
	add #N+1, r1
	mov (r1)(r2*4), r3
	mov 4(r1)(r2*8), r3
	mov (r1)(r2), r3
	mov #(1+2)*3, r4
	mov #M|~N, r6
	mov #0x12, r7
	mov #0x34, r8
	mov r1, r2
	add r3, sp
	.data
	.byte 1, 2, 3
	.word 1000
	.byte "ab", 0
