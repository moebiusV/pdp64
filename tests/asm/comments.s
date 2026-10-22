; comments after instructions and directives, and a ; inside a string or character
	.text
	movq	#5, r1		; five
	add	r1, r2		; two operands
	bne	next		; a branch
next:	ret			; a label and an instruction
	.data
s:	.byte	"a;b", ';', 0	; the semicolons in the string and character are data
