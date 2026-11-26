; the atomic words: every one of the 24, each with registers that differ, assembled and compared with the words worked out from the layout of the grammar (57-enc-atomic.hbnf):
; parcel 0 = prefix (12 bits: 0xFE0) then the high four bits of the 5-bit sub-opcode (the operation times two, plus 1 for the 4-byte word); parcel 1 = the low bit of the sub-opcode, Rs, Ra, Rd (5 bits each, in the order written, `op Rs, (Ra), Rd`: the destination is the lowest field);
; ll and lll: parcel 0 = 0xFE20, parcel 1 = sub-opcode (6 bits), Ra, Rd (written `ll (Ra), Rd`).
	.text
	cas r2,(r3),r1
	swap r8,(r13),r3
	aadd r14,(r23),r5
	aand r20,(r1),r7
	abis r26,(r11),r9
	axor r0,(r21),r11
	amax r6,(r31),r13
	amin r12,(r9),r15
	amaxu r18,(r19),r17
	aminu r24,(r29),r19
	sc r22,(r23),r21
	casl r1,(r12),r22
	swapl r7,(r22),r24
	aaddl r13,(r0),r26
	aandl r19,(r10),r28
	abisl r25,(r20),r30
	axorl r31,(r30),r0
	amaxl r5,(r8),r2
	aminl r11,(r18),r4
	amaxul r17,(r28),r6
	aminul r23,(r6),r8
	scl r14,(r16),r12
	ll (r30),r7
	lll (r29),r8
