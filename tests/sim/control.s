; branches on every condition, sob, call/ret, push/pop, pushm/popm, jmp, calli
	.text
	.globl	_start
_start:
	mov	$5, r1
	mov	$7, r2
	cbne r1, r2, L4_ok
	br	fail1
L4_ok:
	mov	$5, r1
	mov	$7, r2
	cbeq r1, r2, L10_ok
	br	L10_end
L10_ok:
	br	fail2
L10_end:
	mov	$5, r1
	mov	$7, r2
	cblt	r1, r2, L18_ok
	br	fail3
L18_ok:
	mov	$5, r1
	mov	$7, r2
	cbge	r1, r2, L24_ok
	br	L24_end
L24_ok:
	br	fail4
L24_end:
	mov	$5, r1
	mov	$7, r2
	cbcs r1, r2, L46_ok
	br	fail7
L46_ok:
	mov	$5, r1
	mov	$7, r2
	cbcc r1, r2, L52_ok
	br	L52_end
L52_ok:
	br	fail8
L52_end:
	mov	$5, r1
	mov	$7, r2
	cblo r1, r2, L60_ok
	br	fail9
L60_ok:
	mov	$5, r1
	mov	$7, r2
	cbhis r1, r2, L66_ok
	br	L66_end
L66_ok:
	br	fail10
L66_end:
	mov	$5, r1
	mov	$7, r2
	cblt r1, r2, L74_ok
	br	fail11
L74_ok:
	mov	$5, r1
	mov	$7, r2
	cbge r1, r2, L80_ok
	br	L80_end
L80_ok:
	br	fail12
L80_end:
	mov	$5, r1
	mov	$7, r2
	cble r1, r2, L88_ok
	br	fail13
L88_ok:
	mov	$5, r1
	mov	$7, r2
	cbgt r1, r2, L94_ok
	br	L94_end
L94_ok:
	br	fail14
L94_end:
	mov	$5, r1
	mov	$7, r2
	cbhi r1, r2, L102_ok
	br	L102_end
L102_ok:
	br	fail15
L102_end:
	mov	$5, r1
	mov	$7, r2
	cblos r1, r2, L110_ok
	br	fail16
L110_ok:
	mov	$7, r1
	mov	$7, r2
	cbeq r1, r2, L116_ok
	br	fail17
L116_ok:
	mov	$7, r1
	mov	$7, r2
	cbne r1, r2, L122_ok
	br	L122_end
L122_ok:
	br	fail18
L122_end:
	mov	$7, r1
	mov	$7, r2
	cbge r1, r2, L130_ok
	br	fail19
L130_ok:
	mov	$7, r1
	mov	$7, r2
	cble r1, r2, L136_ok
	br	fail20
L136_ok:
	mov	$7, r1
	mov	$7, r2
	cbgt r1, r2, L142_ok
	br	L142_end
L142_ok:
	br	fail21
L142_end:
	mov	$7, r1
	mov	$7, r2
	cblt r1, r2, L150_ok
	br	L150_end
L150_ok:
	br	fail22
L150_end:
	mov	$7, r1
	mov	$7, r2
	cblos r1, r2, L158_ok
	br	fail23
L158_ok:
	mov	$7, r1
	mov	$7, r2
	cbhi r1, r2, L164_ok
	br	L164_end
L164_ok:
	br	fail24
L164_end:
	mov	$7, r1
	mov	$7, r2
	cbcc r1, r2, L172_ok
	br	fail25
L172_ok:
	mov	$-1, r1
	mov	$1, r2
	cblt r1, r2, L178_ok
	br	fail26
L178_ok:
	mov	$-1, r1
	mov	$1, r2
	cbhi r1, r2, L184_ok
	br	fail27
L184_ok:
	mov	$-1, r1
	mov	$1, r2
	cbge r1, r2, L190_ok
	br	L190_end
L190_ok:
	br	fail28
L190_end:
	mov	$-1, r1
	mov	$1, r2
	cblos r1, r2, L198_ok
	br	L198_end
L198_ok:
	br	fail29
L198_end:
	mov	$-1, r1
	mov	$1, r2
	cbgt r1, r2, L206_ok
	br	L206_end
L206_ok:
	br	fail30
L206_end:
	mov	$-1, r1
	mov	$1, r2
	cble r1, r2, L214_ok
	br	fail31
L214_ok:
	mov	$-1, r1
	mov	$1, r2
	cbcs r1, r2, L220_ok
	br	L220_end
L220_ok:
	br	fail32
L220_end:
	mov	$0, r0
	mov	$5, r1
	1:	inc	r0
	sob	r1, 1b
	cbne r0, $5, fail33
	cbne r1, $0, fail34
	mov	$0, r0
	call	fn
	call	fn
	cbne r0, $2, fail35
	br	pastfn
	fn:	inc	r0
	ret
pastfn:
	mov	r14, r9
	mov	$11, r1
	push	r1
	mov	$22, r1
	push	r1
	cbne r1, $22, fail36
	sub	r14, r9
	mov	r9, r8
	cbne r8, $16, fail37
	pop	r2
	cbne r2, $22, fail38
	pop	r3
	cbne r3, $11, fail39
	mov	r14, r4
	sub	r9, r4
	mov	r14, r9
	mov	$101, r1
	mov	$102, r2
	mov	$103, r3
	pushm	$0x0e
	mov	r9, r8
	sub	r14, r8
	cbne r8, $24, fail40
	mov	0(r14), r5
	cbne r5, $103, fail41
	mov	16(r14), r5
	cbne r5, $101, fail42
	mov	$0, r1
	mov	$0, r2
	mov	$0, r3
	popm	$0x0e
	cbne r1, $101, fail43
	cbne r2, $102, fail44
	cbne r3, $103, fail45
	cbne r14, r9, fail46
	lea	target, r6
	mov	r6, slot
	mov	$0, r0
	jmpi	slot
	mov	$99, r0
target:
	cbne r0, $0, fail47
	lea	fn2, r6
	mov	r6, slot
	calli	slot
	cbne r0, $7, fail48
	br	pastfn2
	fn2:	mov	$7, r0
	ret
pastfn2:
	mov	$0, r0
	trap	$0
fail1:	mov	$1, r0
	trap	$0
fail2:	mov	$2, r0
	trap	$0
fail3:	mov	$3, r0
	trap	$0
fail4:	mov	$4, r0
	trap	$0
fail5:	mov	$5, r0
	trap	$0
fail6:	mov	$6, r0
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
fail17:	mov	$17, r0
	trap	$0
fail18:	mov	$18, r0
	trap	$0
fail19:	mov	$19, r0
	trap	$0
fail20:	mov	$20, r0
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
fail31:	mov	$31, r0
	trap	$0
fail32:	mov	$32, r0
	trap	$0
fail33:	mov	$33, r0
	trap	$0
fail34:	mov	$34, r0
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
fail45:	mov	$45, r0
	trap	$0
fail46:	mov	$46, r0
	trap	$0
fail47:	mov	$47, r0
	trap	$0
fail48:	mov	$48, r0
	trap	$0
	.data
	.even
slot:	.quad	0
