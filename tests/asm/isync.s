; isync and hint: the assembler picks the two-byte (page 2) forms: isync = 0x2C, hint #n = 0x2D with n = reg:low
	.text
	isync
	hint	#0
	hint	#1
	hint	#2
	hint	#0xA5
	hint	#255
