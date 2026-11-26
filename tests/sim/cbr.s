; the register-register cbCC (opcode 0x2A): signed and unsigned conditions with equal, less and greater values and the most negative number;
; each condition is checked taken and not taken.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	#5, r1
	movq	#5, r2
	movq	#7, r3
	movq	#-1, r4
	movq	#1, r5
	shl	#15, r5
	shl	#16, r5
	shl	#16, r5
	shl	#16, r5			; r5 = 0x8000000000000000, the most negative number
	movq	#0, r6
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
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f7:	movq	#7, r0
	trap	#0
f8:	movq	#8, r0
	trap	#0
f9:	movq	#9, r0
	trap	#0
f10:	movq	#10, r0
	trap	#0
f11:	movq	#11, r0
	trap	#0
f12:	movq	#12, r0
	trap	#0
f13:	movq	#13, r0
	trap	#0
f14:	movq	#14, r0
	trap	#0
f15:	movq	#15, r0
	trap	#0
f16:	movq	#16, r0
	trap	#0
f21:	movq	#21, r0
	trap	#0
f22:	movq	#22, r0
	trap	#0
f23:	movq	#23, r0
	trap	#0
f24:	movq	#24, r0
	trap	#0
f25:	movq	#25, r0
	trap	#0
f26:	movq	#26, r0
	trap	#0
f27:	movq	#27, r0
	trap	#0
f28:	movq	#28, r0
	trap	#0
f29:	movq	#29, r0
	trap	#0
f30:	movq	#30, r0
	trap	#0
f35:	movq	#35, r0
	trap	#0
f36:	movq	#36, r0
	trap	#0
f37:	movq	#37, r0
	trap	#0
f38:	movq	#38, r0
	trap	#0
f39:	movq	#39, r0
	trap	#0
f40:	movq	#40, r0
	trap	#0
f41:	movq	#41, r0
	trap	#0
f42:	movq	#42, r0
	trap	#0
f43:	movq	#43, r0
	trap	#0
f44:	movq	#44, r0
	trap	#0
f49:	movq	#49, r0
	trap	#0
f50:	movq	#50, r0
	trap	#0
f51:	movq	#51, r0
	trap	#0
f52:	movq	#52, r0
	trap	#0
f53:	movq	#53, r0
	trap	#0
f54:	movq	#54, r0
	trap	#0
f55:	movq	#55, r0
	trap	#0
f56:	movq	#56, r0
	trap	#0
f57:	movq	#57, r0
	trap	#0
f58:	movq	#58, r0
	trap	#0
f63:	movq	#63, r0
	trap	#0
f64:	movq	#64, r0
	trap	#0
f65:	movq	#65, r0
	trap	#0
f66:	movq	#66, r0
	trap	#0
f67:	movq	#67, r0
	trap	#0
f68:	movq	#68, r0
	trap	#0
f69:	movq	#69, r0
	trap	#0
f70:	movq	#70, r0
	trap	#0
f71:	movq	#71, r0
	trap	#0
f72:	movq	#72, r0
	trap	#0
f77:	movq	#77, r0
	trap	#0
f78:	movq	#78, r0
	trap	#0
f79:	movq	#79, r0
	trap	#0
f80:	movq	#80, r0
	trap	#0
f81:	movq	#81, r0
	trap	#0
f82:	movq	#82, r0
	trap	#0
f83:	movq	#83, r0
	trap	#0
f84:	movq	#84, r0
	trap	#0
f85:	movq	#85, r0
	trap	#0
f86:	movq	#86, r0
	trap	#0
f91:	movq	#91, r0
	trap	#0
f92:	movq	#92, r0
	trap	#0
f93:	movq	#93, r0
	trap	#0
f94:	movq	#94, r0
	trap	#0
f95:	movq	#95, r0
	trap	#0
f96:	movq	#96, r0
	trap	#0
f97:	movq	#97, r0
	trap	#0
f98:	movq	#98, r0
	trap	#0
f99:	movq	#99, r0
	trap	#0
f100:	movq	#100, r0
	trap	#0
f105:	movq	#105, r0
	trap	#0
f106:	movq	#106, r0
	trap	#0
f107:	movq	#107, r0
	trap	#0
f108:	movq	#108, r0
	trap	#0
f109:	movq	#109, r0
	trap	#0
f110:	movq	#110, r0
	trap	#0
f111:	movq	#111, r0
	trap	#0
f112:	movq	#112, r0
	trap	#0
f113:	movq	#113, r0
	trap	#0
f114:	movq	#114, r0
	trap	#0
f119:	movq	#119, r0
	trap	#0
f120:	movq	#120, r0
	trap	#0
f121:	movq	#121, r0
	trap	#0
f122:	movq	#122, r0
	trap	#0
f123:	movq	#123, r0
	trap	#0
f124:	movq	#124, r0
	trap	#0
f125:	movq	#125, r0
	trap	#0
f126:	movq	#126, r0
	trap	#0
f127:	movq	#127, r0
	trap	#0
f128:	movq	#128, r0
	trap	#0
f133:	movq	#133, r0
	trap	#0
f134:	movq	#134, r0
	trap	#0
f135:	movq	#135, r0
	trap	#0
f136:	movq	#136, r0
	trap	#0
f137:	movq	#137, r0
	trap	#0
f138:	movq	#138, r0
	trap	#0
f139:	movq	#139, r0
	trap	#0
f140:	movq	#140, r0
	trap	#0
