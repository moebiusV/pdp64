; the register-register cbCC (opcode 0x2A): parcel 0 = len 101010 ra rb, parcel 1 = cond:4 disp:12 (four bytes) or cond:4 disp-high:12 and parcel 2 = disp-low:16 (six bytes), the displacement in parcels from the first parcel
	.text
	cbne	r0, r15, 1f
1:
	cbeq	r15, r0, 1f
1:
	cbpl	r1, r2, 1f
1:
	cbmi	r3, r3, 1f
1:
	cbvc	r14, r13, 1f
1:
	cbvs	r7, r8, 1f
1:
	cbcc	r2, r1, 1f
1:
	cbcs	r9, r9, 1f
1:
	cbge	r5, r12, 1f
1:
	cblt	r12, r5, 1f
1:
	cbgt	r0, r0, 1f
1:
	cble	r15, r15, 1f
1:
	cbhi	r4, r11, 1f
1:
	cblos	r6, r10, 1f
1:
	cbhis	sp, fp, 1f
1:
	cblo	sp, fp, 1f
1:
	cbeq	r1, r2, 1f
	.space	4090
1:
	cbeq	r1, r2, 1f
	.space	4092
1:
1:	.space	4096
	cbne	r3, r4, 1b
1:	.space	4098
	cbne	r3, r4, 1b
	cblt	r5, r6, 2f
	nop
2:
3:	cbgt	r5, r6, 3b
	cbhi	r8, r9, 4f
	.space	139994
4:
