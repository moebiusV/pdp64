; NASM's spellings of the directives, the numbers with a suffix, and $ and $$ (errata 162)
	bits 64
	default rel
	SECTION .text
	global _start, f
	extern ext
_start:	mov	#0FFh, r1
	mov	#101b, r2
	mov	#17q, r3
	mov	#0x1f, r4
	mov	#10d, r5
	mov	#1010b, r6
f:	ret
	align 8
	section .data
tab:	dd 1, 2, 3
	dq 0x1122334455667788
msg	db 'hello', 0
	db 'a'
	dw 'ab'
	db `tab\t`
	times 5 db 0xAA
	times 64-($-$$) db 0
here:	dq $
	section .bss
buf:	resb 16
	resq 2
