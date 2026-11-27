; The same chunk with colours.  A chunk's colour is (generation << 1) | (chunk number & 1), the generation 1 to 6; a free chunk is colour 15; the generation of the last
; occupant is kept in the first word of the free chunk, which only the allocator reaches, through a colour-15 pointer.
;   info:  0 page address   8 chunk size (a multiple of 16)   16 number of chunks   24 free chunks   32 bitmap
	.text
	.globl	slab_alloc, slab_free
slab_alloc:				; r1 = info; returns r0 = the chunk with its colour in bits 63 to 60, or 0 when the page is full
	mov	32(r1), r2
	cbeq	r2, $0, full
	ctz	r2, r3			; r3 = the number of the first free chunk
	mov	$1, r4
	shl	r3, r4
	bic	r4, r2
	mov	r2, 32(r1)
	mov	24(r1), r5
	sub	$1, r5
	mov	r5, 24(r1)
	mov	8(r1), r8		; r8 = the chunk size
	mov	r8, r5
	mul	r3, r5
	add	(r1), r5		; r5 = the address
	mov	r5, r6
	colset	$15, r6			; the allocator's pointer to a free chunk
	mov	(r6), r7		; the generation of the last occupant (0 in a new page)
	add	$1, r7
	cbgt	r7, $6, wrap
back:	shl	$1, r7
	and	$1, r3
	bis	r3, r7			; r7 = the new colour
	mov	r5, r0
	mcol	r5, r7, r8		; the whole chunk takes the colour
	colset	r7, r0			; and so does the pointer
	ret
wrap:	mov	$1, r7
	br	back
full:	mov	$0, r0
	ret
slab_free:				; r0 = the chunk as the program holds it, r1 = info
	ldcol	r0, r2			; the colour of the chunk now
	mov	r0, r3
	shr	$60, r3			; the colour of the pointer
	cbne	r2, r3, double_free	; a freed or reused chunk has another colour: double free or stale pointer
	colstrip r0, r4
	sub	(r1), r4
	mov	8(r1), r5
	div.u64	r4, r5, r6		; r6 = the chunk number
	mov	$1, r7
	shl	r6, r7
	mov	32(r1), r8
	bis	r7, r8
	mov	r8, 32(r1)
	mov	24(r1), r5
	add	$1, r5
	mov	r5, 24(r1)
	mov	8(r1), r5
	colstrip r0, r9
	mov	r9, r10
	mov	$15, r8
	mcol	r10, r8, r5		; the chunk is colour 15
	colset	$15, r9
	shr	$1, r3			; the generation it had
	mov	r3, (r9)		; kept for the next allocation
	ret
double_free:
	bpt
