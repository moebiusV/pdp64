	.text
	.globl helper
helper:
	.chk 3, "two.c", 31
	chk2 r6, r7, r8
	ret
