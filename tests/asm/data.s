	.text
	nop_label:
	ret
	.data
a:	.byte	"hi\n", 'a', '\n', 0x41, 0b101, 0o17, 10, -1
	.even
b:	.word	0x1234, -2
	.long	100000
	.quad	0x0123456789abcdef
	.ascii	"A\x42\103"
	.align	8
c:	.quad	N * 2 + 1
N = 100 / 7 * 3
