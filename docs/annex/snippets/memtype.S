; Two leaf entries for the same page of memory: the guest's own table says cached, the hypervisor's second stage says uncached.
; The access is uncached: the stricter of the two stages counts.
#include "pdp64-consts.h"
#define LEAF(page, mt) (((page)<<PTE_PPN) | (1<<PTE_V)|(1<<PTE_R)|(1<<PTE_W)|((mt)<<PTE_MT))
	.text
	.globl	_start
_start:
	movq	=LEAF(0x1234, MT_CACHED), r1		; stage 1: written by the guest kernel
	movq	=LEAF(0x8f7, MT_UNCACHED), r2		; stage 2: written by the hypervisor, this page is a DMA buffer
	halt
