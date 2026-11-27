; the numbers next to the local labels: `1b` with a label 1 before it is the label (br 1b), `0b101` is the binary number 5, `10b` is the label 10 backward, and a name that looks like an old suffixed number is a name
	.text
A6h = 0xa6
1:	nop
	br	1b
	mov	$0b101, r1
	mov	$0xA5, r2
	mov	$0xff, r3
	mov	$0o377, r4
	mov	$255, r5
	mov	$0b1010, r6
	mov	$A6h, r7
	mov	$0b1001, r8
10:	br	10b
