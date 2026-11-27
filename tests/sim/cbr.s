; the register-register cbCC (opcode 0x2A): signed and unsigned conditions with equal, less and greater values and the most negative number;
; each condition is checked taken and not taken.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	mov	$5, r1
	mov	$5, r2
	mov	$7, r3
	mov	$-1, r4
	mov	$1, r5
	shl	$15, r5
	shl	$16, r5
	shl	$16, r5
	shl	$16, r5			; r5 = 0x8000000000000000, the most negative number
	mov	$0, r6
	cbne	r1, r2, fail1
	cbeq	r1, r2, 1f
	br	fail2
1:
1:
1:
	cbcc	r1, r2, 1f
	br	fail7
1:
	cbcs	r1, r2, fail8
	cbge	r1, r2, 1f
	br	fail9
1:
	cblt	r1, r2, fail10
	cbgt	r1, r2, fail11
	cble	r1, r2, 1f
	br	fail12
1:
	cbhi	r1, r2, fail13
	cblos	r1, r2, 1f
	br	fail14
1:
	cbne	r1, r3, 1f
	br	fail15
1:
	cbeq	r1, r3, fail16
1:
1:
	cbcc	r1, r3, fail21
	cbcs	r1, r3, 1f
	br	fail22
1:
	cbge	r1, r3, fail23
	cblt	r1, r3, 1f
	br	fail24
1:
	cbgt	r1, r3, fail25
	cble	r1, r3, 1f
	br	fail26
1:
	cbhi	r1, r3, fail27
	cblos	r1, r3, 1f
	br	fail28
1:
	cbne	r3, r1, 1f
	br	fail29
1:
	cbeq	r3, r1, fail30
1:
1:
	cbcc	r3, r1, 1f
	br	fail35
1:
	cbcs	r3, r1, fail36
	cbge	r3, r1, 1f
	br	fail37
1:
	cblt	r3, r1, fail38
	cbgt	r3, r1, 1f
	br	fail39
1:
	cble	r3, r1, fail40
	cbhi	r3, r1, 1f
	br	fail41
1:
	cblos	r3, r1, fail42
	cbne	r4, r1, 1f
	br	fail43
1:
	cbeq	r4, r1, fail44
1:
1:
	cbcc	r4, r1, 1f
	br	fail49
1:
	cbcs	r4, r1, fail50
	cbge	r4, r1, fail51
	cblt	r4, r1, 1f
	br	fail52
1:
	cbgt	r4, r1, fail53
	cble	r4, r1, 1f
	br	fail54
1:
	cbhi	r4, r1, 1f
	br	fail55
1:
	cblos	r4, r1, fail56
	cbne	r1, r4, 1f
	br	fail57
1:
	cbeq	r1, r4, fail58
1:
1:
	cbcc	r1, r4, fail63
	cbcs	r1, r4, 1f
	br	fail64
1:
	cbge	r1, r4, 1f
	br	fail65
1:
	cblt	r1, r4, fail66
	cbgt	r1, r4, 1f
	br	fail67
1:
	cble	r1, r4, fail68
	cbhi	r1, r4, fail69
	cblos	r1, r4, 1f
	br	fail70
1:
	cbne	r5, r1, 1f
	br	fail71
1:
	cbeq	r5, r1, fail72
1:
1:
	cbcc	r5, r1, 1f
	br	fail77
1:
	cbcs	r5, r1, fail78
	cbge	r5, r1, fail79
	cblt	r5, r1, 1f
	br	fail80
1:
	cbgt	r5, r1, fail81
	cble	r5, r1, 1f
	br	fail82
1:
	cbhi	r5, r1, 1f
	br	fail83
1:
	cblos	r5, r1, fail84
	cbne	r1, r5, 1f
	br	fail85
1:
	cbeq	r1, r5, fail86
1:
1:
	cbcc	r1, r5, fail91
	cbcs	r1, r5, 1f
	br	fail92
1:
	cbge	r1, r5, 1f
	br	fail93
1:
	cblt	r1, r5, fail94
	cbgt	r1, r5, 1f
	br	fail95
1:
	cble	r1, r5, fail96
	cbhi	r1, r5, fail97
	cblos	r1, r5, 1f
	br	fail98
1:
	cbne	r5, r4, 1f
	br	fail99
1:
	cbeq	r5, r4, fail100
1:
1:
	cbcc	r5, r4, fail105
	cbcs	r5, r4, 1f
	br	fail106
1:
	cbge	r5, r4, fail107
	cblt	r5, r4, 1f
	br	fail108
1:
	cbgt	r5, r4, fail109
	cble	r5, r4, 1f
	br	fail110
1:
	cbhi	r5, r4, fail111
	cblos	r5, r4, 1f
	br	fail112
1:
	cbne	r6, r5, 1f
	br	fail113
1:
	cbeq	r6, r5, fail114
1:
1:
	cbcc	r6, r5, fail119
	cbcs	r6, r5, 1f
	br	fail120
1:
	cbge	r6, r5, 1f
	br	fail121
1:
	cblt	r6, r5, fail122
	cbgt	r6, r5, 1f
	br	fail123
1:
	cble	r6, r5, fail124
	cbhi	r6, r5, fail125
	cblos	r6, r5, 1f
	br	fail126
1:
	cbne	r5, r6, 1f
	br	fail127
1:
	cbeq	r5, r6, fail128
1:
1:
	cbcc	r5, r6, 1f
	br	fail133
1:
	cbcs	r5, r6, fail134
	cbge	r5, r6, fail135
	cblt	r5, r6, 1f
	br	fail136
1:
	cbgt	r5, r6, fail137
	cble	r5, r6, 1f
	br	fail138
1:
	cbhi	r5, r6, 1f
	br	fail139
1:
	cblos	r5, r6, fail140
	mov	$0, r0
	trap	$0
fail1:	mov	$1, r0
	trap	$0
fail2:	mov	$2, r0
	trap	$0
fail7:	mov	$7, r0
	trap	$0
fail8:	mov	$8, r0
	trap	$0
fail9:	mov	$9, r0
	trap	$0
fail10:	mov	$10, r0
	trap	$0
fail11:	mov	$11, r0
	trap	$0
fail12:	mov	$12, r0
	trap	$0
fail13:	mov	$13, r0
	trap	$0
fail14:	mov	$14, r0
	trap	$0
fail15:	mov	$15, r0
	trap	$0
fail16:	mov	$16, r0
	trap	$0
fail21:	mov	$21, r0
	trap	$0
fail22:	mov	$22, r0
	trap	$0
fail23:	mov	$23, r0
	trap	$0
fail24:	mov	$24, r0
	trap	$0
fail25:	mov	$25, r0
	trap	$0
fail26:	mov	$26, r0
	trap	$0
fail27:	mov	$27, r0
	trap	$0
fail28:	mov	$28, r0
	trap	$0
fail29:	mov	$29, r0
	trap	$0
fail30:	mov	$30, r0
	trap	$0
fail35:	mov	$35, r0
	trap	$0
fail36:	mov	$36, r0
	trap	$0
fail37:	mov	$37, r0
	trap	$0
fail38:	mov	$38, r0
	trap	$0
fail39:	mov	$39, r0
	trap	$0
fail40:	mov	$40, r0
	trap	$0
fail41:	mov	$41, r0
	trap	$0
fail42:	mov	$42, r0
	trap	$0
fail43:	mov	$43, r0
	trap	$0
fail44:	mov	$44, r0
	trap	$0
fail49:	mov	$49, r0
	trap	$0
fail50:	mov	$50, r0
	trap	$0
fail51:	mov	$51, r0
	trap	$0
fail52:	mov	$52, r0
	trap	$0
fail53:	mov	$53, r0
	trap	$0
fail54:	mov	$54, r0
	trap	$0
fail55:	mov	$55, r0
	trap	$0
fail56:	mov	$56, r0
	trap	$0
fail57:	mov	$57, r0
	trap	$0
fail58:	mov	$58, r0
	trap	$0
fail63:	mov	$63, r0
	trap	$0
fail64:	mov	$64, r0
	trap	$0
fail65:	mov	$65, r0
	trap	$0
fail66:	mov	$66, r0
	trap	$0
fail67:	mov	$67, r0
	trap	$0
fail68:	mov	$68, r0
	trap	$0
fail69:	mov	$69, r0
	trap	$0
fail70:	mov	$70, r0
	trap	$0
fail71:	mov	$71, r0
	trap	$0
fail72:	mov	$72, r0
	trap	$0
fail77:	mov	$77, r0
	trap	$0
fail78:	mov	$78, r0
	trap	$0
fail79:	mov	$79, r0
	trap	$0
fail80:	mov	$80, r0
	trap	$0
fail81:	mov	$81, r0
	trap	$0
fail82:	mov	$82, r0
	trap	$0
fail83:	mov	$83, r0
	trap	$0
fail84:	mov	$84, r0
	trap	$0
fail85:	mov	$85, r0
	trap	$0
fail86:	mov	$86, r0
	trap	$0
fail91:	mov	$91, r0
	trap	$0
fail92:	mov	$92, r0
	trap	$0
fail93:	mov	$93, r0
	trap	$0
fail94:	mov	$94, r0
	trap	$0
fail95:	mov	$95, r0
	trap	$0
fail96:	mov	$96, r0
	trap	$0
fail97:	mov	$97, r0
	trap	$0
fail98:	mov	$98, r0
	trap	$0
fail99:	mov	$99, r0
	trap	$0
fail100:	mov	$100, r0
	trap	$0
fail105:	mov	$105, r0
	trap	$0
fail106:	mov	$106, r0
	trap	$0
fail107:	mov	$107, r0
	trap	$0
fail108:	mov	$108, r0
	trap	$0
fail109:	mov	$109, r0
	trap	$0
fail110:	mov	$110, r0
	trap	$0
fail111:	mov	$111, r0
	trap	$0
fail112:	mov	$112, r0
	trap	$0
fail113:	mov	$113, r0
	trap	$0
fail114:	mov	$114, r0
	trap	$0
fail119:	mov	$119, r0
	trap	$0
fail120:	mov	$120, r0
	trap	$0
fail121:	mov	$121, r0
	trap	$0
fail122:	mov	$122, r0
	trap	$0
fail123:	mov	$123, r0
	trap	$0
fail124:	mov	$124, r0
	trap	$0
fail125:	mov	$125, r0
	trap	$0
fail126:	mov	$126, r0
	trap	$0
fail127:	mov	$127, r0
	trap	$0
fail128:	mov	$128, r0
	trap	$0
fail133:	mov	$133, r0
	trap	$0
fail134:	mov	$134, r0
	trap	$0
fail135:	mov	$135, r0
	trap	$0
fail136:	mov	$136, r0
	trap	$0
fail137:	mov	$137, r0
	trap	$0
fail138:	mov	$138, r0
	trap	$0
fail139:	mov	$139, r0
	trap	$0
fail140:	mov	$140, r0
	trap	$0
