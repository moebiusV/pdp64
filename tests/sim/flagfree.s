; moves, loads and stores (every width, register, memory, immediate and literal-pool forms, and their one-parcel abbreviations), lea and set write no flag
; (errata 39): a cmp sets the flags (5 - 7: N and C set, Z clear; 7 - 7: Z set), the instruction runs on a zero, a negative and a positive value, and the
; flags read back with mfps are what the cmp left.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	movq	#5, r1
	movq	#7, r2
	lea	buf, r5
	movq	#0, r11
	movq	#-1, r12
	movq	#5, r13
	sub	#64, sp
	cmp	r1, r2
	mfps	r10
	nop
	movq	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f1
	cmp	r1, r2
	mfps	r10
	nop
	movq	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f2
	cmp	r1, r2
	mfps	r10
	nop
	movq	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f3
	cmp	r1, r2
	mfps	r10
	nop
	movq	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f4
	cmp	r1, r2
	mfps	r10
	nop
	movq	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f5
	cmp	r1, r2
	mfps	r10
	nop
	movq	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f6
	cmp	r1, r2
	mfps	r10
	nop
	movl	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f7
	cmp	r1, r2
	mfps	r10
	nop
	movl	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f8
	cmp	r1, r2
	mfps	r10
	nop
	movl	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f9
	cmp	r1, r2
	mfps	r10
	nop
	movl	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f10
	cmp	r1, r2
	mfps	r10
	nop
	movl	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f11
	cmp	r1, r2
	mfps	r10
	nop
	movl	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f12
	cmp	r1, r2
	mfps	r10
	nop
	movw	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f13
	cmp	r1, r2
	mfps	r10
	nop
	movw	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f14
	cmp	r1, r2
	mfps	r10
	nop
	movw	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f15
	cmp	r1, r2
	mfps	r10
	nop
	movw	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f16
	cmp	r1, r2
	mfps	r10
	nop
	movw	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f17
	cmp	r1, r2
	mfps	r10
	nop
	movw	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f18
	cmp	r1, r2
	mfps	r10
	nop
	movb	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f19
	cmp	r1, r2
	mfps	r10
	nop
	movb	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f20
	cmp	r1, r2
	mfps	r10
	nop
	movb	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f21
	cmp	r1, r2
	mfps	r10
	nop
	movb	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f22
	cmp	r1, r2
	mfps	r10
	nop
	movb	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f23
	cmp	r1, r2
	mfps	r10
	nop
	movb	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f24
	cmp	r1, r2
	mfps	r10
	nop
	movzl	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f25
	cmp	r1, r2
	mfps	r10
	nop
	movzl	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f26
	cmp	r1, r2
	mfps	r10
	nop
	movzl	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f27
	cmp	r1, r2
	mfps	r10
	nop
	movzl	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f28
	cmp	r1, r2
	mfps	r10
	nop
	movzl	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f29
	cmp	r1, r2
	mfps	r10
	nop
	movzl	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f30
	cmp	r1, r2
	mfps	r10
	nop
	movzw	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f31
	cmp	r1, r2
	mfps	r10
	nop
	movzw	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f32
	cmp	r1, r2
	mfps	r10
	nop
	movzw	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f33
	cmp	r1, r2
	mfps	r10
	nop
	movzw	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f34
	cmp	r1, r2
	mfps	r10
	nop
	movzw	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f35
	cmp	r1, r2
	mfps	r10
	nop
	movzw	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f36
	cmp	r1, r2
	mfps	r10
	nop
	movzb	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f37
	cmp	r1, r2
	mfps	r10
	nop
	movzb	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f38
	cmp	r1, r2
	mfps	r10
	nop
	movzb	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f39
	cmp	r1, r2
	mfps	r10
	nop
	movzb	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f40
	cmp	r1, r2
	mfps	r10
	nop
	movzb	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f41
	cmp	r1, r2
	mfps	r10
	nop
	movzb	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f42
	cmp	r1, r2
	mfps	r10
	nop
	movq	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f43
	cmp	r1, r2
	mfps	r10
	nop
	movq	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f44
	cmp	r1, r2
	mfps	r10
	nop
	movq	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f45
	cmp	r1, r2
	mfps	r10
	nop
	movl	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f46
	cmp	r1, r2
	mfps	r10
	nop
	movl	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f47
	cmp	r1, r2
	mfps	r10
	nop
	movl	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f48
	cmp	r1, r2
	mfps	r10
	nop
	movw	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f49
	cmp	r1, r2
	mfps	r10
	nop
	movw	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f50
	cmp	r1, r2
	mfps	r10
	nop
	movw	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f51
	cmp	r1, r2
	mfps	r10
	nop
	movb	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f52
	cmp	r1, r2
	mfps	r10
	nop
	movb	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f53
	cmp	r1, r2
	mfps	r10
	nop
	movb	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f54
	cmp	r1, r2
	mfps	r10
	nop
	movq	#0, r3
	mfps	r9
	cmp	r9, r10
	bne	f55
	cmp	r1, r2
	mfps	r10
	nop
	movq	#-1, r3
	mfps	r9
	cmp	r9, r10
	bne	f56
	cmp	r1, r2
	mfps	r10
	nop
	movq	#7, r3
	mfps	r9
	cmp	r9, r10
	bne	f57
	cmp	r1, r2
	mfps	r10
	nop
	movq	#-8, r3
	mfps	r9
	cmp	r9, r10
	bne	f58
	cmp	r1, r2
	mfps	r10
	nop
	movq	#1000, r3
	mfps	r9
	cmp	r9, r10
	bne	f59
	cmp	r1, r2
	mfps	r10
	nop
	movq	=0x123456789ABC, r3
	mfps	r9
	cmp	r9, r10
	bne	f60
	cmp	r1, r2
	mfps	r10
	nop
	movq	=0, r3
	mfps	r9
	cmp	r9, r10
	bne	f61
	cmp	r1, r2
	mfps	r10
	nop
	movq	=-1, r3
	mfps	r9
	cmp	r9, r10
	bne	f62
	cmp	r1, r2
	mfps	r10
	nop
	movq	(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f63
	cmp	r1, r2
	mfps	r10
	nop
	movq	r12, (r5)
	mfps	r9
	cmp	r9, r10
	bne	f64
	cmp	r1, r2
	mfps	r10
	nop
	movq	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f65
	cmp	r1, r2
	mfps	r10
	nop
	movq	r11, 16(sp)
	mfps	r9
	cmp	r9, r10
	bne	f66
	cmp	r1, r2
	mfps	r10
	nop
	movq	16(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f67
	cmp	r1, r2
	mfps	r10
	nop
	movl	8(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f68
	cmp	r1, r2
	mfps	r10
	nop
	movl	r12, 4(sp)
	mfps	r9
	cmp	r9, r10
	bne	f69
	cmp	r1, r2
	mfps	r10
	nop
	lea	24(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f70
	cmp	r1, r2
	mfps	r10
	nop
	lea	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f71
	cmp	r1, r2
	mfps	r10
	nop
	set	eq, r3
	mfps	r9
	cmp	r9, r10
	bne	f72
	cmp	r1, r2
	mfps	r10
	nop
	set	mi, r3
	mfps	r9
	cmp	r9, r10
	bne	f73
	cmp	r2, r2
	mfps	r10
	nop
	movq	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f74
	cmp	r2, r2
	mfps	r10
	nop
	movq	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f75
	cmp	r2, r2
	mfps	r10
	nop
	movq	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f76
	cmp	r2, r2
	mfps	r10
	nop
	movq	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f77
	cmp	r2, r2
	mfps	r10
	nop
	movq	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f78
	cmp	r2, r2
	mfps	r10
	nop
	movq	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f79
	cmp	r2, r2
	mfps	r10
	nop
	movl	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f80
	cmp	r2, r2
	mfps	r10
	nop
	movl	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f81
	cmp	r2, r2
	mfps	r10
	nop
	movl	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f82
	cmp	r2, r2
	mfps	r10
	nop
	movl	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f83
	cmp	r2, r2
	mfps	r10
	nop
	movl	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f84
	cmp	r2, r2
	mfps	r10
	nop
	movl	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f85
	cmp	r2, r2
	mfps	r10
	nop
	movw	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f86
	cmp	r2, r2
	mfps	r10
	nop
	movw	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f87
	cmp	r2, r2
	mfps	r10
	nop
	movw	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f88
	cmp	r2, r2
	mfps	r10
	nop
	movw	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f89
	cmp	r2, r2
	mfps	r10
	nop
	movw	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f90
	cmp	r2, r2
	mfps	r10
	nop
	movw	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f91
	cmp	r2, r2
	mfps	r10
	nop
	movb	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f92
	cmp	r2, r2
	mfps	r10
	nop
	movb	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f93
	cmp	r2, r2
	mfps	r10
	nop
	movb	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f94
	cmp	r2, r2
	mfps	r10
	nop
	movb	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f95
	cmp	r2, r2
	mfps	r10
	nop
	movb	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f96
	cmp	r2, r2
	mfps	r10
	nop
	movb	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f97
	cmp	r2, r2
	mfps	r10
	nop
	movzl	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f98
	cmp	r2, r2
	mfps	r10
	nop
	movzl	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f99
	cmp	r2, r2
	mfps	r10
	nop
	movzl	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f100
	cmp	r2, r2
	mfps	r10
	nop
	movzl	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f101
	cmp	r2, r2
	mfps	r10
	nop
	movzl	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f102
	cmp	r2, r2
	mfps	r10
	nop
	movzl	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f103
	cmp	r2, r2
	mfps	r10
	nop
	movzw	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f104
	cmp	r2, r2
	mfps	r10
	nop
	movzw	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f105
	cmp	r2, r2
	mfps	r10
	nop
	movzw	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f106
	cmp	r2, r2
	mfps	r10
	nop
	movzw	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f107
	cmp	r2, r2
	mfps	r10
	nop
	movzw	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f108
	cmp	r2, r2
	mfps	r10
	nop
	movzw	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f109
	cmp	r2, r2
	mfps	r10
	nop
	movzb	0(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f110
	cmp	r2, r2
	mfps	r10
	nop
	movzb	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f111
	cmp	r2, r2
	mfps	r10
	nop
	movzb	16(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f112
	cmp	r2, r2
	mfps	r10
	nop
	movzb	r11, r3
	mfps	r9
	cmp	r9, r10
	bne	f113
	cmp	r2, r2
	mfps	r10
	nop
	movzb	r12, r3
	mfps	r9
	cmp	r9, r10
	bne	f114
	cmp	r2, r2
	mfps	r10
	nop
	movzb	r13, r3
	mfps	r9
	cmp	r9, r10
	bne	f115
	cmp	r2, r2
	mfps	r10
	nop
	movq	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f116
	cmp	r2, r2
	mfps	r10
	nop
	movq	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f117
	cmp	r2, r2
	mfps	r10
	nop
	movq	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f118
	cmp	r2, r2
	mfps	r10
	nop
	movl	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f119
	cmp	r2, r2
	mfps	r10
	nop
	movl	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f120
	cmp	r2, r2
	mfps	r10
	nop
	movl	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f121
	cmp	r2, r2
	mfps	r10
	nop
	movw	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f122
	cmp	r2, r2
	mfps	r10
	nop
	movw	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f123
	cmp	r2, r2
	mfps	r10
	nop
	movw	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f124
	cmp	r2, r2
	mfps	r10
	nop
	movb	r11, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f125
	cmp	r2, r2
	mfps	r10
	nop
	movb	r12, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f126
	cmp	r2, r2
	mfps	r10
	nop
	movb	r13, 24(r5)
	mfps	r9
	cmp	r9, r10
	bne	f127
	cmp	r2, r2
	mfps	r10
	nop
	movq	#0, r3
	mfps	r9
	cmp	r9, r10
	bne	f128
	cmp	r2, r2
	mfps	r10
	nop
	movq	#-1, r3
	mfps	r9
	cmp	r9, r10
	bne	f129
	cmp	r2, r2
	mfps	r10
	nop
	movq	#7, r3
	mfps	r9
	cmp	r9, r10
	bne	f130
	cmp	r2, r2
	mfps	r10
	nop
	movq	#-8, r3
	mfps	r9
	cmp	r9, r10
	bne	f131
	cmp	r2, r2
	mfps	r10
	nop
	movq	#1000, r3
	mfps	r9
	cmp	r9, r10
	bne	f132
	cmp	r2, r2
	mfps	r10
	nop
	movq	=0x123456789ABC, r3
	mfps	r9
	cmp	r9, r10
	bne	f133
	cmp	r2, r2
	mfps	r10
	nop
	movq	=0, r3
	mfps	r9
	cmp	r9, r10
	bne	f134
	cmp	r2, r2
	mfps	r10
	nop
	movq	=-1, r3
	mfps	r9
	cmp	r9, r10
	bne	f135
	cmp	r2, r2
	mfps	r10
	nop
	movq	(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f136
	cmp	r2, r2
	mfps	r10
	nop
	movq	r12, (r5)
	mfps	r9
	cmp	r9, r10
	bne	f137
	cmp	r2, r2
	mfps	r10
	nop
	movq	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f138
	cmp	r2, r2
	mfps	r10
	nop
	movq	r11, 16(sp)
	mfps	r9
	cmp	r9, r10
	bne	f139
	cmp	r2, r2
	mfps	r10
	nop
	movq	16(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f140
	cmp	r2, r2
	mfps	r10
	nop
	movl	8(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f141
	cmp	r2, r2
	mfps	r10
	nop
	movl	r12, 4(sp)
	mfps	r9
	cmp	r9, r10
	bne	f142
	cmp	r2, r2
	mfps	r10
	nop
	lea	24(sp), r3
	mfps	r9
	cmp	r9, r10
	bne	f143
	cmp	r2, r2
	mfps	r10
	nop
	lea	8(r5), r3
	mfps	r9
	cmp	r9, r10
	bne	f144
	cmp	r2, r2
	mfps	r10
	nop
	set	eq, r3
	mfps	r9
	cmp	r9, r10
	bne	f145
	cmp	r2, r2
	mfps	r10
	nop
	set	mi, r3
	mfps	r9
	cmp	r9, r10
	bne	f146
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
	.data
	.even
buf:	.quad	0, -1, 5, 0, 0, 0, 0, 0
