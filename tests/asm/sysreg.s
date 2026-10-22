; mfsr rd, name and mtsr name, rs: SYS class 0, minors 13 and 14, four bytes: parcel 0 = 0101 0100 0000 minor, parcel 1 = sr:8 r:4 pad:4.
	.text
	mfsr	r8, ptbr
	mfsr	r9, epc
	mfsr	r10, eva
	mfsr	r11, ecause
	mfsr	r12, dmw0
	mfsr	r13, dmw1
	mfsr	r14, usp
	mfsr	r15, ssp
	mtsr	ptbr, r1
	mtsr	epc, r2
	mtsr	dmw0, r3
	mtsr	dmw1, r4
	mtsr	usp, r5
	mtsr	ssp, sp
	mfsr	fp, ssp
