; an instruction after an odd number of bytes in .text is an error
	.text
	.byte	1
	ret
