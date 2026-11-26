; sign and zero extension of every width, from a register, from memory and from an immediate; partial stores
	.text
	.globl	_start
_start:
	movq	#0x1234, r1
	shl	#16, r1
	bis	#0x5678, r1
	shl	#16, r1
	bis	#0x9ABC, r1
	shl	#16, r1
	bis	#0xDEF0, r1
	movb	r1, r2
	cbne r2, #-16, f1
	movzb	r1, r2
	cbne r2, #240, f2
	movw	r1, r2
	cbne r2, #-8464, f3
	movzw	r1, r2
	movq	=57072, r12	; register source: movzw 
	cbne	r2, r12, f4
	movl	r1, r2
	movq	=-1698898192, r12	; register source: movl low long 0x9ABCDEF0
	cbne	r2, r12, f5
	movzl	r1, r2
	movq	#39612, r12
	shl	#16, r12
	bis	#57072, r12
	cbne r2, r12, f6
	movq	r1, r2
	cbne r2, r1, f7
	movq	#0, r3
	movq	#0, r3
	bis	#127, r3
	movq	#-1, r4
	shl	#8, r4
	bis	r4, r3
	movb	r3, r2
	cbne r2, #127, f8
	movzb	r3, r2
	cbne r2, #127, f9
	movq	#0, r3
	movq	#0, r3
	bis	#128, r3
	movq	#-1, r4
	shl	#8, r4
	bis	r4, r3
	movb	r3, r2
	cbne r2, #-128, f10
	movzb	r3, r2
	cbne r2, #128, f11
	movq	#0, r3
	movq	#0, r3
	bis	#32767, r3
	movq	#-1, r4
	shl	#16, r4
	bis	r4, r3
	movw	r3, r2
	cbne r2, #32767, f12
	movzw	r3, r2
	cbne r2, #32767, f13
	movq	#0, r3
	movq	#0, r3
	bis	#32768, r3
	movq	#-1, r4
	shl	#16, r4
	bis	r4, r3
	movw	r3, r2
	cbne r2, #-32768, f14
	movzw	r3, r2
	movq	=32768, r12	; boundary 0x8000 movzw
	cbne	r2, r12, f15
	movq	#32767, r3
	shl	#16, r3
	bis	#65535, r3
	movq	#-1, r4
	shl	#32, r4
	bis	r4, r3
	movl	r3, r2
	movq	=2147483647, r12	; boundary 0x7FFFFFFF movl
	cbne	r2, r12, f16
	movzl	r3, r2
	movq	=2147483647, r12	; boundary 0x7FFFFFFF movzl
	cbne	r2, r12, f17
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	movq	#-1, r4
	shl	#32, r4
	bis	r4, r3
	movl	r3, r2
	movq	=-2147483648, r12	; boundary 0x80000000 movl
	cbne	r2, r12, f18
	movzl	r3, r2
	movq	#32768, r12
	shl	#16, r12
	bis	#0, r12
	cbne r2, r12, f19
	movq	r1, r2
	movzl	r2, r2
	movq	#39612, r12
	shl	#16, r12
	bis	#57072, r12
	cbne r2, r12, f20
	movq	r1, r2
	movl	r2, r2
	movq	=-1698898192, r12	; movl r,r sign-extends
	cbne	r2, r12, f21
	movq	r1, r2
	movzb	r2, r2
	cbne r2, #240, f22
	lea	pat, r5
	movb	0(r5), r2
	cbne r2, #-16, f23
	lea	pat, r5
	movb	1(r5), r2
	cbne r2, #-34, f24
	lea	pat, r5
	movzb	1(r5), r2
	cbne r2, #222, f25
	lea	pat, r5
	movw	0(r5), r2
	cbne r2, #-8464, f26
	lea	pat, r5
	movw	2(r5), r2
	cbne r2, #-25924, f27
	lea	pat, r5
	movzw	2(r5), r2
	movq	=39612, r12	; memory source: movzw at +2
	cbne	r2, r12, f28
	lea	pat, r5
	movl	0(r5), r2
	movq	=-1698898192, r12	; memory source: movl at +0
	cbne	r2, r12, f29
	lea	pat, r5
	movl	4(r5), r2
	movq	=305419896, r12	; memory source: movl at +4
	cbne	r2, r12, f30
	lea	pat, r5
	movzl	0(r5), r2
	movq	#39612, r12
	shl	#16, r12
	bis	#57072, r12
	cbne r2, r12, f31
	lea	pat, r5
	movzl	4(r5), r2
	movq	=305419896, r12	; memory source: movzl at +4
	cbne	r2, r12, f32
	movb	#-1, r2
	cbne r2, #-1, f33
	movzb	#-1, r2
	cbne r2, #255, f34
	movw	#-2, r2
	cbne r2, #-2, f35
	movzw	#-2, r2
	movq	=65534, r12	; immediate source: movzw #-2
	cbne	r2, r12, f36
	movzw	#-1, r2
	movq	=65535, r12	; immediate source: movzw #-1
	cbne	r2, r12, f37
	movl	#-3, r2
	cbne r2, #-3, f38
	movzl	#-3, r2
	movq	#65535, r12
	shl	#16, r12
	bis	#65533, r12
	cbne r2, r12, f39
	movzl	#-1, r2
	movq	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cbne r2, r12, f40
	lea	out, r5
	movq	#-1, r6
	movb	r6, 0(r5)
	movq	0(r5), r2
	movq	exp1, r12	; movb stores one byte, the others stay
	cbne	r2, r12, f41
	movw	r6, 8(r5)
	movq	8(r5), r2
	movq	exp2, r12	; movw stores two bytes
	cbne	r2, r12, f42
	movq	#0x1234, r6
	shl	#16, r6
	bis	#0x5678, r6
	movl	r6, 8(r5)
	movq	8(r5), r2
	movq	exp3, r12	; movl stores four bytes
	cbne	r2, r12, f43
; the sign and zero extension show in the register (checks 44 to 49)
	movq	#128, r3
	movb	r3, r2
	cbne r2, #-128, f44
	movq	#128, r3
	movzb	r3, r2
	cbne r2, #128, f45
	movq	#0, r3
	movb	r3, r2
	cbne r2, #0, f46
	movq	#0, r3
	movzw	r3, r2
	cbne r2, #0, f47
	movq	#32768, r3
	shl	#16, r3
	movl	r3, r2
	movq	=-2147483648, r12	; and it is sign-extended
	cbne r2, r12, f48
	movq	#32768, r3
	shl	#16, r3
	movzl	r3, r2
	cbne r2, r3, f49
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
	.data
	.even
pat:	.byte	0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12
out:	.quad	0x1111111111111111, 0x2222222222222222
exp1:	.quad	0x11111111111111FF
exp2:	.quad	0x222222222222FFFF
exp3:	.quad	0x2222222212345678
