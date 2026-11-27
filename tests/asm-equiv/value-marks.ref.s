; the same, written as the values
	.text
big = 0x1ff
	mov	$-1, r1
	mov	$255, r2
	mov	$255, r3
	mov	$-56, r4
	mov	$-128, r5
	mov	$-1, r6
	mov	$-1, r7
	mov	$0x1ff, r8
	mov	$0x1ff, r9
	mov	$255, r10
	cbeq	r1, $127, 1f
	cbeq	r1, $-1, 1f
1:	nop
	.data
	.byte	-1, 255, 255, -56, 128
	.word	-1, 65535, 0x1ff
	.long	-1, 0xffffffff
	.quad	-1, -1
