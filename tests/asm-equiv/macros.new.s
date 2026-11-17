	.macro twice a, b
	movq \a, \b
	movq \a, \b
	.endm
	.macro skipit
	br 1f
	clr r1
1:
	.endm
	.macro nested
	skipit
	.endm
DEBUG = 1
	.text
top:	twice #5, r2
	.rept 3
	inc r3
	.endr
	.if DEBUG
	movq #1, r4
	.else
	movq #2, r4
	.endif
	.if 0
	movq #9, r9
	.endif
	.if DEBUG
	.if 0
	movq #7, r7
	.else
here:	skipit
	.endif
	.endif
	nested
	ret
