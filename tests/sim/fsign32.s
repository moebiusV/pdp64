; fneg .32 and fabs .32: the sign of a binary32 kept sign-extended in a register; assembler mappings of XOR and AND (they write no flag)
	.text
	.globl	_start
_start:
	mov	$0x3F800000, r1		; 1.0f
	fneg.f32	r1, r2
	mov	$0xFFFFFFFFBF800000, r3	; -1.0f, sign-extended
	cbne r2, r3, f1
	mov	$0x3F800000, r13
	cbne	r1, r13, f2		; the source is untouched
	fneg.f32	r2, r2 ; in place: back to 1.0f
	cbne r2, r1, f3
	fabs.f32	r3, r4
	cbne r4, r1, f4
	fabs.f32	r1, r1
	cbne	r1, r13, f5
	mov	$0, r5			; +0.0f gives -0.0f, and the sum of a value and its negation is +0.0f
	fneg.f32	r5, r6
	mov	$0xFFFFFFFF80000000, r7
	cbne r6, r7, f6
	mov	$0x40490FDB, r8		; pi as a binary32
	fneg.f32	r8, r9
	fadd.f32	r8, r9
	cbne r9, $0, f7
	; the sign of the results as an integer
	mov	$0x7F800000, r10	; +infinity: fneg .32 gives a negative integer (sign-extended)
	fneg.f32	r10, r10
	cbge	r10, $0, f8
	fabs.f32	r10, r11 ; a positive result
	cblt	r11, $0, f9
	cbeq	r11, $0, f10
	mov	$0xFFFFFFFF80000000, r12	; -0.0f sign-extended: fabs .32 of it is zero
	fabs.f32	r12, r12
	cbne	r12, $0, f11
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
