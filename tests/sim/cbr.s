; the register-register cbCC (opcode 0x2A): signed and unsigned conditions with equal, less and greater values and the most negative number;
; each condition is checked taken and not taken.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	mov	#5, r1
	mov	#5, r2
	mov	#7, r3
	mov	#-1, r4
	mov	#1, r5
	shl	#15, r5
	shl	#16, r5
	shl	#16, r5
	shl	#16, r5			; r5 = 0x8000000000000000, the most negative number
	mov	#0, r6
	cbne	r1, r2, f1
	cbeq	r1, r2, 1f
	br	f2
1:
1:
1:
	cbcc	r1, r2, 1f
	br	f7
1:
	cbcs	r1, r2, f8
	cbge	r1, r2, 1f
	br	f9
1:
	cblt	r1, r2, f10
	cbgt	r1, r2, f11
	cble	r1, r2, 1f
	br	f12
1:
	cbhi	r1, r2, f13
	cblos	r1, r2, 1f
	br	f14
1:
	cbne	r1, r3, 1f
	br	f15
1:
	cbeq	r1, r3, f16
1:
1:
	cbcc	r1, r3, f21
	cbcs	r1, r3, 1f
	br	f22
1:
	cbge	r1, r3, f23
	cblt	r1, r3, 1f
	br	f24
1:
	cbgt	r1, r3, f25
	cble	r1, r3, 1f
	br	f26
1:
	cbhi	r1, r3, f27
	cblos	r1, r3, 1f
	br	f28
1:
	cbne	r3, r1, 1f
	br	f29
1:
	cbeq	r3, r1, f30
1:
1:
	cbcc	r3, r1, 1f
	br	f35
1:
	cbcs	r3, r1, f36
	cbge	r3, r1, 1f
	br	f37
1:
	cblt	r3, r1, f38
	cbgt	r3, r1, 1f
	br	f39
1:
	cble	r3, r1, f40
	cbhi	r3, r1, 1f
	br	f41
1:
	cblos	r3, r1, f42
	cbne	r4, r1, 1f
	br	f43
1:
	cbeq	r4, r1, f44
1:
1:
	cbcc	r4, r1, 1f
	br	f49
1:
	cbcs	r4, r1, f50
	cbge	r4, r1, f51
	cblt	r4, r1, 1f
	br	f52
1:
	cbgt	r4, r1, f53
	cble	r4, r1, 1f
	br	f54
1:
	cbhi	r4, r1, 1f
	br	f55
1:
	cblos	r4, r1, f56
	cbne	r1, r4, 1f
	br	f57
1:
	cbeq	r1, r4, f58
1:
1:
	cbcc	r1, r4, f63
	cbcs	r1, r4, 1f
	br	f64
1:
	cbge	r1, r4, 1f
	br	f65
1:
	cblt	r1, r4, f66
	cbgt	r1, r4, 1f
	br	f67
1:
	cble	r1, r4, f68
	cbhi	r1, r4, f69
	cblos	r1, r4, 1f
	br	f70
1:
	cbne	r5, r1, 1f
	br	f71
1:
	cbeq	r5, r1, f72
1:
1:
	cbcc	r5, r1, 1f
	br	f77
1:
	cbcs	r5, r1, f78
	cbge	r5, r1, f79
	cblt	r5, r1, 1f
	br	f80
1:
	cbgt	r5, r1, f81
	cble	r5, r1, 1f
	br	f82
1:
	cbhi	r5, r1, 1f
	br	f83
1:
	cblos	r5, r1, f84
	cbne	r1, r5, 1f
	br	f85
1:
	cbeq	r1, r5, f86
1:
1:
	cbcc	r1, r5, f91
	cbcs	r1, r5, 1f
	br	f92
1:
	cbge	r1, r5, 1f
	br	f93
1:
	cblt	r1, r5, f94
	cbgt	r1, r5, 1f
	br	f95
1:
	cble	r1, r5, f96
	cbhi	r1, r5, f97
	cblos	r1, r5, 1f
	br	f98
1:
	cbne	r5, r4, 1f
	br	f99
1:
	cbeq	r5, r4, f100
1:
1:
	cbcc	r5, r4, f105
	cbcs	r5, r4, 1f
	br	f106
1:
	cbge	r5, r4, f107
	cblt	r5, r4, 1f
	br	f108
1:
	cbgt	r5, r4, f109
	cble	r5, r4, 1f
	br	f110
1:
	cbhi	r5, r4, f111
	cblos	r5, r4, 1f
	br	f112
1:
	cbne	r6, r5, 1f
	br	f113
1:
	cbeq	r6, r5, f114
1:
1:
	cbcc	r6, r5, f119
	cbcs	r6, r5, 1f
	br	f120
1:
	cbge	r6, r5, 1f
	br	f121
1:
	cblt	r6, r5, f122
	cbgt	r6, r5, 1f
	br	f123
1:
	cble	r6, r5, f124
	cbhi	r6, r5, f125
	cblos	r6, r5, 1f
	br	f126
1:
	cbne	r5, r6, 1f
	br	f127
1:
	cbeq	r5, r6, f128
1:
1:
	cbcc	r5, r6, 1f
	br	f133
1:
	cbcs	r5, r6, f134
	cbge	r5, r6, f135
	cblt	r5, r6, 1f
	br	f136
1:
	cbgt	r5, r6, f137
	cble	r5, r6, 1f
	br	f138
1:
	cbhi	r5, r6, 1f
	br	f139
1:
	cblos	r5, r6, f140
	mov	#0, r0
	trap	#0
f1:	mov	#1, r0
	trap	#0
f2:	mov	#2, r0
	trap	#0
f7:	mov	#7, r0
	trap	#0
f8:	mov	#8, r0
	trap	#0
f9:	mov	#9, r0
	trap	#0
f10:	mov	#10, r0
	trap	#0
f11:	mov	#11, r0
	trap	#0
f12:	mov	#12, r0
	trap	#0
f13:	mov	#13, r0
	trap	#0
f14:	mov	#14, r0
	trap	#0
f15:	mov	#15, r0
	trap	#0
f16:	mov	#16, r0
	trap	#0
f21:	mov	#21, r0
	trap	#0
f22:	mov	#22, r0
	trap	#0
f23:	mov	#23, r0
	trap	#0
f24:	mov	#24, r0
	trap	#0
f25:	mov	#25, r0
	trap	#0
f26:	mov	#26, r0
	trap	#0
f27:	mov	#27, r0
	trap	#0
f28:	mov	#28, r0
	trap	#0
f29:	mov	#29, r0
	trap	#0
f30:	mov	#30, r0
	trap	#0
f35:	mov	#35, r0
	trap	#0
f36:	mov	#36, r0
	trap	#0
f37:	mov	#37, r0
	trap	#0
f38:	mov	#38, r0
	trap	#0
f39:	mov	#39, r0
	trap	#0
f40:	mov	#40, r0
	trap	#0
f41:	mov	#41, r0
	trap	#0
f42:	mov	#42, r0
	trap	#0
f43:	mov	#43, r0
	trap	#0
f44:	mov	#44, r0
	trap	#0
f49:	mov	#49, r0
	trap	#0
f50:	mov	#50, r0
	trap	#0
f51:	mov	#51, r0
	trap	#0
f52:	mov	#52, r0
	trap	#0
f53:	mov	#53, r0
	trap	#0
f54:	mov	#54, r0
	trap	#0
f55:	mov	#55, r0
	trap	#0
f56:	mov	#56, r0
	trap	#0
f57:	mov	#57, r0
	trap	#0
f58:	mov	#58, r0
	trap	#0
f63:	mov	#63, r0
	trap	#0
f64:	mov	#64, r0
	trap	#0
f65:	mov	#65, r0
	trap	#0
f66:	mov	#66, r0
	trap	#0
f67:	mov	#67, r0
	trap	#0
f68:	mov	#68, r0
	trap	#0
f69:	mov	#69, r0
	trap	#0
f70:	mov	#70, r0
	trap	#0
f71:	mov	#71, r0
	trap	#0
f72:	mov	#72, r0
	trap	#0
f77:	mov	#77, r0
	trap	#0
f78:	mov	#78, r0
	trap	#0
f79:	mov	#79, r0
	trap	#0
f80:	mov	#80, r0
	trap	#0
f81:	mov	#81, r0
	trap	#0
f82:	mov	#82, r0
	trap	#0
f83:	mov	#83, r0
	trap	#0
f84:	mov	#84, r0
	trap	#0
f85:	mov	#85, r0
	trap	#0
f86:	mov	#86, r0
	trap	#0
f91:	mov	#91, r0
	trap	#0
f92:	mov	#92, r0
	trap	#0
f93:	mov	#93, r0
	trap	#0
f94:	mov	#94, r0
	trap	#0
f95:	mov	#95, r0
	trap	#0
f96:	mov	#96, r0
	trap	#0
f97:	mov	#97, r0
	trap	#0
f98:	mov	#98, r0
	trap	#0
f99:	mov	#99, r0
	trap	#0
f100:	mov	#100, r0
	trap	#0
f105:	mov	#105, r0
	trap	#0
f106:	mov	#106, r0
	trap	#0
f107:	mov	#107, r0
	trap	#0
f108:	mov	#108, r0
	trap	#0
f109:	mov	#109, r0
	trap	#0
f110:	mov	#110, r0
	trap	#0
f111:	mov	#111, r0
	trap	#0
f112:	mov	#112, r0
	trap	#0
f113:	mov	#113, r0
	trap	#0
f114:	mov	#114, r0
	trap	#0
f119:	mov	#119, r0
	trap	#0
f120:	mov	#120, r0
	trap	#0
f121:	mov	#121, r0
	trap	#0
f122:	mov	#122, r0
	trap	#0
f123:	mov	#123, r0
	trap	#0
f124:	mov	#124, r0
	trap	#0
f125:	mov	#125, r0
	trap	#0
f126:	mov	#126, r0
	trap	#0
f127:	mov	#127, r0
	trap	#0
f128:	mov	#128, r0
	trap	#0
f133:	mov	#133, r0
	trap	#0
f134:	mov	#134, r0
	trap	#0
f135:	mov	#135, r0
	trap	#0
f136:	mov	#136, r0
	trap	#0
f137:	mov	#137, r0
	trap	#0
f138:	mov	#138, r0
	trap	#0
f139:	mov	#139, r0
	trap	#0
f140:	mov	#140, r0
	trap	#0
