; the naming of the vector accumulators (what `vclr` sets) is cleared by every exception entry and every exception return (errata 186 decision 13, manual 6.14.9; the
; open item of errata 172), on the kernel-mode machine (sim64 -K).  The block `vld v8; vadd v0,v0,v8; vst v0` gives dst == src when v0 is an ordinary register (zero at the
; start of each strip) and running sums when v0 is named an accumulator (the strip of such a block is 16 bytes on every implementation, so four 32-bit lanes).
;   1  control: vclr, then the block: v0 is an accumulator, the sums run over the strips
;   2  vclr, an exception (trap #1: the handler runs no vector code), then the block: the entry cleared the naming, dst == src
;   4  vclr, an exception whose handler runs the block at once: the entry (not only the return) cleared the naming, dst == src
;   3  no vclr; an exception whose handler names accumulators with vclr outside any block; then the block: the return cleared it, dst == src
; (the restart of a faulting block after a handler that names accumulators is clob 4 of tests/sim/vec-restart.S)
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	; 1
	call	clear_dst
	vclr.l	v0, #1
	call	runblock
	call	expect_sums
	cbeq	r0, #0, 1f
	movq	#1, r0
	halt
1:
	; 2
	call	clear_dst
	vclr.l	v0, #1
	trap	#1
	call	runblock
	call	expect_copy
	cbeq	r0, #0, 1f
	movq	#2, r0
	halt
1:
	; 3
	call	clear_dst
	trap	#2
	call	runblock
	call	expect_copy
	cbeq	r0, #0, 1f
	movq	#3, r0
	halt
1:
	; 4
	call	clear_dst
	vclr.l	v0, #1
	trap	#3			; the handler runs the block at once: the entry cleared the naming, so v0 is an ordinary register there (the return would be too late)
	call	expect_copy
	cbeq	r0, #0, 1f
	movq	#4, r0
	halt
1:
	movq	#0, r0
	halt

clear_dst:
	lea	dst, r1
	movq	#0xa5, r2
	movq	#32, r3
	mset	r1, r2, r3
	ret
runblock:
	lea	src, r1
	lea	src+32, r5
	lea	dst, r3
	vec	r1, r5
	vld.l	v8, (r1)+
	vadd.l	v0, v0, v8
	vst.l	v0, (r3)+
	vend
	ret
; r0 = 0 if dst == src
expect_copy:
	lea	src, r1
	lea	dst, r2
	movq	#32, r3
1:	movzb	(r1)+, r4
	movzb	(r2)+, r5
	cbne	r4, r5, 2f
	sob	r3, 1b
	movq	#0, r0
	ret
2:	movq	#1, r0
	ret
; r0 = 0 if dst holds the running sums over the strips of 16 bytes (four 32-bit lanes): strip 0 = src[0..3], strip 1 = src[0..3] + src[4..7]
expect_sums:
	lea	src, r1
	lea	dst, r2
	movq	#4, r3
1:	movl	(r1)+, r4
	movl	(r2)+, r5
	cbne	r4, r5, 2f
	sob	r3, 1b
	lea	src, r1
	lea	dst+16, r2
	movq	#4, r3
3:	movl	(r1), r4
	movl	16(r1), r6
	add	r6, r4
	movl	(r2)+, r5
	cbne	r4, r5, 2f
	add	#4, r1
	sob	r3, 3b
	movq	#0, r0
	ret
2:	movq	#1, r0
	ret
h_trap1:
	rti	#RTIMASK_ALL
h_trap3:
	call	runblock
	rti	#RTIMASK_ALL
h_trap2:
	vclr.l	v0, #8
	vclr.l	v8, #8
	rti	#RTIMASK_ALL
h_bad:	movq	#99, r0
	halt
	.data
	.align	8
src:	.long	1, 2, 3, 4, 10, 20, 30, 40
	.long	100, 200, 300, 400, 1000, 2000, 3000, 4000
dst:	.space	32
	.align	8
vtab:
	.space	2048
	.quad	h_bad
	.quad	h_trap1
	.quad	h_trap2
	.quad	h_trap3
	.space	1000
