; the same with the older marker
	.text
	mov	#5, r1
	mov	#-1, r2
	mov	#(3+4), r3
	mov	#x+1, r4
	add	#[x*2], r5
	cbeq	r1, #5, 1f
	trap	#1
	mov	#'a', r6
	mov	#0x1f, r7
	mov	#0o17, r8
	mov	#0b101, r9
	mov	#., r10
1:	nop
x = 4
