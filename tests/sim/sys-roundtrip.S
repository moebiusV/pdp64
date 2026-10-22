; System v1: a null system call round trip, two ways.  The user executes trap #n; the kernel handler saves the exception state, does a null call (or one
; copyin-style load of a user word), restores the state and rti's back.  Handlers V1 (trap #5, #6) do it with mfsr/push/pop/mtsr, V2 (#7, #8) with pushx/popx.
; The test checks that both give the same architectural result: r0, every other register, the stack pointer and the flags are as they should be.
; The numbers of instructions, bytes and memory accesses of the two are measured from this program by the script in the report (sim64 -K -t).  Generated.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	lea	ustk_top, r1
	mtsr	usp, r1
	lea	user, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti
user:
	movq	#1001, r1
	movq	#1002, r2
	movq	#1003, r3
	movq	#1004, r4
	movq	#1005, r5
	movq	#1006, r6
	movq	#1007, r7
	movq	#1008, r8
	movq	#1009, r9
	movq	#1010, r10
	movq	#1011, r11
	movq	#1012, r12
	movq	#1013, r13
	movq	#0, r0
	cmp	r2, r2
	.globl	rt_v1_null
rt_v1_null:	trap	#5
	.globl	ret_v1_null
ret_v1_null:	bne	F1
	cmp	r0, #7
	bne	F2
	cmp	r2, #1002
	bne	F3
	cmp	r3, #1003
	bne	F4
	cmp	r4, #1004
	bne	F5
	cmp	r5, #1005
	bne	F6
	cmp	r6, #1006
	bne	F7
	cmp	r7, #1007
	bne	F8
	cmp	r8, #1008
	bne	F9
	cmp	r9, #1009
	bne	F10
	cmp	r10, #1010
	bne	F11
	cmp	r11, #1011
	bne	F12
	cmp	r12, #1012
	bne	F13
	cmp	r13, #1013
	bne	F14
	cmp	r1, #1001
	bne	F15
	lea	word, r1
	movq	#1002, r2
	movq	#1003, r3
	movq	#1004, r4
	movq	#1005, r5
	movq	#1006, r6
	movq	#1007, r7
	movq	#1008, r8
	movq	#1009, r9
	movq	#1010, r10
	movq	#1011, r11
	movq	#1012, r12
	movq	#1013, r13
	movq	#0, r0
	cmp	r2, r2
	.globl	rt_v1_copyin
rt_v1_copyin:	trap	#6
	.globl	ret_v1_copyin
ret_v1_copyin:	bne	F16
	cmp	r0, #0x1234
	bne	F17
	cmp	r2, #1002
	bne	F18
	cmp	r3, #1003
	bne	F19
	cmp	r4, #1004
	bne	F20
	cmp	r5, #1005
	bne	F21
	cmp	r6, #1006
	bne	F22
	cmp	r7, #1007
	bne	F23
	cmp	r8, #1008
	bne	F24
	cmp	r9, #1009
	bne	F25
	cmp	r10, #1010
	bne	F26
	cmp	r11, #1011
	bne	F27
	cmp	r12, #1012
	bne	F28
	cmp	r13, #1013
	bne	F29
	lea	word, r11
	cmp	r1, r11
	bne	F30
	movq	#1001, r1
	movq	#1002, r2
	movq	#1003, r3
	movq	#1004, r4
	movq	#1005, r5
	movq	#1006, r6
	movq	#1007, r7
	movq	#1008, r8
	movq	#1009, r9
	movq	#1010, r10
	movq	#1011, r11
	movq	#1012, r12
	movq	#1013, r13
	movq	#0, r0
	cmp	r2, r2
	.globl	rt_v2_null
rt_v2_null:	trap	#7
	.globl	ret_v2_null
ret_v2_null:	bne	F31
	cmp	r0, #7
	bne	F32
	cmp	r2, #1002
	bne	F33
	cmp	r3, #1003
	bne	F34
	cmp	r4, #1004
	bne	F35
	cmp	r5, #1005
	bne	F36
	cmp	r6, #1006
	bne	F37
	cmp	r7, #1007
	bne	F38
	cmp	r8, #1008
	bne	F39
	cmp	r9, #1009
	bne	F40
	cmp	r10, #1010
	bne	F41
	cmp	r11, #1011
	bne	F42
	cmp	r12, #1012
	bne	F43
	cmp	r13, #1013
	bne	F44
	cmp	r1, #1001
	bne	F45
	lea	word, r1
	movq	#1002, r2
	movq	#1003, r3
	movq	#1004, r4
	movq	#1005, r5
	movq	#1006, r6
	movq	#1007, r7
	movq	#1008, r8
	movq	#1009, r9
	movq	#1010, r10
	movq	#1011, r11
	movq	#1012, r12
	movq	#1013, r13
	movq	#0, r0
	cmp	r2, r2
	.globl	rt_v2_copyin
rt_v2_copyin:	trap	#8
	.globl	ret_v2_copyin
ret_v2_copyin:	bne	F46
	cmp	r0, #0x1234
	bne	F47
	cmp	r2, #1002
	bne	F48
	cmp	r3, #1003
	bne	F49
	cmp	r4, #1004
	bne	F50
	cmp	r5, #1005
	bne	F51
	cmp	r6, #1006
	bne	F52
	cmp	r7, #1007
	bne	F53
	cmp	r8, #1008
	bne	F54
	cmp	r9, #1009
	bne	F55
	cmp	r10, #1010
	bne	F56
	cmp	r11, #1011
	bne	F57
	cmp	r12, #1012
	bne	F58
	cmp	r13, #1013
	bne	F59
	lea	word, r11
	cmp	r1, r11
	bne	F60
	movq	#0, r0
	trap	#0
F1:	movq	#1, r0
	trap	#1
F2:	movq	#2, r0
	trap	#1
F3:	movq	#3, r0
	trap	#1
F4:	movq	#4, r0
	trap	#1
F5:	movq	#5, r0
	trap	#1
F6:	movq	#6, r0
	trap	#1
F7:	movq	#7, r0
	trap	#1
F8:	movq	#8, r0
	trap	#1
F9:	movq	#9, r0
	trap	#1
F10:	movq	#10, r0
	trap	#1
F11:	movq	#11, r0
	trap	#1
F12:	movq	#12, r0
	trap	#1
F13:	movq	#13, r0
	trap	#1
F14:	movq	#14, r0
	trap	#1
F15:	movq	#15, r0
	trap	#1
F16:	movq	#16, r0
	trap	#1
F17:	movq	#17, r0
	trap	#1
F18:	movq	#18, r0
	trap	#1
F19:	movq	#19, r0
	trap	#1
F20:	movq	#20, r0
	trap	#1
F21:	movq	#21, r0
	trap	#1
F22:	movq	#22, r0
	trap	#1
F23:	movq	#23, r0
	trap	#1
F24:	movq	#24, r0
	trap	#1
F25:	movq	#25, r0
	trap	#1
F26:	movq	#26, r0
	trap	#1
F27:	movq	#27, r0
	trap	#1
F28:	movq	#28, r0
	trap	#1
F29:	movq	#29, r0
	trap	#1
F30:	movq	#30, r0
	trap	#1
F31:	movq	#31, r0
	trap	#1
F32:	movq	#32, r0
	trap	#1
F33:	movq	#33, r0
	trap	#1
F34:	movq	#34, r0
	trap	#1
F35:	movq	#35, r0
	trap	#1
F36:	movq	#36, r0
	trap	#1
F37:	movq	#37, r0
	trap	#1
F38:	movq	#38, r0
	trap	#1
F39:	movq	#39, r0
	trap	#1
F40:	movq	#40, r0
	trap	#1
F41:	movq	#41, r0
	trap	#1
F42:	movq	#42, r0
	trap	#1
F43:	movq	#43, r0
	trap	#1
F44:	movq	#44, r0
	trap	#1
F45:	movq	#45, r0
	trap	#1
F46:	movq	#46, r0
	trap	#1
F47:	movq	#47, r0
	trap	#1
F48:	movq	#48, r0
	trap	#1
F49:	movq	#49, r0
	trap	#1
F50:	movq	#50, r0
	trap	#1
F51:	movq	#51, r0
	trap	#1
F52:	movq	#52, r0
	trap	#1
F53:	movq	#53, r0
	trap	#1
F54:	movq	#54, r0
	trap	#1
F55:	movq	#55, r0
	trap	#1
F56:	movq	#56, r0
	trap	#1
F57:	movq	#57, r0
	trap	#1
F58:	movq	#58, r0
	trap	#1
F59:	movq	#59, r0
	trap	#1
F60:	movq	#60, r0
	trap	#1
h_ok:	movq	#0, r0
h_fail:	halt
; V1: without pushx and popx.  The user's registers are live at entry: free r1, save EPC and EPSW through it, reload r1.
	.globl	h_v1_null
h_v1_null:
	push	r1
	mfsr	r1, epc
	push	r1
	mfsr	r1, epsw
	push	r1
	movq	16(sp), r1
	spl	#0
	movq	#7, r0				; the null call
	spl	#7
	pop	r1
	mtsr	epsw, r1
	pop	r1
	mtsr	epc, r1
	pop	r1
	.globl	h_v1_null_end
h_v1_null_end:
	rti
	.globl	h_v1_copyin
h_v1_copyin:
	push	r1
	mfsr	r1, epc
	push	r1
	mfsr	r1, epsw
	push	r1
	movq	16(sp), r1
	spl	#0
	movq	(r1), r0			; copyin: one load of a user word that cannot fault
	spl	#7
	pop	r1
	mtsr	epsw, r1
	pop	r1
	mtsr	epc, r1
	pop	r1
	rti
; V2: with pushx and popx: no scratch register is needed.
	.globl	h_v2_null
h_v2_null:
	pushx
	spl	#0
	movq	#7, r0
	spl	#7
	popx
	rti
	.globl	h_v2_copyin
h_v2_copyin:
	pushx
	spl	#0
	movq	(r1), r0
	spl	#7
	popx
	rti
	.data
	.align	8
vtab:
	.space	2048
	.quad	h_ok
	.quad	h_fail
	.space	24
	.quad	h_v1_null
	.quad	h_v1_copyin
	.quad	h_v2_null
	.quad	h_v2_copyin
	.space	1976

	.align	8
word:	.quad	0x1234
ustk:	.space	256
ustk_top:

