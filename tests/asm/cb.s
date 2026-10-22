; cbCC (page 1, opcode 0x28) in its 4-byte and 6-byte forms with the boundaries of the immediate and of the displacement, and rori32 (a BESC word with the format of rori).  Hand-worked from CHANGES section 12.
	.text
; every condition, forward to the next instruction (disp 2 parcels), then the aliases
	cbne	r0, #-5, 1f
1:
	cbeq	r1, #-4, 1f
1:
	cbpl	r2, #-3, 1f
1:
	cbmi	r3, #-2, 1f
1:
	cbvc	r4, #-1, 1f
1:
	cbvs	r5, #0, 1f
1:
	cbcc	r6, #1, 1f
1:
	cbcs	r7, #2, 1f
1:
	cbge	r8, #3, 1f
1:
	cblt	r9, #4, 1f
1:
	cbgt	r10, #5, 1f
1:
	cble	r11, #6, 1f
1:
	cbhi	r12, #7, 1f
1:
	cblos	r13, #8, 1f
1:
	cbhis	r2, #3, 1f
1:
	cblo	r2, #3, 1f
1:
	cbeq	r15, #-16, 1f
1:
	cbeq	r15, #15, 1f
1:
2:	cbne	r1, #1, 2b
	nop
3:	nop
	cbne	r1, #1, 3b
	cbne	r1, #1, 1f
	nop
1:
	cbge	r3, #4, 1f
	.space	2042
1:
	cbge	r3, #4, 1f
	.space	2044
1:
1:	.space	2048
	cblt	r4, #-2, 1b
1:	.space	2050
	cblt	r4, #-2, 1b
	cbhi	r5, #0, 1f
	.space	6000
1:
	rori32	r1, #5, r2
	rori32	r7, #0, r15
	rori32	r0, #31, r0
	rori	r1, #5, r2
