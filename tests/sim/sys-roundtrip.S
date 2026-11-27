; System v1: a null system call round trip, two ways.  The user executes trap #n; the kernel handler saves the exception state, does a null call (or one
; copyin-style load of a user word), restores the state and rti's back.  Handlers V1 (trap #5, #6) do it with mfsr/push/pop/mtsr, V2 (#7, #8) with pushx/popx.
; The test checks that both give the same architectural result: r0, every other register, and the stack pointer are as they should be.
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
	mov	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti	#RTIMASK_ALL
user:
	mov	#1001, r1
	mov	#1002, r2
	mov	#1003, r3
	mov	#1004, r4
	mov	#1005, r5
	mov	#1006, r6
	mov	#1007, r7
	mov	#1008, r8
	mov	#1009, r9
	mov	#1010, r10
	mov	#1011, r11
	mov	#1012, r12
	mov	#1013, r13
	mov	#0, r0
	.globl	rt_v1_null
rt_v1_null:	trap	#5
	.globl	ret_v1_null
ret_v1_null:
	cbne r0, #7, F2
	cbne r2, #1002, F3
	cbne r3, #1003, F4
	cbne r4, #1004, F5
	cbne r5, #1005, F6
	cbne r6, #1006, F7
	cbne r7, #1007, F8
	cbne r8, #1008, F9
	cbne r9, #1009, F10
	cbne r10, #1010, F11
	cbne r11, #1011, F12
	cbne r12, #1012, F13
	cbne r13, #1013, F14
	cbne r1, #1001, F15
	lea	word, r1
	mov	#1002, r2
	mov	#1003, r3
	mov	#1004, r4
	mov	#1005, r5
	mov	#1006, r6
	mov	#1007, r7
	mov	#1008, r8
	mov	#1009, r9
	mov	#1010, r10
	mov	#1011, r11
	mov	#1012, r12
	mov	#1013, r13
	mov	#0, r0
	.globl	rt_v1_copyin
rt_v1_copyin:	trap	#6
	.globl	ret_v1_copyin
ret_v1_copyin:
	cbne r0, #0x1234, F17
	cbne r2, #1002, F18
	cbne r3, #1003, F19
	cbne r4, #1004, F20
	cbne r5, #1005, F21
	cbne r6, #1006, F22
	cbne r7, #1007, F23
	cbne r8, #1008, F24
	cbne r9, #1009, F25
	cbne r10, #1010, F26
	cbne r11, #1011, F27
	cbne r12, #1012, F28
	cbne r13, #1013, F29
	lea	word, r11
	cbne r1, r11, F30
	mov	#1001, r1
	mov	#1002, r2
	mov	#1003, r3
	mov	#1004, r4
	mov	#1005, r5
	mov	#1006, r6
	mov	#1007, r7
	mov	#1008, r8
	mov	#1009, r9
	mov	#1010, r10
	mov	#1011, r11
	mov	#1012, r12
	mov	#1013, r13
	mov	#0, r0
	.globl	rt_v2_null
rt_v2_null:	trap	#7
	.globl	ret_v2_null
ret_v2_null:
	cbne r0, #7, F32
	cbne r2, #1002, F33
	cbne r3, #1003, F34
	cbne r4, #1004, F35
	cbne r5, #1005, F36
	cbne r6, #1006, F37
	cbne r7, #1007, F38
	cbne r8, #1008, F39
	cbne r9, #1009, F40
	cbne r10, #1010, F41
	cbne r11, #1011, F42
	cbne r12, #1012, F43
	cbne r13, #1013, F44
	cbne r1, #1001, F45
	lea	word, r1
	mov	#1002, r2
	mov	#1003, r3
	mov	#1004, r4
	mov	#1005, r5
	mov	#1006, r6
	mov	#1007, r7
	mov	#1008, r8
	mov	#1009, r9
	mov	#1010, r10
	mov	#1011, r11
	mov	#1012, r12
	mov	#1013, r13
	mov	#0, r0
	.globl	rt_v2_copyin
rt_v2_copyin:	trap	#8
	.globl	ret_v2_copyin
ret_v2_copyin:
	cbne r0, #0x1234, F47
	cbne r2, #1002, F48
	cbne r3, #1003, F49
	cbne r4, #1004, F50
	cbne r5, #1005, F51
	cbne r6, #1006, F52
	cbne r7, #1007, F53
	cbne r8, #1008, F54
	cbne r9, #1009, F55
	cbne r10, #1010, F56
	cbne r11, #1011, F57
	cbne r12, #1012, F58
	cbne r13, #1013, F59
	lea	word, r11
	cbne r1, r11, F60
	mov	#0, r0
	trap	#0
F1:	mov	#1, r0
	trap	#1
F2:	mov	#2, r0
	trap	#1
F3:	mov	#3, r0
	trap	#1
F4:	mov	#4, r0
	trap	#1
F5:	mov	#5, r0
	trap	#1
F6:	mov	#6, r0
	trap	#1
F7:	mov	#7, r0
	trap	#1
F8:	mov	#8, r0
	trap	#1
F9:	mov	#9, r0
	trap	#1
F10:	mov	#10, r0
	trap	#1
F11:	mov	#11, r0
	trap	#1
F12:	mov	#12, r0
	trap	#1
F13:	mov	#13, r0
	trap	#1
F14:	mov	#14, r0
	trap	#1
F15:	mov	#15, r0
	trap	#1
F16:	mov	#16, r0
	trap	#1
F17:	mov	#17, r0
	trap	#1
F18:	mov	#18, r0
	trap	#1
F19:	mov	#19, r0
	trap	#1
F20:	mov	#20, r0
	trap	#1
F21:	mov	#21, r0
	trap	#1
F22:	mov	#22, r0
	trap	#1
F23:	mov	#23, r0
	trap	#1
F24:	mov	#24, r0
	trap	#1
F25:	mov	#25, r0
	trap	#1
F26:	mov	#26, r0
	trap	#1
F27:	mov	#27, r0
	trap	#1
F28:	mov	#28, r0
	trap	#1
F29:	mov	#29, r0
	trap	#1
F30:	mov	#30, r0
	trap	#1
F31:	mov	#31, r0
	trap	#1
F32:	mov	#32, r0
	trap	#1
F33:	mov	#33, r0
	trap	#1
F34:	mov	#34, r0
	trap	#1
F35:	mov	#35, r0
	trap	#1
F36:	mov	#36, r0
	trap	#1
F37:	mov	#37, r0
	trap	#1
F38:	mov	#38, r0
	trap	#1
F39:	mov	#39, r0
	trap	#1
F40:	mov	#40, r0
	trap	#1
F41:	mov	#41, r0
	trap	#1
F42:	mov	#42, r0
	trap	#1
F43:	mov	#43, r0
	trap	#1
F44:	mov	#44, r0
	trap	#1
F45:	mov	#45, r0
	trap	#1
F46:	mov	#46, r0
	trap	#1
F47:	mov	#47, r0
	trap	#1
F48:	mov	#48, r0
	trap	#1
F49:	mov	#49, r0
	trap	#1
F50:	mov	#50, r0
	trap	#1
F51:	mov	#51, r0
	trap	#1
F52:	mov	#52, r0
	trap	#1
F53:	mov	#53, r0
	trap	#1
F54:	mov	#54, r0
	trap	#1
F55:	mov	#55, r0
	trap	#1
F56:	mov	#56, r0
	trap	#1
F57:	mov	#57, r0
	trap	#1
F58:	mov	#58, r0
	trap	#1
F59:	mov	#59, r0
	trap	#1
F60:	mov	#60, r0
	trap	#1
h_ok:	mov	#0, r0
h_fail:	halt
; V1: without pushx and popx.  The user's registers are live at entry: free r1, save EPC and EPSW through it, reload r1.
	.globl	h_v1_null
h_v1_null:
	push	r1
	mfsr	r1, epc
	push	r1
	mfsr	r1, epsw
	push	r1
	mov	16(sp), r1
	spl	#0
	mov	#7, r0				; the null call
	spl	#7
	pop	r1
	mtsr	epsw, r1
	pop	r1
	mtsr	epc, r1
	pop	r1
	.globl	h_v1_null_end
h_v1_null_end:
	rti	#RTIMASK_ALL
	.globl	h_v1_copyin
h_v1_copyin:
	push	r1
	mfsr	r1, epc
	push	r1
	mfsr	r1, epsw
	push	r1
	mov	16(sp), r1
	spl	#0
	mov	(r1), r0			; copyin: one load of a user word that cannot fault
	spl	#7
	pop	r1
	mtsr	epsw, r1
	pop	r1
	mtsr	epc, r1
	pop	r1
	rti	#RTIMASK_ALL
; V2: with pushx and popx: no scratch register is needed.
	.globl	h_v2_null
h_v2_null:
	pushx
	spl	#0
	mov	#7, r0
	spl	#7
	popx
	rti	#RTIMASK_ALL
	.globl	h_v2_copyin
h_v2_copyin:
	pushx
	spl	#0
	mov	(r1), r0
	spl	#7
	popx
	rti	#RTIMASK_ALL
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

