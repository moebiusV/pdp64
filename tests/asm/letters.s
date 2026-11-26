; the integer words with a width letter that the other letter tests do not have: b w l q (8, 16, 32, 64 bits), z (zero-extending), the user moves, the byte swaps, the explicit q atomics.
; The words are those of the encoding, unchanged by the marks: tests/asm-equiv/letters writes every one of them with the marks and the objects must be the same.
	.text
	movb r1,r2
	movw r3,r4
	movl r5,r6
	movq r7,r8
	movzb r1,r2
	movzw r3,r4
	movzl r5,r6
	movw (r3),r4
	movw r4,(r3)
	movzw (r3),r4
	movzl 8(r3),r4
	movl (r1)(r2*4),r3
	movq.u (r1),r2
	movl.u (r1),r2
	movw.u 2(r1),r2
	movb.u (r1),r2
	movzl.u (r1),r2
	movzw.u (r1),r2
	movzb.u (r1),r2
	bswapw r1,r2
	bswapl r3,r4
	cas r1,(r2),r3
	casq r1,(r2),r3
	aaddq r4,(r5),r6
	llq (r7),r8
	scq r1,(r2),r3
	rorl r1,#5,r2
