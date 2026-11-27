; granule colours: the stray write and the stale pointer, using alloc and free of malloc-free.S (r4 = the first block's pointer, colour 5; the next block has colour 6).
	.text
	mov	$7, r0
	mov	r0, (r4)	; fine: pointer colour 5, granule colour 5
	mov	r0, 24(r4)	; fine: the second granule of the same block
	mov	r0, 32(r4)	; one block too far: the granule has colour 6, the pointer 5: a colour fault, nothing is written
	mov	(r4), r1	; after free(r4) this faults too: the granule has colour 15
