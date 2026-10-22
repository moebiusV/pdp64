; page 2: the one-parcel forms (the assembler chooses them for these operands; tests/asm/p2.s checks that it does) execute as the page-1 instruction they abbreviate.
; Expected values hand-worked from the definition of the instructions (sign and zero extension, offsets, widths).  A failed check n exits with n.
	.text
	.globl	_start
_start:
	lea	buf, r5
	movq	(r5), r3
	movq	#4386, r12
	shl	#16, r12
	bis	#13124, r12
	shl	#16, r12
	bis	#35243, r12
	shl	#16, r12
	bis	#52720, r12
	cmp	r3, r12		; 1: movq (r5), r3
	bne	f1
	movl	(r5), r3
	cmp	r3, #-1985229328		; 2: movl (r5), r3
	bne	f2
	movw	(r5), r3
	cmp	r3, #-12816		; 3: movw (r5), r3
	bne	f3
	movb	(r5), r3
	cmp	r3, #-16		; 4: movb (r5), r3
	bne	f4
	movzl	(r5), r3
	movq	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#35243, r12
	shl	#16, r12
	bis	#52720, r12
	cmp	r3, r12		; 5: movzl (r5), r3
	bne	f5
	movzw	(r5), r3
	cmp	r3, #52720		; 6: movzw (r5), r3
	bne	f6
	movzb	(r5), r3
	cmp	r3, #240		; 7: movzb (r5), r3
	bne	f7
	lea	buf+24, r9
	movq	(r9), r4
	cmp	r4, #259		; 8: movq (r9), r4: another register pair
	bne	f8
	movq	(r5), r15
	movq	#4386, r12
	shl	#16, r12
	bis	#13124, r12
	shl	#16, r12
	bis	#35243, r12
	shl	#16, r12
	bis	#52720, r12
	cmp	r15, r12		; 9: movq (r5), r15: rd = r15
	bne	f9
	movq	#65244, r1
	shl	#16, r1
	bis	#47768, r1
	shl	#16, r1
	bis	#30292, r1
	shl	#16, r1
	bis	#12816, r1
	lea	buf+160, r6
	movq	#0x1122, r2
	movq	#34935, r2
	shl	#16, r2
	bis	#26197, r2
	shl	#16, r2
	bis	#17459, r2
	shl	#16, r2
	bis	#8721, r2
	movq	r2, (r6)
	movq	r1, (r6)
	movq	(r6), r3
	movq	#65244, r12
	shl	#16, r12
	bis	#47768, r12
	shl	#16, r12
	bis	#30292, r12
	shl	#16, r12
	bis	#12816, r12
	cmp	r3, r12		; 10: movq r1, (r6) stores 8 byte(s)
	bne	f10
	movq	#65244, r1
	shl	#16, r1
	bis	#47768, r1
	shl	#16, r1
	bis	#30292, r1
	shl	#16, r1
	bis	#12816, r1
	lea	buf+160, r6
	movq	#0x1122, r2
	movq	#34935, r2
	shl	#16, r2
	bis	#26197, r2
	shl	#16, r2
	bis	#17459, r2
	shl	#16, r2
	bis	#8721, r2
	movq	r2, (r6)
	movl	r1, (r6)
	movq	(r6), r3
	movq	#34935, r12
	shl	#16, r12
	bis	#26197, r12
	shl	#16, r12
	bis	#30292, r12
	shl	#16, r12
	bis	#12816, r12
	cmp	r3, r12		; 11: movl r1, (r6) stores 4 byte(s)
	bne	f11
	movq	#65244, r1
	shl	#16, r1
	bis	#47768, r1
	shl	#16, r1
	bis	#30292, r1
	shl	#16, r1
	bis	#12816, r1
	lea	buf+160, r6
	movq	#0x1122, r2
	movq	#34935, r2
	shl	#16, r2
	bis	#26197, r2
	shl	#16, r2
	bis	#17459, r2
	shl	#16, r2
	bis	#8721, r2
	movq	r2, (r6)
	movw	r1, (r6)
	movq	(r6), r3
	movq	#34935, r12
	shl	#16, r12
	bis	#26197, r12
	shl	#16, r12
	bis	#17459, r12
	shl	#16, r12
	bis	#12816, r12
	cmp	r3, r12		; 12: movw r1, (r6) stores 2 byte(s)
	bne	f12
	movq	#65244, r1
	shl	#16, r1
	bis	#47768, r1
	shl	#16, r1
	bis	#30292, r1
	shl	#16, r1
	bis	#12816, r1
	lea	buf+160, r6
	movq	#0x1122, r2
	movq	#34935, r2
	shl	#16, r2
	bis	#26197, r2
	shl	#16, r2
	bis	#17459, r2
	shl	#16, r2
	bis	#8721, r2
	movq	r2, (r6)
	movb	r1, (r6)
	movq	(r6), r3
	movq	#34935, r12
	shl	#16, r12
	bis	#26197, r12
	shl	#16, r12
	bis	#17459, r12
	shl	#16, r12
	bis	#8720, r12
	cmp	r3, r12		; 13: movb r1, (r6) stores 1 byte(s)
	bne	f13
	lea	0(sp), r3
	sub	sp, r3
	cmp	r3, #0		; 14: lea 0(sp), r3
	bne	f14
	lea	8(sp), r3
	sub	sp, r3
	cmp	r3, #8		; 15: lea 8(sp), r3
	bne	f15
	lea	120(sp), r3
	sub	sp, r3
	cmp	r3, #120		; 16: lea 120(sp), r3
	bne	f16
	lea	128(sp), r3
	sub	sp, r3
	cmp	r3, #128		; 17: lea 128(sp), r3 (long form)
	bne	f17
	lea	4(sp), r3
	sub	sp, r3
	cmp	r3, #4		; 18: lea 4(sp), r3 (long form: not a multiple of 8)
	bne	f18
	movq	sp, r7
	sub	#320, sp
	movq	r7, r3
	sub	sp, r3
	cmp	r3, #320		; 19: sub #320, sp
	bne	f19
	movq	sp, r7
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#0, r1
	shl	#16, r1
	bis	#0, r1
	movq	r1, 0(sp)
	movq	0(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	cmp	r3, r12		; 20: movq r1, 0(sp) stored; read through r7
	bne	f20
	movq	0(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	cmp	r4, r12		; 21: movq 0(sp), r4
	bne	f21
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#0, r1
	shl	#16, r1
	bis	#2056, r1
	movq	r1, 8(sp)
	movq	8(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#2056, r12
	cmp	r3, r12		; 22: movq r1, 8(sp) stored; read through r7
	bne	f22
	movq	8(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#2056, r12
	cmp	r4, r12		; 23: movq 8(sp), r4
	bne	f23
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#0, r1
	shl	#16, r1
	bis	#30840, r1
	movq	r1, 120(sp)
	movq	120(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#30840, r12
	cmp	r3, r12		; 24: movq r1, 120(sp) stored; read through r7
	bne	f24
	movq	120(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#30840, r12
	cmp	r4, r12		; 25: movq 120(sp), r4
	bne	f25
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#0, r1
	shl	#16, r1
	bis	#32896, r1
	movq	r1, 128(sp)
	movq	128(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#32896, r12
	cmp	r3, r12		; 26: movq r1, 128(sp) stored; read through r7
	bne	f26
	movq	128(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#32896, r12
	cmp	r4, r12		; 27: movq 128(sp), r4
	bne	f27
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#0, r1
	shl	#16, r1
	bis	#63736, r1
	movq	r1, 248(sp)
	movq	248(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#63736, r12
	cmp	r3, r12		; 28: movq r1, 248(sp) stored; read through r7
	bne	f28
	movq	248(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#63736, r12
	cmp	r4, r12		; 29: movq 248(sp), r4
	bne	f29
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#1, r1
	shl	#16, r1
	bis	#256, r1
	movq	r1, 256(sp)
	movq	256(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#1, r12
	shl	#16, r12
	bis	#256, r12
	cmp	r3, r12		; 30: movq r1, 256(sp) stored; read through r7
	bne	f30
	movq	256(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#1, r12
	shl	#16, r12
	bis	#256, r12
	cmp	r4, r12		; 31: movq 256(sp), r4
	bne	f31
	movq	#2571, r1
	shl	#16, r1
	bis	#3085, r1
	shl	#16, r1
	bis	#1, r1
	shl	#16, r1
	bis	#14648, r1
	movq	r1, 312(sp)
	movq	312(r7), r3
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#1, r12
	shl	#16, r12
	bis	#14648, r12
	cmp	r3, r12		; 32: movq r1, 312(sp) stored; read through r7
	bne	f32
	movq	312(sp), r4
	movq	#2571, r12
	shl	#16, r12
	bis	#3085, r12
	shl	#16, r12
	bis	#1, r12
	shl	#16, r12
	bis	#14648, r12
	cmp	r4, r12		; 33: movq 312(sp), r4
	bne	f33
	movq	#-1, r2
	movq	r2, 0(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#0, r1
	movl	r1, 0(sp)
	movl	0(sp), r3
	cmp	r3, #-2147483648		; 34: movl 0(sp): store 4 bytes, load sign-extends
	bne	f34
	movq	0(r7), r4
	cmp	r4, #-2147483648		; 35: the other half of the quad at 0 is untouched
	bne	f35
	movq	r2, 0(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#4, r1
	movl	r1, 4(sp)
	movl	4(sp), r3
	cmp	r3, #-2147483644		; 36: movl 4(sp): store 4 bytes, load sign-extends
	bne	f36
	movq	0(r7), r4
	movq	#32768, r12
	shl	#16, r12
	bis	#4, r12
	shl	#16, r12
	bis	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cmp	r4, r12		; 37: the other half of the quad at 0 is untouched
	bne	f37
	movq	r2, 56(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#60, r1
	movl	r1, 60(sp)
	movl	60(sp), r3
	cmp	r3, #-2147483588		; 38: movl 60(sp): store 4 bytes, load sign-extends
	bne	f38
	movq	56(r7), r4
	movq	#32768, r12
	shl	#16, r12
	bis	#60, r12
	shl	#16, r12
	bis	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cmp	r4, r12		; 39: the other half of the quad at 56 is untouched
	bne	f39
	movq	r2, 64(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#64, r1
	movl	r1, 64(sp)
	movl	64(sp), r3
	cmp	r3, #-2147483584		; 40: movl 64(sp): store 4 bytes, load sign-extends
	bne	f40
	movq	64(r7), r4
	cmp	r4, #-2147483584		; 41: the other half of the quad at 64 is untouched
	bne	f41
	movq	r2, 120(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#124, r1
	movl	r1, 124(sp)
	movl	124(sp), r3
	cmp	r3, #-2147483524		; 42: movl 124(sp): store 4 bytes, load sign-extends
	bne	f42
	movq	120(r7), r4
	movq	#32768, r12
	shl	#16, r12
	bis	#124, r12
	shl	#16, r12
	bis	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cmp	r4, r12		; 43: the other half of the quad at 120 is untouched
	bne	f43
	movq	r2, 128(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#128, r1
	movl	r1, 128(sp)
	movl	128(sp), r3
	cmp	r3, #-2147483520		; 44: movl 128(sp): store 4 bytes, load sign-extends
	bne	f44
	movq	128(r7), r4
	cmp	r4, #-2147483520		; 45: the other half of the quad at 128 is untouched
	bne	f45
	movq	r2, 128(sp)
	movq	#4660, r1
	shl	#16, r1
	bis	#22136, r1
	shl	#16, r1
	bis	#32768, r1
	shl	#16, r1
	bis	#132, r1
	movl	r1, 132(sp)
	movl	132(sp), r3
	cmp	r3, #-2147483516		; 46: movl 132(sp): store 4 bytes, load sign-extends
	bne	f46
	movq	128(r7), r4
	movq	#32768, r12
	shl	#16, r12
	bis	#132, r12
	shl	#16, r12
	bis	#65535, r12
	shl	#16, r12
	bis	#65535, r12
	cmp	r4, r12		; 47: the other half of the quad at 128 is untouched
	bne	f47
	movq	8(r5), r3
	cmp	r3, #257		; 48: movq 8(r5), r3
	bne	f48
	movq	16(r5), r3
	cmp	r3, #258		; 49: movq 16(r5), r3
	bne	f49
	movq	24(r5), r3
	cmp	r3, #259		; 50: movq 24(r5), r3
	bne	f50
	movq	32(r5), r3
	cmp	r3, #260		; 51: movq 32(r5), r3
	bne	f51
	movq	40(r5), r3
	cmp	r3, #261		; 52: movq 40(r5), r3
	bne	f52
	movl	4(r5), r3
	cmp	r3, #287454020		; 53: movl 4(r5), r3
	bne	f53
	movl	8(r5), r3
	cmp	r3, #257		; 54: movl 8(r5), r3
	bne	f54
	movl	12(r5), r3
	cmp	r3, #0		; 55: movl 12(r5), r3
	bne	f55
	movl	16(r5), r3
	cmp	r3, #258		; 56: movl 16(r5), r3
	bne	f56
	movl	20(r5), r3
	cmp	r3, #0		; 57: movl 20(r5), r3
	bne	f57
	movq	#30566, r1
	shl	#16, r1
	bis	#21828, r1
	shl	#16, r1
	bis	#13090, r1
	shl	#16, r1
	bis	#4352, r1
	movq	r1, 8(r6)
	movq	8(r6), r3
	movq	#30566, r12
	shl	#16, r12
	bis	#21828, r12
	shl	#16, r12
	bis	#13090, r12
	shl	#16, r12
	bis	#4352, r12
	cmp	r3, r12		; 58: movq r1, 8(r6)
	bne	f58
	movq	r1, 16(r6)
	movq	16(r6), r3
	movq	#30566, r12
	shl	#16, r12
	bis	#21828, r12
	shl	#16, r12
	bis	#13090, r12
	shl	#16, r12
	bis	#4352, r12
	cmp	r3, r12		; 59: movq r1, 16(r6)
	bne	f59
	movq	r1, 24(r6)
	movq	24(r6), r3
	movq	#30566, r12
	shl	#16, r12
	bis	#21828, r12
	shl	#16, r12
	bis	#13090, r12
	shl	#16, r12
	bis	#4352, r12
	cmp	r3, r12		; 60: movq r1, 24(r6)
	bne	f60
	movq	#4104, r8
	movq	#4105, r9
	movq	#4106, r10
	movq	#4107, r11
	movq	#4108, r12
	movq	#4109, r13
	movq	#4111, r15
	movq	sp, r2
	pushm	#0x0F00
	movq	r2, r3
	sub	sp, r3
	cmp	r3, #32		; 61: pushm r8-r11 pushes 4 registers
	bne	f61
	movq	(sp), r3
	cmp	r3, #4107		; 62: the last register pushed is on top (r11)
	bne	f62
	movq	24(sp), r3
	cmp	r3, #4104		; 63: r8 is deepest
	bne	f63
	movq	#0, r8
	movq	#0, r9
	movq	#0, r10
	movq	#0, r11
	popm	#0x0F00
	movq	sp, r3
	sub	r2, r3
	cmp	r3, #0		; 64: popm restores sp
	bne	f64
	cmp	r8, #4104
	bne	f65
	cmp	r9, #4105
	bne	f66
	cmp	r10, #4106
	bne	f67
	cmp	r11, #4107
	bne	f68
	pushm	#0x8000
	movq	(sp), r3
	cmp	r3, #4111		; 69: pushm #0x8000 pushes r15 only
	bne	f69
	movq	#0, r15
	popm	#0x8000
	cmp	r15, #4111		; 70: popm #0x8000 pops r15
	bne	f70
	pushm	#0x3F00
	movq	#0, r13
	popm	#0x3F00
	cmp	r13, #4109		; 71: pushm/popm r8-r13
	bne	f71
	add	#312, sp
	movq	sp, r3
	sub	r7, r3
	cmp	r3, #312		; 72: add #312, sp
	bne	f72
	add	#8, sp
	movq	sp, r3
	sub	r7, r3
	cmp	r3, #320		; 73: add #8, sp
	bne	f73
	sub	#2040, sp
	movq	r7, r3
	sub	sp, r3
	cmp	r3, #1720		; 74: sub #2040, sp (the largest one-parcel frame)
	bne	f74
	add	#2040, sp
	movq	r7, sp
	add	#320, sp
	movq	#-8, r3
	cmp	r3, #-8		; 75: movq #-8, r3
	bne	f75
	movq	#-1, r3
	cmp	r3, #-1		; 76: movq #-1, r3
	bne	f76
	movq	#0, r3
	cmp	r3, #0		; 77: movq #0, r3
	bne	f77
	movq	#7, r3
	cmp	r3, #7		; 78: movq #7, r3
	bne	f78
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shl	#0, r3
	movq	#32768, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#4660, r12
	cmp	r3, r12		; 79: shl #0
	bne	f79
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shl	#1, r3
	cmp	r3, #9320		; 80: shl #1
	bne	f80
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shl	#15, r3
	cmp	r3, #152698880		; 81: shl #15
	bne	f81
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shr	#0, r3
	movq	#32768, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#4660, r12
	cmp	r3, r12		; 82: shr #0
	bne	f82
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shr	#1, r3
	movq	#16384, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#2330, r12
	cmp	r3, r12		; 83: shr #1
	bne	f83
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	shr	#15, r3
	movq	#1, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	cmp	r3, r12		; 84: shr #15
	bne	f84
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	sar	#0, r3
	movq	#32768, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#4660, r12
	cmp	r3, r12		; 85: sar #0
	bne	f85
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	sar	#1, r3
	movq	#49152, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#2330, r12
	cmp	r3, r12		; 86: sar #1
	bne	f86
	movq	#32768, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#0, r3
	shl	#16, r3
	bis	#4660, r3
	sar	#15, r3
	movq	#65535, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	shl	#16, r12
	bis	#0, r12
	cmp	r3, r12		; 87: sar #15
	bne	f87
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	and	#-8, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#240, r12
	cmp	r3, r12		; 88: and #-8
	bne	f88
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	and	#-1, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#245, r12
	cmp	r3, r12		; 89: and #-1
	bne	f89
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	and	#7, r3
	cmp	r3, #5		; 90: and #7
	bne	f90
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	bis	#-8, r3
	cmp	r3, #-3		; 91: bis #-8
	bne	f91
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	bis	#-1, r3
	cmp	r3, #-1		; 92: bis #-1
	bne	f92
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	bis	#7, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#247, r12
	cmp	r3, r12		; 93: bis #7
	bne	f93
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	xor	#-8, r3
	movq	#65280, r12
	shl	#16, r12
	bis	#65280, r12
	shl	#16, r12
	bis	#65280, r12
	shl	#16, r12
	bis	#65293, r12
	cmp	r3, r12		; 94: xor #-8
	bne	f94
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	xor	#-1, r3
	movq	#65280, r12
	shl	#16, r12
	bis	#65280, r12
	shl	#16, r12
	bis	#65280, r12
	shl	#16, r12
	bis	#65290, r12
	cmp	r3, r12		; 95: xor #-1
	bne	f95
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	xor	#7, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#242, r12
	cmp	r3, r12		; 96: xor #7
	bne	f96
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	add	#-8, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#237, r12
	cmp	r3, r12		; 97: add #-8
	bne	f97
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	add	#-1, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#244, r12
	cmp	r3, r12		; 98: add #-1
	bne	f98
	movq	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#255, r3
	shl	#16, r3
	bis	#245, r3
	add	#7, r3
	movq	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#255, r12
	shl	#16, r12
	bis	#252, r12
	cmp	r3, r12		; 99: add #7
	bne	f99
	movq	#1, r3
	add	#-1, r3
	bne	f100		; 100: add #-1 to 1 gives zero ...
	bcc	f101		; 101: ... and a carry
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
	.data
	.even
buf:
	.quad	0x1122334489abcdf0
	.quad	0x0000000000000101
	.quad	0x0000000000000102
	.quad	0x0000000000000103
	.quad	0x0000000000000104
	.quad	0x0000000000000105
	.quad	0x0000000000000106
	.quad	0x0000000000000107
	.quad	0x0000000000000108
	.quad	0x0000000000000109
	.quad	0x000000000000010a
	.quad	0x000000000000010b
	.quad	0x000000000000010c
	.quad	0x000000000000010d
	.quad	0x000000000000010e
	.quad	0x000000000000010f
	.quad	0x0000000000000110
	.quad	0x0000000000000111
	.quad	0x0000000000000112
	.quad	0x0000000000000113
	.quad	0x0000000000000114
	.quad	0x0000000000000115
	.quad	0x0000000000000116
	.quad	0x0000000000000117
	.quad	0x0000000000000118
	.quad	0x0000000000000119
	.quad	0x000000000000011a
	.quad	0x000000000000011b
	.quad	0x000000000000011c
	.quad	0x000000000000011d
	.quad	0x000000000000011e
	.quad	0x000000000000011f
	.quad	0x0000000000000120
	.quad	0x0000000000000121
	.quad	0x0000000000000122
	.quad	0x0000000000000123
	.quad	0x0000000000000124
	.quad	0x0000000000000125
	.quad	0x0000000000000126
	.quad	0x0000000000000127
	.space	64
