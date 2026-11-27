	.text
	.globl _start
_start:
	.chk 1, "one.c", 7
	cthis r1, $16
	call helper
	.chk 2, "one.c", 9
	cteq r2
	lea __start___bug_table, r3
	lea __stop___bug_table, r4
	halt
