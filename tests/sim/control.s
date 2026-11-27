; branches on every condition, sob, call/ret, push/pop, pushm/popm, jmp, calli
	.text
	.globl	_start
_start:
	mov	$5, r1
	mov	$7, r2
	cbne r1, r2, L4_ok
	br	f1
L4_ok:
	mov	$5, r1
	mov	$7, r2
	cbeq r1, r2, L10_ok
	br	L10_end
L10_ok:
	br	f2
L10_end:
	mov	$5, r1
	mov	$7, r2
	cblt	r1, r2, L18_ok
	br	f3
L18_ok:
	mov	$5, r1
	mov	$7, r2
	cbge	r1, r2, L24_ok
	br	L24_end
L24_ok:
	br	f4
L24_end:
	mov	$5, r1
	mov	$7, r2
	cbcs r1, r2, L46_ok
	br	f7
L46_ok:
	mov	$5, r1
	mov	$7, r2
	cbcc r1, r2, L52_ok
	br	L52_end
L52_ok:
	br	f8
L52_end:
	mov	$5, r1
	mov	$7, r2
	cblo r1, r2, L60_ok
	br	f9
L60_ok:
	mov	$5, r1
	mov	$7, r2
	cbhis r1, r2, L66_ok
	br	L66_end
L66_ok:
	br	f10
L66_end:
	mov	$5, r1
	mov	$7, r2
	cblt r1, r2, L74_ok
	br	f11
L74_ok:
	mov	$5, r1
	mov	$7, r2
	cbge r1, r2, L80_ok
	br	L80_end
L80_ok:
	br	f12
L80_end:
	mov	$5, r1
	mov	$7, r2
	cble r1, r2, L88_ok
	br	f13
L88_ok:
	mov	$5, r1
	mov	$7, r2
	cbgt r1, r2, L94_ok
	br	L94_end
L94_ok:
	br	f14
L94_end:
	mov	$5, r1
	mov	$7, r2
	cbhi r1, r2, L102_ok
	br	L102_end
L102_ok:
	br	f15
L102_end:
	mov	$5, r1
	mov	$7, r2
	cblos r1, r2, L110_ok
	br	f16
L110_ok:
	mov	$7, r1
	mov	$7, r2
	cbeq r1, r2, L116_ok
	br	f17
L116_ok:
	mov	$7, r1
	mov	$7, r2
	cbne r1, r2, L122_ok
	br	L122_end
L122_ok:
	br	f18
L122_end:
	mov	$7, r1
	mov	$7, r2
	cbge r1, r2, L130_ok
	br	f19
L130_ok:
	mov	$7, r1
	mov	$7, r2
	cble r1, r2, L136_ok
	br	f20
L136_ok:
	mov	$7, r1
	mov	$7, r2
	cbgt r1, r2, L142_ok
	br	L142_end
L142_ok:
	br	f21
L142_end:
	mov	$7, r1
	mov	$7, r2
	cblt r1, r2, L150_ok
	br	L150_end
L150_ok:
	br	f22
L150_end:
	mov	$7, r1
	mov	$7, r2
	cblos r1, r2, L158_ok
	br	f23
L158_ok:
	mov	$7, r1
	mov	$7, r2
	cbhi r1, r2, L164_ok
	br	L164_end
L164_ok:
	br	f24
L164_end:
	mov	$7, r1
	mov	$7, r2
	cbcc r1, r2, L172_ok
	br	f25
L172_ok:
	mov	$-1, r1
	mov	$1, r2
	cblt r1, r2, L178_ok
	br	f26
L178_ok:
	mov	$-1, r1
	mov	$1, r2
	cbhi r1, r2, L184_ok
	br	f27
L184_ok:
	mov	$-1, r1
	mov	$1, r2
	cbge r1, r2, L190_ok
	br	L190_end
L190_ok:
	br	f28
L190_end:
	mov	$-1, r1
	mov	$1, r2
	cblos r1, r2, L198_ok
	br	L198_end
L198_ok:
	br	f29
L198_end:
	mov	$-1, r1
	mov	$1, r2
	cbgt r1, r2, L206_ok
	br	L206_end
L206_ok:
	br	f30
L206_end:
	mov	$-1, r1
	mov	$1, r2
	cble r1, r2, L214_ok
	br	f31
L214_ok:
	mov	$-1, r1
	mov	$1, r2
	cbcs r1, r2, L220_ok
	br	L220_end
L220_ok:
	br	f32
L220_end:
	mov	$0, r0
	mov	$5, r1
	1:	inc	r0
	sob	r1, 1b
	cbne r0, $5, f33
	cbne r1, $0, f34
	mov	$0, r0
	call	fn
	call	fn
	cbne r0, $2, f35
	br	pastfn
	fn:	inc	r0
	ret
pastfn:
	mov	r14, r9
	mov	$11, r1
	push	r1
	mov	$22, r1
	push	r1
	cbne r1, $22, f36
	sub	r14, r9
	mov	r9, r8
	cbne r8, $16, f37
	pop	r2
	cbne r2, $22, f38
	pop	r3
	cbne r3, $11, f39
	mov	r14, r4
	sub	r9, r4
	mov	r14, r9
	mov	$101, r1
	mov	$102, r2
	mov	$103, r3
	pushm	$0x0e
	mov	r9, r8
	sub	r14, r8
	cbne r8, $24, f40
	mov	0(r14), r5
	cbne r5, $103, f41
	mov	16(r14), r5
	cbne r5, $101, f42
	mov	$0, r1
	mov	$0, r2
	mov	$0, r3
	popm	$0x0e
	cbne r1, $101, f43
	cbne r2, $102, f44
	cbne r3, $103, f45
	cbne r14, r9, f46
	lea	target, r6
	mov	r6, slot
	mov	$0, r0
	jmpi	slot
	mov	$99, r0
target:
	cbne r0, $0, f47
	lea	fn2, r6
	mov	r6, slot
	calli	slot
	cbne r0, $7, f48
	br	pastfn2
	fn2:	mov	$7, r0
	ret
pastfn2:
	mov	$0, r0
	trap	$0
f1:	mov	$1, r0
	trap	$0
f2:	mov	$2, r0
	trap	$0
f3:	mov	$3, r0
	trap	$0
f4:	mov	$4, r0
	trap	$0
f5:	mov	$5, r0
	trap	$0
f6:	mov	$6, r0
	trap	$0
f7:	mov	$7, r0
	trap	$0
f8:	mov	$8, r0
	trap	$0
f9:	mov	$9, r0
	trap	$0
f10:	mov	$10, r0
	trap	$0
f11:	mov	$11, r0
	trap	$0
f12:	mov	$12, r0
	trap	$0
f13:	mov	$13, r0
	trap	$0
f14:	mov	$14, r0
	trap	$0
f15:	mov	$15, r0
	trap	$0
f16:	mov	$16, r0
	trap	$0
f17:	mov	$17, r0
	trap	$0
f18:	mov	$18, r0
	trap	$0
f19:	mov	$19, r0
	trap	$0
f20:	mov	$20, r0
	trap	$0
f21:	mov	$21, r0
	trap	$0
f22:	mov	$22, r0
	trap	$0
f23:	mov	$23, r0
	trap	$0
f24:	mov	$24, r0
	trap	$0
f25:	mov	$25, r0
	trap	$0
f26:	mov	$26, r0
	trap	$0
f27:	mov	$27, r0
	trap	$0
f28:	mov	$28, r0
	trap	$0
f29:	mov	$29, r0
	trap	$0
f30:	mov	$30, r0
	trap	$0
f31:	mov	$31, r0
	trap	$0
f32:	mov	$32, r0
	trap	$0
f33:	mov	$33, r0
	trap	$0
f34:	mov	$34, r0
	trap	$0
f35:	mov	$35, r0
	trap	$0
f36:	mov	$36, r0
	trap	$0
f37:	mov	$37, r0
	trap	$0
f38:	mov	$38, r0
	trap	$0
f39:	mov	$39, r0
	trap	$0
f40:	mov	$40, r0
	trap	$0
f41:	mov	$41, r0
	trap	$0
f42:	mov	$42, r0
	trap	$0
f43:	mov	$43, r0
	trap	$0
f44:	mov	$44, r0
	trap	$0
f45:	mov	$45, r0
	trap	$0
f46:	mov	$46, r0
	trap	$0
f47:	mov	$47, r0
	trap	$0
f48:	mov	$48, r0
	trap	$0
	.data
	.even
slot:	.quad	0
