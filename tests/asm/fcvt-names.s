	.text
	; names that are nearly an operand mark are names (a name that ends in a real value mark, .s8 .u16 .f32 ..., is reserved): a label x.s7, a symbol buf.u7, a label r1.f7 (the marks are only a register's, and only fcvt takes them)
x.s7:
	br	buf.u7
buf.u7:
r1.f7:
	br	x.s7
	.quad	r1.f7
