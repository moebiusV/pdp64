; a displacement and a pre-decrement differ by one pair of parentheses, and the bytes differ: -8(r5) loads from r5-8 and leaves r5, (r5)-8 first subtracts 8 from r5
	mov -8(r5), r1
	mov (r5)-8, r1
