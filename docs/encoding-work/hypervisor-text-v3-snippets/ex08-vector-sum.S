; 6.15 example 8: a vector block that keeps a running sum in a hidden accumulator.  VEC repeats the body, once for each strip, until the first pointer reaches the second;
; VCLR names the accumulator and is legal only inside the block; VFIN starts the epilogue, which runs once after the last strip.  The scalar loop below computes the
; same sum, so the program checks itself.  Run: sim64, and again with a wider strip (sim64 -S 32), which must give the same answer.
	.text
	.globl	_start
_start:
	lea	wsrc, r1			; 21 words of 16 bits
	mov	$21, r2
	lea	(r1)(r2*2), r4			; the end pointer
	mov	$0, r12				; the result register
	vec	r1, r4				; the block: the body runs once for each strip
	vclr.l	v4, $1				; the accumulator starts at zero (only inside the block)
	vld.w.l	v0, (r1)+			; four 16-bit words widened to 32 bits; the pointer advances
	vadd.l	v4, v4, v0			; the running sum, by lane
	vfin					; the epilogue: once, after the last strip
	vacc.l.q r12, v4			; add the lanes into R12
	vend
	; the same sum, one word at a time
	lea	wsrc, r1
	mov	$21, r2
	mov	$0, r6
1:	mov.u16	(r1)+, r3
	add	r3, r6
	sob	r2, 1b
	cbeq	r12, r6, ok
	mov	$1, r0				; the block and the loop disagree
	halt
ok:	mov	$0, r0
	halt
	.data
	.align	8
wsrc:	.word	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21
