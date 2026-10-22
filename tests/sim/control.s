; branches on every condition, sob, call/ret, push/pop, pushm/popm, jmp, calli
	.text
	.globl	_start
_start:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bne	L4_ok
	br	f1
L4_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	beq	L10_ok
	br	L10_end
L10_ok:
	br	f2
L10_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bmi	L18_ok
	br	f3
L18_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bpl	L24_ok
	br	L24_end
L24_ok:
	br	f4
L24_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bvs	L32_ok
	br	L32_end
L32_ok:
	br	f5
L32_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bvc	L40_ok
	br	f6
L40_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bcs	L46_ok
	br	f7
L46_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bcc	L52_ok
	br	L52_end
L52_ok:
	br	f8
L52_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	blo	L60_ok
	br	f9
L60_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bhis	L66_ok
	br	L66_end
L66_ok:
	br	f10
L66_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	blt	L74_ok
	br	f11
L74_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bge	L80_ok
	br	L80_end
L80_ok:
	br	f12
L80_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	ble	L88_ok
	br	f13
L88_ok:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bgt	L94_ok
	br	L94_end
L94_ok:
	br	f14
L94_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	bhi	L102_ok
	br	L102_end
L102_ok:
	br	f15
L102_end:
	movq	#5, r1
	movq	#7, r2
	cmp	r1, r2
	blos	L110_ok
	br	f16
L110_ok:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	beq	L116_ok
	br	f17
L116_ok:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	bne	L122_ok
	br	L122_end
L122_ok:
	br	f18
L122_end:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	bge	L130_ok
	br	f19
L130_ok:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	ble	L136_ok
	br	f20
L136_ok:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	bgt	L142_ok
	br	L142_end
L142_ok:
	br	f21
L142_end:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	blt	L150_ok
	br	L150_end
L150_ok:
	br	f22
L150_end:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	blos	L158_ok
	br	f23
L158_ok:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	bhi	L164_ok
	br	L164_end
L164_ok:
	br	f24
L164_end:
	movq	#7, r1
	movq	#7, r2
	cmp	r1, r2
	bcc	L172_ok
	br	f25
L172_ok:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	blt	L178_ok
	br	f26
L178_ok:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	bhi	L184_ok
	br	f27
L184_ok:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	bge	L190_ok
	br	L190_end
L190_ok:
	br	f28
L190_end:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	blos	L198_ok
	br	L198_end
L198_ok:
	br	f29
L198_end:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	bgt	L206_ok
	br	L206_end
L206_ok:
	br	f30
L206_end:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	ble	L214_ok
	br	f31
L214_ok:
	movq	#-1, r1
	movq	#1, r2
	cmp	r1, r2
	bcs	L220_ok
	br	L220_end
L220_ok:
	br	f32
L220_end:
	movq	#0, r0
	movq	#5, r1
	1:	inc	r0
	sob	r1, 1b
	cmp	r0, #5
	bne	f33
	cmp	r1, #0
	bne	f34
	movq	#0, r0
	call	fn
	call	fn
	cmp	r0, #2
	bne	f35
	br	pastfn
	fn:	inc	r0
	ret
pastfn:
	movq	r14, r9
	movq	#11, r1
	push	r1
	movq	#22, r1
	push	r1
	cmp	r1, #22
	bne	f36
	sub	r14, r9
	movq	r9, r8
	cmp	r8, #16		; two pushes move sp down by 16
	bne	f37
	pop	r2
	cmp	r2, #22		; last in, first out
	bne	f38
	pop	r3
	cmp	r3, #11
	bne	f39
	movq	r14, r4
	sub	r9, r4
	movq	r14, r9
	movq	#101, r1
	movq	#102, r2
	movq	#103, r3
	pushm	#0x0e
	movq	r9, r8
	sub	r14, r8
	cmp	r8, #24		; three registers = 24 bytes
	bne	f40
	movq	0(r14), r5
	cmp	r5, #103		; highest-numbered register at the lowest address
	bne	f41
	movq	16(r14), r5
	cmp	r5, #101		; lowest-numbered register at the highest address
	bne	f42
	movq	#0, r1
	movq	#0, r2
	movq	#0, r3
	popm	#0x0e
	cmp	r1, #101
	bne	f43
	cmp	r2, #102
	bne	f44
	cmp	r3, #103
	bne	f45
	cmp	r14, r9		; sp restored
	bne	f46
	lea	target, r6
	movq	r6, slot
	movq	#0, r0
	jmpi	slot
	movq	#99, r0
target:
	cmp	r0, #0		; jmpi through memory skipped the next instruction
	bne	f47
	lea	fn2, r6
	movq	r6, slot
	calli	slot
	cmp	r0, #7
	bne	f48
	br	pastfn2
	fn2:	movq	#7, r0
	ret
pastfn2:
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
	.data
	.even
slot:	.quad	0
