	.text
	; names that look like an operand mark are names: a label x.s8, a symbol buf.u8, a label r1.f32 (the marks are only a register's, and only fcvt takes them)
x.s8:
	br	buf.u8
buf.u8:
r1.f32:
	br	x.s8
	.quad	r1.f32
