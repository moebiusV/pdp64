; A client of the coloured slab (colour-slab-after.S): a chunk of 32 bytes.  It is assembled, not run: the comments say what the machine does.
	.text
	.globl	client
client:	lea	info, r1
	call	slab_alloc		; chunk 0: colour (1 << 1) | 0 = 2, in r0
	mov	r0, r2
	call	slab_alloc		; chunk 1 is the next 32 bytes: colour (1 << 1) | 1 = 3, in r0
	mov	r0, r3
	mov	$0x41, r4
	mov	r4, 24(r2)		; inside chunk 0: fine
	mov	r4, 32(r2)		; one chunk too far: the granule is colour 3, the pointer 2: colour fault, nothing written
	mov	r2, r0
	call	slab_free		; the colour of chunk 0 is 2 and so is the pointer's: it is freed, and its colour becomes 15
	mov	(r2), r5		; use after free: colour 15 against 2: colour fault
	mov	r2, r0
	call	slab_free		; double free: the check in slab_free finds 15 against 2 and stops
	ret
	.data
	.align	8
info:	.quad	page, 32, 128, 128, -1
	.align	16
page:	.space	4096
