; .even after odd data: layout passes must count the padding (found by the pcc back end)
	.text
	.byte 0
	.even
f:	lea f,r0
	bne L
	call memset
L:	ret
