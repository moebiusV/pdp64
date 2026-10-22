; literal-pool loads: an operand written =K stores the 64-bit constant K once per pool (8 bytes, aligned to 8, entries in the order of first use) and is that
; entry as a pc-relative memory operand.  `=` always pools, a K that would fit 32 bits too.  A pool is emitted at .pool and at the end of the text.
; Hand-worked: six 4-byte instructions = 24 bytes, so the first pool needs no padding: A = 0x123456789ABC at 24, -2 at 32, 5 at 40 (A is used twice:
; one entry).  The next instruction is at 48 and has a pool of its own (A again, one more entry); three bytes of data end at 55, so the pool at the end
; of the text is padded to 56.
	.text
	movq	=0x123456789ABC, r1
	movq	=-2, r2
	movq	=5, r3
	movq	=0x123456789ABC, r4
	add	=-2, r5
	cmp	r6, =5
	.pool
	movq	=0x123456789ABC, r7
	.byte	1, 2, 3
