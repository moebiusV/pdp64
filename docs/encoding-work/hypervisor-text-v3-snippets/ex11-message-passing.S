; 6.15 example 11: message passing.  The guest writes the data and then the flag; the hypervisor reads the flag and then the data.
; Both are in memory that the two share.  sim64 has one core, so this is an illustration of the order and of the shared words,
; not a test of two cores running at once: the hypervisor reads after the guest's hypercall has stopped the guest.  Run: sim64 -H
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	htab, r1
	mtsr	hvbr, r1
	lea	hcall, r2
	lea	htab+8*(VECTOR_TRAP_BASE+40), r1
	mov	r2, (r1)
	lea	hhalt, r2
	lea	htab+8*VECTOR_HEXIT, r1
	mov	r2, (r1)
	mov	=(2<<HTRAP_MASK), r1
	mtsr	htrap, r1
	lea	guest, r1
	mtsr	hepc, r1
	mov	#0, r1
	mtsr	hepsw, r1
	genter	#0
guest:	lea	data, r3
	lea	flag, r4
	mov	#42, r1
	mov	r1, (r3)			; first the data ...
	mov	#1, r1
	mov	r1, (r4)			; ... then the flag: "the data is ready"
	trap	#40				; tell the hypervisor to look (the reader needs no fence between its two loads)
	halt
hcall:	lea	flag, r4
	lea	data, r3
	mov	(r4), r1			; the reader: first the flag ...
	cbne	r1, #1, hbad			; not set: nothing to read yet
	mov	(r3), r2			; ... then the data
	cbeq	r2, #42, 1f			; the flag was set, so the data is the new data, never the old
	mov	#1, r0
	halt
1:	mov	#0, r0
	genter	#RTIMASK_NONE
hhalt:	mfsr	r20, hexitr
	cbeq	r20, #XCODE_HALT, 1f
	br	hbad
1:	mov	#0, r0
	halt
hbad:	mov	#98, r0
	halt
	.data
	.align	4096
htab:	.space	4096
	.align	8
data:	.quad	0
flag:	.quad	0
