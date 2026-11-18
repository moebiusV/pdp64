	.text
	.chk 1, "a.c", 10
	cthis r1, #16
	cteq r2
	ctne r3
	.chk 3, "a.c", 12
	ctcc r4, r5
	chk2 r6, r7, r8
	ctlo r9, r11
	ctge r10, r12
	ret
