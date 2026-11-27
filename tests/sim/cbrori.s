; cbCC (compare a register with a 5-bit immediate and branch) and ror32.  A failed check n exits with n.
	.text
	.globl	_start
_start:
	mov	$5, r1
	cbeq	r1, $5, 1f		; taken: 5 - 5 = 0
	br	fail1
1:	cbne	r1, $5, fail2		; not taken
	cblt	r1, $6, 1f		; taken: 5 < 6 signed
	br	fail3
1:	cbge	r1, $6, fail4		; not taken
	cbgt	r1, $-1, 1f		; taken: 5 > -1 signed
	br	fail5
1:	cbhi	r1, $-1, fail6		; not taken: -1 is 0xFFFF...F unsigned, 5 is below it
	cblos	r1, $-1, 1f		; taken, unsigned lower or same
	br	fail7
1:	cble	r1, $5, 1f		; taken: equal
	br	fail8
1:	cbcs	r1, $6, 1f		; taken: 5 - 6 borrows
	br	fail9
1:	cbcc	r1, $6, fail10		; not taken
1:	cbhis	r1, $-16, fail15		; not taken: unsigned 5 is below 0xFFFF...F0
	cblo	r1, $-16, 1f		; taken
	br	fail16
1:
; the extreme immediates: -16 and 15
	mov	$-16, r2
	cbeq	r2, $-16, 1f
	br	fail21
1:	mov	$15, r2
	cbeq	r2, $15, 1f
	br	fail22
1:
; a loop with the branch backward: counts 10 down to 0
	mov	$10, r3
	mov	$0, r4
2:	add	$1, r4
	sub	$1, r3
	cbne	r3, $0, 2b
	cbne r4, $10, fail23
; the long form: a target more than 1024 parcels away, forward and backward
	cbeq	r4, $10, 1f
	br	fail24
	.space	3000
1:	br	3f
4:	mov	$1, r5
	br	5f
	.space	3000
3:	cbeq	r4, $10, 4b
	br	fail25
5:	cbne r5, $1, fail26
; ror .32: the low 32 bits rotate right, the result is sign-extended from bit 31 (errata 34)
	mov	$-1, r6
	shl	$16, r6
	bis	$0x8000, r6
	shl	$16, r6
	bis	$1, r6			; r6 = 0xFFFFFFFF80000001
	ror.s32	r6, $1, r7 ; the rotate of 0x80000001 by 1 = 0xC0000000: bit 31 set, so negative: 0xFFFFFFFFC0000000
	mov	$-1073741824, r8
	cbne r7, r8, fail27
	ror.s32	r6, $0, r7 ; a zero count: 0x80000001 sign-extended
	mov	$-2147483647, r8
	cbne r7, r8, fail28
	ror.s32	r6, $31, r7 ; the rotate of 0x80000001 by 31 = 3: bit 31 clear, positive
	cbne r7, $3, fail29
	mov	$0x12345678, r6
	ror.s32	r6, $8, r7 ; 0x78123456: bit 31 clear
	mov	$0x78123456, r8
	cbne r7, r8, fail30
	ror.s32	r6, $4, r6 ; rd = rs; 0x81234567: bit 31 set, 0xFFFFFFFF81234567
	mov	$-2128394905, r8
	cbne r6, r8, fail31
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
