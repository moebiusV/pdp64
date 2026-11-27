	.text
	mov $5, r3
	mov $100000, r3
	mov $0x123456789abcdef0, r3
	mov $-1, r4
	trap $3
	trap $200
	jmp lab
	br lab
	nop
lab:	ret
	.encode 3
	mov $5, r3
	.encode 5
	mov $-1, r4
	.encode 0
	mov $5, r3
	.encode 2
	mov r1, r2
	.encode
	mov r1, r2
