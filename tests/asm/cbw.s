; the wide-immediate cbCC (opcode 0x29, six bytes: parcel 0 = 10 101001 rd cond, parcel 1 = imm16, parcel 2 = disp16 in parcels) and the choice among the three encodings
	.text
	cbne	r0, #-32768, 1f
1:
	cbeq	r1, #32767, 1f
1:
	cbpl	r2, #-17, 1f
1:
	cbmi	r3, #16, 1f
1:
	cbvc	r4, #255, 1f
1:
	cbvs	r5, #-1000, 1f
1:
	cbcc	r6, #47, 1f
1:
	cbcs	r7, #-32768, 1f
1:
	cbge	r8, #32767, 1f
1:
	cblt	r9, #-17, 1f
1:
	cbgt	r10, #16, 1f
1:
	cble	r11, #255, 1f
1:
	cbhi	r12, #-1000, 1f
1:
	cblos	r13, #47, 1f
1:
	cbhis	r2, #200, 1f
1:
	cblo	r2, #200, 1f
1:
	cbeq	r3, #-16, 1f
1:
	cbeq	r3, #15, 1f
1:
	cbeq	r3, #-17, 1f
1:
	cbeq	r3, #16, 1f
1:
	cbne	r4, #3, 1f
	.space	2044
1:
	cbne	r4, #3000, 1f
	.space	2044
1:
	cbne	r4, #3, 1f
	.space	2042
1:
	cbne	r4, #-17, 1f
	nop
1:
2:	cbgt	r5, #-32768, 2b
	nop
3:	nop
	cbgt	r5, #32767, 3b
