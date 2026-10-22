; a constant that does not fit the 32-bit immediate field, in an instruction that reads 8 bytes, becomes a pc-relative operand on a literal at the end
; of .text (aligned to 8, one copy of each value): movq, the ALU, push.  Hand-worked: three 4-byte instructions and ret = 14 bytes, a nop pads
; to 16, the literals are 0x100000000 at 16 and -0x100000000 at 24.
	.text
	movq	#0x100000000, r1
	cmp	r2, #-0x100000000
	add	#0x100000000, r3
	ret
