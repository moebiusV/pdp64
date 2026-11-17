DEBUG = 1
	.text
top:	movq #5, r2
	movq #5, r2
	inc r3
	inc r3
	inc r3
	movq #1, r4
here:
	br 1f
	clr r1
1:
	br 1f
	clr r1
1:
	ret
