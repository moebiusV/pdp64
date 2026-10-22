; the register-register cbCC (opcode 0x2A): signed and unsigned conditions with equal, less and greater values and the most negative number;
; and it writes NO flag (errata 39), taken or not: the flags after it are those before it (read with `set`).  A failed check n exits with n.
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
	cbpl	r1, r2, 1f
	br	f3
1:
	cbmi	r1, r2, f4
	cbvc	r1, r2, 1f
	br	f5
1:
	cbvs	r1, r2, f6
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
	cbpl	r1, r3, f17
	cbmi	r1, r3, 1f
	br	f18
1:
	cbvc	r1, r3, 1f
	br	f19
1:
	cbvs	r1, r3, f20
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
	cbpl	r3, r1, 1f
	br	f31
1:
	cbmi	r3, r1, f32
	cbvc	r3, r1, 1f
	br	f33
1:
	cbvs	r3, r1, f34
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
	cbpl	r4, r1, f45
	cbmi	r4, r1, 1f
	br	f46
1:
	cbvc	r4, r1, 1f
	br	f47
1:
	cbvs	r4, r1, f48
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
	cbpl	r1, r4, 1f
	br	f59
1:
	cbmi	r1, r4, f60
	cbvc	r1, r4, 1f
	br	f61
1:
	cbvs	r1, r4, f62
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
	cbpl	r5, r1, 1f
	br	f73
1:
	cbmi	r5, r1, f74
	cbvc	r5, r1, f75
	cbvs	r5, r1, 1f
	br	f76
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
	cbpl	r1, r5, f87
	cbmi	r1, r5, 1f
	br	f88
1:
	cbvc	r1, r5, f89
	cbvs	r1, r5, 1f
	br	f90
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
	cbpl	r5, r4, f101
	cbmi	r5, r4, 1f
	br	f102
1:
	cbvc	r5, r4, 1f
	br	f103
1:
	cbvs	r5, r4, f104
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
	cbpl	r6, r5, f115
	cbmi	r6, r5, 1f
	br	f116
1:
	cbvc	r6, r5, f117
	cbvs	r6, r5, 1f
	br	f118
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
	cbpl	r5, r6, f129
	cbmi	r5, r6, 1f
	br	f130
1:
	cbvc	r5, r6, 1f
	br	f131
1:
	cbvs	r5, r6, f132
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
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f141
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f141
	cmp	r11, r8
	bne	f141
	cmp	r12, r9
	bne	f141
	cmp	r13, r15
	bne	f141
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f142
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f142
	cmp	r11, r8
	bne	f142
	cmp	r12, r9
	bne	f142
	cmp	r13, r15
	bne	f142
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f143
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f143
	cmp	r11, r8
	bne	f143
	cmp	r12, r9
	bne	f143
	cmp	r13, r15
	bne	f143
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f144
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f144
	cmp	r11, r8
	bne	f144
	cmp	r12, r9
	bne	f144
	cmp	r13, r15
	bne	f144
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f145
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f145
	cmp	r11, r8
	bne	f145
	cmp	r12, r9
	bne	f145
	cmp	r13, r15
	bne	f145
	cmp	r1, r2
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f146
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f146
	cmp	r11, r8
	bne	f146
	cmp	r12, r9
	bne	f146
	cmp	r13, r15
	bne	f146
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f147
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f147
	cmp	r11, r8
	bne	f147
	cmp	r12, r9
	bne	f147
	cmp	r13, r15
	bne	f147
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f148
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f148
	cmp	r11, r8
	bne	f148
	cmp	r12, r9
	bne	f148
	cmp	r13, r15
	bne	f148
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f149
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f149
	cmp	r11, r8
	bne	f149
	cmp	r12, r9
	bne	f149
	cmp	r13, r15
	bne	f149
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f150
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f150
	cmp	r11, r8
	bne	f150
	cmp	r12, r9
	bne	f150
	cmp	r13, r15
	bne	f150
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f151
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f151
	cmp	r11, r8
	bne	f151
	cmp	r12, r9
	bne	f151
	cmp	r13, r15
	bne	f151
	cmp	r1, r3
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f152
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f152
	cmp	r11, r8
	bne	f152
	cmp	r12, r9
	bne	f152
	cmp	r13, r15
	bne	f152
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f153
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f153
	cmp	r11, r8
	bne	f153
	cmp	r12, r9
	bne	f153
	cmp	r13, r15
	bne	f153
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f154
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f154
	cmp	r11, r8
	bne	f154
	cmp	r12, r9
	bne	f154
	cmp	r13, r15
	bne	f154
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f155
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f155
	cmp	r11, r8
	bne	f155
	cmp	r12, r9
	bne	f155
	cmp	r13, r15
	bne	f155
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f156
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f156
	cmp	r11, r8
	bne	f156
	cmp	r12, r9
	bne	f156
	cmp	r13, r15
	bne	f156
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f157
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f157
	cmp	r11, r8
	bne	f157
	cmp	r12, r9
	bne	f157
	cmp	r13, r15
	bne	f157
	cmp	r3, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f158
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f158
	cmp	r11, r8
	bne	f158
	cmp	r12, r9
	bne	f158
	cmp	r13, r15
	bne	f158
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f159
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f159
	cmp	r11, r8
	bne	f159
	cmp	r12, r9
	bne	f159
	cmp	r13, r15
	bne	f159
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f160
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f160
	cmp	r11, r8
	bne	f160
	cmp	r12, r9
	bne	f160
	cmp	r13, r15
	bne	f160
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f161
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f161
	cmp	r11, r8
	bne	f161
	cmp	r12, r9
	bne	f161
	cmp	r13, r15
	bne	f161
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f162
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f162
	cmp	r11, r8
	bne	f162
	cmp	r12, r9
	bne	f162
	cmp	r13, r15
	bne	f162
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f163
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f163
	cmp	r11, r8
	bne	f163
	cmp	r12, r9
	bne	f163
	cmp	r13, r15
	bne	f163
	cmp	r4, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f164
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f164
	cmp	r11, r8
	bne	f164
	cmp	r12, r9
	bne	f164
	cmp	r13, r15
	bne	f164
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f165
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f165
	cmp	r11, r8
	bne	f165
	cmp	r12, r9
	bne	f165
	cmp	r13, r15
	bne	f165
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f166
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f166
	cmp	r11, r8
	bne	f166
	cmp	r12, r9
	bne	f166
	cmp	r13, r15
	bne	f166
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f167
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f167
	cmp	r11, r8
	bne	f167
	cmp	r12, r9
	bne	f167
	cmp	r13, r15
	bne	f167
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f168
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f168
	cmp	r11, r8
	bne	f168
	cmp	r12, r9
	bne	f168
	cmp	r13, r15
	bne	f168
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f169
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f169
	cmp	r11, r8
	bne	f169
	cmp	r12, r9
	bne	f169
	cmp	r13, r15
	bne	f169
	cmp	r1, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f170
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f170
	cmp	r11, r8
	bne	f170
	cmp	r12, r9
	bne	f170
	cmp	r13, r15
	bne	f170
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f171
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f171
	cmp	r11, r8
	bne	f171
	cmp	r12, r9
	bne	f171
	cmp	r13, r15
	bne	f171
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f172
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f172
	cmp	r11, r8
	bne	f172
	cmp	r12, r9
	bne	f172
	cmp	r13, r15
	bne	f172
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f173
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f173
	cmp	r11, r8
	bne	f173
	cmp	r12, r9
	bne	f173
	cmp	r13, r15
	bne	f173
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f174
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f174
	cmp	r11, r8
	bne	f174
	cmp	r12, r9
	bne	f174
	cmp	r13, r15
	bne	f174
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f175
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f175
	cmp	r11, r8
	bne	f175
	cmp	r12, r9
	bne	f175
	cmp	r13, r15
	bne	f175
	cmp	r5, r1
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f176
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f176
	cmp	r11, r8
	bne	f176
	cmp	r12, r9
	bne	f176
	cmp	r13, r15
	bne	f176
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f177
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f177
	cmp	r11, r8
	bne	f177
	cmp	r12, r9
	bne	f177
	cmp	r13, r15
	bne	f177
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f178
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f178
	cmp	r11, r8
	bne	f178
	cmp	r12, r9
	bne	f178
	cmp	r13, r15
	bne	f178
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f179
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f179
	cmp	r11, r8
	bne	f179
	cmp	r12, r9
	bne	f179
	cmp	r13, r15
	bne	f179
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f180
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f180
	cmp	r11, r8
	bne	f180
	cmp	r12, r9
	bne	f180
	cmp	r13, r15
	bne	f180
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f181
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f181
	cmp	r11, r8
	bne	f181
	cmp	r12, r9
	bne	f181
	cmp	r13, r15
	bne	f181
	cmp	r1, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f182
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f182
	cmp	r11, r8
	bne	f182
	cmp	r12, r9
	bne	f182
	cmp	r13, r15
	bne	f182
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f183
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f183
	cmp	r11, r8
	bne	f183
	cmp	r12, r9
	bne	f183
	cmp	r13, r15
	bne	f183
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f184
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f184
	cmp	r11, r8
	bne	f184
	cmp	r12, r9
	bne	f184
	cmp	r13, r15
	bne	f184
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f185
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f185
	cmp	r11, r8
	bne	f185
	cmp	r12, r9
	bne	f185
	cmp	r13, r15
	bne	f185
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f186
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f186
	cmp	r11, r8
	bne	f186
	cmp	r12, r9
	bne	f186
	cmp	r13, r15
	bne	f186
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f187
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f187
	cmp	r11, r8
	bne	f187
	cmp	r12, r9
	bne	f187
	cmp	r13, r15
	bne	f187
	cmp	r5, r4
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f188
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f188
	cmp	r11, r8
	bne	f188
	cmp	r12, r9
	bne	f188
	cmp	r13, r15
	bne	f188
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f189
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f189
	cmp	r11, r8
	bne	f189
	cmp	r12, r9
	bne	f189
	cmp	r13, r15
	bne	f189
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f190
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f190
	cmp	r11, r8
	bne	f190
	cmp	r12, r9
	bne	f190
	cmp	r13, r15
	bne	f190
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f191
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f191
	cmp	r11, r8
	bne	f191
	cmp	r12, r9
	bne	f191
	cmp	r13, r15
	bne	f191
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f192
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f192
	cmp	r11, r8
	bne	f192
	cmp	r12, r9
	bne	f192
	cmp	r13, r15
	bne	f192
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f193
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f193
	cmp	r11, r8
	bne	f193
	cmp	r12, r9
	bne	f193
	cmp	r13, r15
	bne	f193
	cmp	r6, r5
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f194
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f194
	cmp	r11, r8
	bne	f194
	cmp	r12, r9
	bne	f194
	cmp	r13, r15
	bne	f194
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r5, r1, 1f
	br	f195
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f195
	cmp	r11, r8
	bne	f195
	cmp	r12, r9
	bne	f195
	cmp	r13, r15
	bne	f195
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r5, r1, f196
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f196
	cmp	r11, r8
	bne	f196
	cmp	r12, r9
	bne	f196
	cmp	r13, r15
	bne	f196
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r1, r2, 1f
	br	f197
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f197
	cmp	r11, r8
	bne	f197
	cmp	r12, r9
	bne	f197
	cmp	r13, r15
	bne	f197
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r1, r2, f198
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f198
	cmp	r11, r8
	bne	f198
	cmp	r12, r9
	bne	f198
	cmp	r13, r15
	bne	f198
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbne	r3, r1, 1f
	br	f199
1:
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f199
	cmp	r11, r8
	bne	f199
	cmp	r12, r9
	bne	f199
	cmp	r13, r15
	bne	f199
	cmp	r5, r6
	set	ne, r10
	set	cs, r11
	set	vs, r12
	set	mi, r13
	cbeq	r3, r1, f200
	set	ne, r7
	set	cs, r8
	set	vs, r9
	set	mi, r15
	cmp	r10, r7
	bne	f200
	cmp	r11, r8
	bne	f200
	cmp	r12, r9
	bne	f200
	cmp	r13, r15
	bne	f200
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f3:	movq	#3, r0
	trap	#0
f4:	movq	#4, r0
	trap	#0
f5:	movq	#5, r0
	trap	#0
f6:	movq	#6, r0
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
f17:	movq	#17, r0
	trap	#0
f18:	movq	#18, r0
	trap	#0
f19:	movq	#19, r0
	trap	#0
f20:	movq	#20, r0
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
f31:	movq	#31, r0
	trap	#0
f32:	movq	#32, r0
	trap	#0
f33:	movq	#33, r0
	trap	#0
f34:	movq	#34, r0
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
f45:	movq	#45, r0
	trap	#0
f46:	movq	#46, r0
	trap	#0
f47:	movq	#47, r0
	trap	#0
f48:	movq	#48, r0
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
f59:	movq	#59, r0
	trap	#0
f60:	movq	#60, r0
	trap	#0
f61:	movq	#61, r0
	trap	#0
f62:	movq	#62, r0
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
f73:	movq	#73, r0
	trap	#0
f74:	movq	#74, r0
	trap	#0
f75:	movq	#75, r0
	trap	#0
f76:	movq	#76, r0
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
f87:	movq	#87, r0
	trap	#0
f88:	movq	#88, r0
	trap	#0
f89:	movq	#89, r0
	trap	#0
f90:	movq	#90, r0
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
f101:	movq	#101, r0
	trap	#0
f102:	movq	#102, r0
	trap	#0
f103:	movq	#103, r0
	trap	#0
f104:	movq	#104, r0
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
f115:	movq	#115, r0
	trap	#0
f116:	movq	#116, r0
	trap	#0
f117:	movq	#117, r0
	trap	#0
f118:	movq	#118, r0
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
f129:	movq	#129, r0
	trap	#0
f130:	movq	#130, r0
	trap	#0
f131:	movq	#131, r0
	trap	#0
f132:	movq	#132, r0
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
f141:	movq	#141, r0
	trap	#0
f142:	movq	#142, r0
	trap	#0
f143:	movq	#143, r0
	trap	#0
f144:	movq	#144, r0
	trap	#0
f145:	movq	#145, r0
	trap	#0
f146:	movq	#146, r0
	trap	#0
f147:	movq	#147, r0
	trap	#0
f148:	movq	#148, r0
	trap	#0
f149:	movq	#149, r0
	trap	#0
f150:	movq	#150, r0
	trap	#0
f151:	movq	#151, r0
	trap	#0
f152:	movq	#152, r0
	trap	#0
f153:	movq	#153, r0
	trap	#0
f154:	movq	#154, r0
	trap	#0
f155:	movq	#155, r0
	trap	#0
f156:	movq	#156, r0
	trap	#0
f157:	movq	#157, r0
	trap	#0
f158:	movq	#158, r0
	trap	#0
f159:	movq	#159, r0
	trap	#0
f160:	movq	#160, r0
	trap	#0
f161:	movq	#161, r0
	trap	#0
f162:	movq	#162, r0
	trap	#0
f163:	movq	#163, r0
	trap	#0
f164:	movq	#164, r0
	trap	#0
f165:	movq	#165, r0
	trap	#0
f166:	movq	#166, r0
	trap	#0
f167:	movq	#167, r0
	trap	#0
f168:	movq	#168, r0
	trap	#0
f169:	movq	#169, r0
	trap	#0
f170:	movq	#170, r0
	trap	#0
f171:	movq	#171, r0
	trap	#0
f172:	movq	#172, r0
	trap	#0
f173:	movq	#173, r0
	trap	#0
f174:	movq	#174, r0
	trap	#0
f175:	movq	#175, r0
	trap	#0
f176:	movq	#176, r0
	trap	#0
f177:	movq	#177, r0
	trap	#0
f178:	movq	#178, r0
	trap	#0
f179:	movq	#179, r0
	trap	#0
f180:	movq	#180, r0
	trap	#0
f181:	movq	#181, r0
	trap	#0
f182:	movq	#182, r0
	trap	#0
f183:	movq	#183, r0
	trap	#0
f184:	movq	#184, r0
	trap	#0
f185:	movq	#185, r0
	trap	#0
f186:	movq	#186, r0
	trap	#0
f187:	movq	#187, r0
	trap	#0
f188:	movq	#188, r0
	trap	#0
f189:	movq	#189, r0
	trap	#0
f190:	movq	#190, r0
	trap	#0
f191:	movq	#191, r0
	trap	#0
f192:	movq	#192, r0
	trap	#0
f193:	movq	#193, r0
	trap	#0
f194:	movq	#194, r0
	trap	#0
f195:	movq	#195, r0
	trap	#0
f196:	movq	#196, r0
	trap	#0
f197:	movq	#197, r0
	trap	#0
f198:	movq	#198, r0
	trap	#0
f199:	movq	#199, r0
	trap	#0
f200:	movq	#200, r0
	trap	#0
