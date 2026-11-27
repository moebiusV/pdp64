; NASM's spellings of the directives (bits, default, section, global, extern, align, db dw dd dq, times, resb resq)
	bits 64
	default rel
	SECTION .text
	global _start, f
	extern ext
_start:	mov	$0xFF, r1
	mov	$0b101, r2
	mov	$0o17, r3
	mov	$0x1f, r4
	mov	$10, r5
	mov	$0b1010, r6
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
	times 64-(. - tab) db 0
here:	dq .
	section .bss
buf:	resb 16
	resq 2
