; fneg32 and fabs32: the sign of a binary32 kept sign-extended in a register; assembler mappings of XOR and AND (they write N and Z as those do)
	.text
	.globl	_start
_start:
	movq	#0x3F800000, r1		; 1.0f
	fneg32	r1, r2
	movq	#0xFFFFFFFFBF800000, r3	; -1.0f, sign-extended
	cmp	r2, r3
	bne	f1
	cmp	r1, #0x3F800000		; the source is untouched
	bne	f2
	fneg32	r2, r2			; in place: back to 1.0f
	cmp	r2, r1
	bne	f3
	fabs32	r3, r4
	cmp	r4, r1
	bne	f4
	fabs32	r1, r1
	cmp	r1, #0x3F800000
	bne	f5
	movq	#0, r5			; +0.0f gives -0.0f, and the sum of a value and its negation is +0.0f
	fneg32	r5, r6
	movq	#0xFFFFFFFF80000000, r7
	cmp	r6, r7
	bne	f6
	movq	#0x40490FDB, r8		; pi as a binary32
	fneg32	r8, r9
	fadd32	r8, r9
	cmp	r9, #0
	bne	f7
	; the flags: XOR writes N and Z (V cleared, C unchanged)
	movq	#0x7F800000, r10	; +infinity: a positive result of the XOR is negative as an integer
	fneg32	r10, r10
	bpl	f8
	fabs32	r10, r11		; a positive result: N clear, Z clear
	bmi	f9
	beq	f10
	movq	#0xFFFFFFFF80000000, r12	; -0.0f sign-extended: fabs32 of it is zero, so Z is set
	fabs32	r12, r12
	bne	f11
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
