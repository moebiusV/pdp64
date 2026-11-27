; An allocator that has no slots: choose a colour for a block of r2 bytes at r1 that differs from the granule before it, the granule after it, and the block's old colour r3.
; At most three colours are excluded and 1 to 14 are allowed, so the loop ends within four tries.  Returns the colour in r0.
	.text
	.globl	pick_colour
pick_colour:
	mov	r1, r4
	sub	$16, r4
	ldcol	r4, r5			; the colour just below the block
	mov	r1, r6
	add	r2, r6
	ldcol	r6, r7			; the colour just above it
	mov	$1, r0
try:	cbeq	r0, r5, next
	cbeq	r0, r7, next
	cbeq	r0, r3, next
	ret
next:	add	$1, r0
	br	try
