; granule colours: a toy malloc and free for 32-byte blocks (the worked example of the section "Colours: the stray write and the stale pointer").
; Every block is two 16-byte granules.  r1 is the address of a free block, r2 the colour the allocator chose for it.
	.text
alloc:				; r1 = a free block, r2 = its colour; returns the pointer, colour included, in r0
	mov	r1, r4		; the address I will hand out
	mov	$32, r3		; the length of the block in bytes
	mcol	r1, r2, r3	; both granules of the block get the colour in r2 (r1 and r3 are used up)
	colset	r2, r4		; the colour goes into bits 63 to 60 of the pointer
	mov	r4, r0
	ret

free:				; r0 = the pointer the program was given
	ldcol	r0, r1		; the colour the block has in memory
	mov	r0, r2
	shr	$60, r2		; the colour the pointer carries
	cbne	r1, r2, wrong	; they differ: a second free, or a pointer that is not a block of mine
	mov	$15, r1		; colour 15 is "freed": no pointer I hand out has it
	mov	$32, r3
	mcol	r0, r1, r3
	ret
wrong:
	halt			; a double free or a wild pointer stops here
