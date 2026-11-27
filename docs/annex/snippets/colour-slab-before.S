; The slab chunk of a small allocator without colours, adapted from OpenBSD lib/libc/stdlib/malloc.c (malloc_bytes, free_bytes, find_chunknum), shortened:
; one page of equal chunks, a bitmap of the free ones (a set bit is a free chunk), no random choice, no canaries.
;   info:  0 page address   8 chunk size (a multiple of 16)   16 number of chunks   24 free chunks   32 bitmap
	.text
	.globl	slab_alloc, slab_free
slab_alloc:				; r1 = info; returns r0 = the chunk, or 0 when the page is full
	mov	32(r1), r2
	cbeq	r2, $0, full
	ctz	r2, r3			; r3 = the number of the first free chunk
	mov	$1, r4
	shl	r3, r4
	bic	r4, r2			; the chunk is taken
	mov	r2, 32(r1)
	mov	24(r1), r5
	sub	$1, r5
	mov	r5, 24(r1)
	mov	8(r1), r5
	mul	r3, r5
	add	(r1), r5
	mov	r5, r0
	ret
full:	mov	$0, r0
	ret
slab_free:				; r0 = the chunk, r1 = info
	mov	r0, r4
	sub	(r1), r4
	mov	8(r1), r5
	div.u64	r4, r5, r3		; r3 = the chunk number
	mov	$1, r4
	shl	r3, r4
	mov	32(r1), r2
	mov	r2, r6
	and	r4, r6
	cbne	r6, $0, double_free	; the bit says it is free already
	bis	r4, r2
	mov	r2, 32(r1)
	mov	24(r1), r5
	add	$1, r5
	mov	r5, 24(r1)
	ret
double_free:
	bpt
