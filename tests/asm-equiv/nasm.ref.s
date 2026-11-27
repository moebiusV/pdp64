; the same, in as64's own spellings
	.text
	.globl _start, f, ext		; (extern ext: an external symbol, listed in the object)
_start:	mov	$255, r1
	mov	$5, r2
	mov	$15, r3
	mov	$31, r4
	mov	$10, r5
	mov	$10, r6
f:	ret
	.align 8
	.data
tab:	.long 1, 2, 3
	.quad 0x1122334455667788
msg:	db "hello", 0
	db 'a'
	dw 0x6261
	db "tab\t"
	.fill 5, 1, 0xAA
	.fill 64-(. - tab), 1, 0
here:	.quad .
	.bss
buf:	.space 16
	.space 16
