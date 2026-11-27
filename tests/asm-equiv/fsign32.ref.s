	.text
	xor $-2147483648, r1
	mov r1, r2
	xor $-2147483648, r2
	and $0x7fffffff, r3
	mov r3, r4
	and $0x7fffffff, r4
