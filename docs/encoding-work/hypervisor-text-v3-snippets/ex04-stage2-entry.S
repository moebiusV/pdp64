; 6.15 examples 4 and 6: the hypervisor's answer to "second-stage fault, entry invalid" for guest-physical page 0x123: it writes the stage-2 entry (real page 0x8F7) in a
; table inside its arena and enters the guest, which runs the same load again.  The store into the arena sets the hardware's flag; the next GENTER discards the guest's
; translations by itself.  Assembled only (it needs the page tables of a whole guest; the same steps run in tests/qemu/hv-first.S).
#include "pdp64-consts.h"
#define LEAF (1<<PTE_V|1<<PTE_R|1<<PTE_W|1<<PTE_X|1<<PTE_A|1<<PTE_D)
	.text
	.globl	_start
_start:
	mfsr	r21, hgpa			; the guest-physical address that failed: 0x123A58
	mov	=0xfffffffff000, r22
	and	r21, r22			; its page: 0x123000
	shr	$12, r22			; the page number 0x123 is the index into the last-level table
	mov	=0x1ff, r23
	and	r23, r22			; the last-level index, 0x123 & 0x1ff
	shl	$3, r22				; 8 bytes to an entry
	lea	s2leaf, r24			; the last-level stage-2 table, inside the arena
	add	r24, r22
	mov	=(0x8f7000|LEAF), r23		; real page 0x8F7, permitted
	mov	r23, (r22)			; a store into the arena: the flag is set
	genter	$0				; the guest runs the load again; the entry is found
	.data
	.align	4096
s2leaf:	.space	4096
