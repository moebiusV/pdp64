; 6.15 example 1 as the text writes it: the new spellings (HARENA, HEPOCH, the NEW bit of GTBR).  Assembled only.
#include "pdp64-consts.h"
#define GTBR_NEW 1
	.text
	.globl	_start
_start:
	lea	arena, r1
	shr	#12, r1
	shl	#28, r1
	bis	#16, r1
	mtsr	harena, r1
	lea	hepoch_word, r1
	mtsr	hepoch, r1
	lea	hroot, r1
	mov	=(1<<GTBR_S2EN | 1<<GTBR_NEW), r2
	bis	r2, r1
	mtsr	gtbr, r1
	mov	=(1<<HTRAP_WFE | 1<<HTRAP_PTBR), r1
	mtsr	htrap, r1
	lea	_start, r1
	mtsr	hepc, r1
	mov	#0, r1
	mtsr	hepsw, r1
	genter	#0
	.data
hepoch_word:	.quad	0
	.align	4096
arena:	.space	65536
hroot:	.space	4096
