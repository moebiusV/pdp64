; System v1 user mode (sim64 -K): the kernel enters user mode with rti; the privileged instructions abort with vector 3; mtps writes the flags only; trap, trapl and bpt enter the kernel at
; vector 256 + n and 15; the stack pointer and DP are banked per mode (usp seen from the kernel, changed while the user is stopped); the supervisor mode has its own bank.  Generated.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	movq	sp, ksp_saved
	lea	ustack_top, r1
	mtsr	usp, r1
	movq	#0x1111, r1
	mtdp	r1
	lea	user, r1
	mtsr	epc, r1
	movq	#(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti
user:
	mfps	r1
	cmp	r1, #(MODE_USER<<PSW_MODE)
	bne	F1	; check 1
	lea	ustack_top, r11
	cmp	sp, r11
	bne	F2	; check 2
	mfdp	r1
	cmp	r1, #(0)
	bne	F3	; check 3
	movq	#0x2222, r1
	mtdp	r1
	mfdp	r5
	cmp	r5, #(8738)
	bne	F4	; check 4
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr0, r4
pi0:
	mfsr	r1, ptbr
pr0:
	cmp	r10, #(1)
	bne	F5	; check 5
	lea	pi0, r11
	cmp	r6, r11
	bne	F6	; check 6
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F7	; check 7
	cmp	r9, #(0)
	bne	F8	; check 8
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F9	; check 9
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F10	; check 10
	movq	ksp_saved, r1
	cmp	r13, r1
	bne	F11	; check 11
	cmp	r2, #(4369)
	bne	F12	; check 12
	cmp	r3, sp
	bne	F13	; check 13
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr1, r4
pi1:
	mtsr	ptbr, r1
pr1:
	cmp	r10, #(1)
	bne	F14	; check 14
	lea	pi1, r11
	cmp	r6, r11
	bne	F15	; check 15
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F16	; check 16
	cmp	r9, #(0)
	bne	F17	; check 17
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F18	; check 18
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F19	; check 19
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr2, r4
pi2:
	spl	#5
pr2:
	cmp	r10, #(1)
	bne	F20	; check 20
	lea	pi2, r11
	cmp	r6, r11
	bne	F21	; check 21
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F22	; check 22
	cmp	r9, #(0)
	bne	F23	; check 23
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F24	; check 24
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F25	; check 25
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr3, r4
pi3:
	halt
pr3:
	cmp	r10, #(1)
	bne	F26	; check 26
	lea	pi3, r11
	cmp	r6, r11
	bne	F27	; check 27
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F28	; check 28
	cmp	r9, #(0)
	bne	F29	; check 29
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F30	; check 30
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F31	; check 31
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr4, r4
pi4:
	rti
pr4:
	cmp	r10, #(1)
	bne	F32	; check 32
	lea	pi4, r11
	cmp	r6, r11
	bne	F33	; check 33
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F34	; check 34
	cmp	r9, #(0)
	bne	F35	; check 35
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F36	; check 36
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F37	; check 37
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr5, r4
pi5:
	rtt
pr5:
	cmp	r10, #(1)
	bne	F38	; check 38
	lea	pi5, r11
	cmp	r6, r11
	bne	F39	; check 39
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F40	; check 40
	cmp	r9, #(0)
	bne	F41	; check 41
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F42	; check 42
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F43	; check 43
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr6, r4
pi6:
	tlbi	r1
pr6:
	cmp	r10, #(1)
	bne	F44	; check 44
	lea	pi6, r11
	cmp	r6, r11
	bne	F45	; check 45
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F46	; check 46
	cmp	r9, #(0)
	bne	F47	; check 47
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F48	; check 48
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F49	; check 49
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr7, r4
pi7:
	tlbia
pr7:
	cmp	r10, #(1)
	bne	F50	; check 50
	lea	pi7, r11
	cmp	r6, r11
	bne	F51	; check 51
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F52	; check 52
	cmp	r9, #(0)
	bne	F53	; check 53
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F54	; check 54
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F55	; check 55
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr8, r4
pi8:
	tlbsync
pr8:
	cmp	r10, #(1)
	bne	F56	; check 56
	lea	pi8, r11
	cmp	r6, r11
	bne	F57	; check 57
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F58	; check 58
	cmp	r9, #(0)
	bne	F59	; check 59
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F60	; check 60
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F61	; check 61
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr9, r4
pi9:
	mtasid	r1
pr9:
	cmp	r10, #(1)
	bne	F62	; check 62
	lea	pi9, r11
	cmp	r6, r11
	bne	F63	; check 63
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F64	; check 64
	cmp	r9, #(0)
	bne	F65	; check 65
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F66	; check 66
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F67	; check 67
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr10, r4
pi10:
	mfasid	r1
pr10:
	cmp	r10, #(1)
	bne	F68	; check 68
	lea	pi10, r11
	cmp	r6, r11
	bne	F69	; check 69
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F70	; check 70
	cmp	r9, #(0)
	bne	F71	; check 71
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F72	; check 72
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F73	; check 73
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr11, r4
pi11:
	mtdmw	r1
pr11:
	cmp	r10, #(1)
	bne	F74	; check 74
	lea	pi11, r11
	cmp	r6, r11
	bne	F75	; check 75
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F76	; check 76
	cmp	r9, #(0)
	bne	F77	; check 77
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F78	; check 78
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F79	; check 79
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr12, r4
pi12:
	wfe
pr12:
	cmp	r10, #(1)
	bne	F80	; check 80
	lea	pi12, r11
	cmp	r6, r11
	bne	F81	; check 81
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F82	; check 82
	cmp	r9, #(0)
	bne	F83	; check 83
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F84	; check 84
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F85	; check 85
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr13, r4
pi13:
	pushx
pr13:
	cmp	r10, #(1)
	bne	F86	; check 86
	lea	pi13, r11
	cmp	r6, r11
	bne	F87	; check 87
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F88	; check 88
	cmp	r9, #(0)
	bne	F89	; check 89
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F90	; check 90
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F91	; check 91
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr14, r4
pi14:
	popx
pr14:
	cmp	r10, #(1)
	bne	F92	; check 92
	lea	pi14, r11
	cmp	r6, r11
	bne	F93	; check 93
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F94	; check 94
	cmp	r9, #(0)
	bne	F95	; check 95
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F96	; check 96
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F97	; check 97
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr15, r4
pi15:
	prober	r2, r1
pr15:
	cmp	r10, #(1)
	bne	F98	; check 98
	lea	pi15, r11
	cmp	r6, r11
	bne	F99	; check 99
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F100	; check 100
	cmp	r9, #(0)
	bne	F101	; check 101
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F102	; check 102
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F103	; check 103
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	movq	#0, r2
	movq	#0, r3
	movq	#0, r13
	lea	pr16, r4
pi16:
	probew	r2, r1
pr16:
	cmp	r10, #(1)
	bne	F104	; check 104
	lea	pi16, r11
	cmp	r6, r11
	bne	F105	; check 105
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F106	; check 106
	cmp	r9, #(0)
	bne	F107	; check 107
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F108	; check 108
	cmp	r12, #((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI))
	bne	F109	; check 109
	mfdp	r5
	cmp	r5, #(8738)
	bne	F110	; check 110
	movq	#0xFFF, r1
	mtps	r1
	mfps	r5
	cmp	r5, #((MODE_USER<<PSW_MODE)|15)
	bne	F111	; check 111
	movq	#0, r1
	mtps	r1
	mfps	r5
	cmp	r5, #(MODE_USER<<PSW_MODE)
	bne	F112	; check 112
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	nop
	fence
	sev
	icinva
	icinv	r1
	mfcpuid	r1
	movq	#7, r1
	mtdp	r1
	mfdp	r5
	push	r1
	pop	r5
	cmp	r10, #(0)
	bne	F113	; check 113
	cmp	r5, #(7)
	bne	F114	; check 114
	movq	#0x2222, r1
	mtdp	r1
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#5
aft1:
	cmp	r10, #(1)
	bne	F115	; check 115
	lea	aft1, r11
	cmp	r6, r11
	bne	F116	; check 116
	cmp	r8, #(VECTOR_TRAP_BASE+5)
	bne	F117	; check 117
	bic	#15, r7
	cmp	r7, #((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV))
	bne	F118	; check 118
	cmp	r9, #(0)
	bne	F119	; check 119
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	trap	#200
aft2:
	cmp	r10, #(1)
	bne	F120	; check 120
	lea	aft2, r11
	cmp	r6, r11
	bne	F121	; check 121
	cmp	r8, #(VECTOR_TRAP_BASE+200)
	bne	F122	; check 122
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	bpt
aft3:
	cmp	r10, #(1)
	bne	F123	; check 123
	lea	aft3, r11
	cmp	r6, r11
	bne	F124	; check 124
	cmp	r8, #(VECTOR_BPT)
	bne	F125	; check 125
	mfdp	r5
	cmp	r5, #(8738)
	bne	F126	; check 126
	trap	#7
	lea	ustack_alt, r11
	cmp	sp, r11
	bne	F127	; check 127
	trap	#8
	movq	#99, r0
	trap	#1
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
F61:	movq	#61, r0
	trap	#1
F62:	movq	#62, r0
	trap	#1
F63:	movq	#63, r0
	trap	#1
F64:	movq	#64, r0
	trap	#1
F65:	movq	#65, r0
	trap	#1
F66:	movq	#66, r0
	trap	#1
F67:	movq	#67, r0
	trap	#1
F68:	movq	#68, r0
	trap	#1
F69:	movq	#69, r0
	trap	#1
F70:	movq	#70, r0
	trap	#1
F71:	movq	#71, r0
	trap	#1
F72:	movq	#72, r0
	trap	#1
F73:	movq	#73, r0
	trap	#1
F74:	movq	#74, r0
	trap	#1
F75:	movq	#75, r0
	trap	#1
F76:	movq	#76, r0
	trap	#1
F77:	movq	#77, r0
	trap	#1
F78:	movq	#78, r0
	trap	#1
F79:	movq	#79, r0
	trap	#1
F80:	movq	#80, r0
	trap	#1
F81:	movq	#81, r0
	trap	#1
F82:	movq	#82, r0
	trap	#1
F83:	movq	#83, r0
	trap	#1
F84:	movq	#84, r0
	trap	#1
F85:	movq	#85, r0
	trap	#1
F86:	movq	#86, r0
	trap	#1
F87:	movq	#87, r0
	trap	#1
F88:	movq	#88, r0
	trap	#1
F89:	movq	#89, r0
	trap	#1
F90:	movq	#90, r0
	trap	#1
F91:	movq	#91, r0
	trap	#1
F92:	movq	#92, r0
	trap	#1
F93:	movq	#93, r0
	trap	#1
F94:	movq	#94, r0
	trap	#1
F95:	movq	#95, r0
	trap	#1
F96:	movq	#96, r0
	trap	#1
F97:	movq	#97, r0
	trap	#1
F98:	movq	#98, r0
	trap	#1
F99:	movq	#99, r0
	trap	#1
F100:	movq	#100, r0
	trap	#1
F101:	movq	#101, r0
	trap	#1
F102:	movq	#102, r0
	trap	#1
F103:	movq	#103, r0
	trap	#1
F104:	movq	#104, r0
	trap	#1
F105:	movq	#105, r0
	trap	#1
F106:	movq	#106, r0
	trap	#1
F107:	movq	#107, r0
	trap	#1
F108:	movq	#108, r0
	trap	#1
F109:	movq	#109, r0
	trap	#1
F110:	movq	#110, r0
	trap	#1
F111:	movq	#111, r0
	trap	#1
F112:	movq	#112, r0
	trap	#1
F113:	movq	#113, r0
	trap	#1
F114:	movq	#114, r0
	trap	#1
F115:	movq	#115, r0
	trap	#1
F116:	movq	#116, r0
	trap	#1
F117:	movq	#117, r0
	trap	#1
F118:	movq	#118, r0
	trap	#1
F119:	movq	#119, r0
	trap	#1
F120:	movq	#120, r0
	trap	#1
F121:	movq	#121, r0
	trap	#1
F122:	movq	#122, r0
	trap	#1
F123:	movq	#123, r0
	trap	#1
F124:	movq	#124, r0
	trap	#1
F125:	movq	#125, r0
	trap	#1
F126:	movq	#126, r0
	trap	#1
F127:	movq	#127, r0
	trap	#1
sup:
	mfps	r1
	cmp	r1, #(MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV)
	bne	F201	; check 201
	lea	sstack_top, r11
	cmp	sp, r11
	bne	F202	; check 202
	movq	#0, r4
	movq	#0, r10
	movq	#0, r6
	movq	#0, r7
	movq	#0, r8
	movq	#0, r9
	movq	#0, r12
	lea	sr1, r4
sp1:
	mfsr	r1, ptbr
sr1:
	cmp	r10, #(1)
	bne	F203	; check 203
	lea	sp1, r11
	cmp	r6, r11
	bne	F204	; check 204
	cmp	r8, #(VECTOR_PRIVILEGED)
	bne	F205	; check 205
	bic	#15, r7
	cmp	r7, #((MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV))
	bne	F206	; check 206
	movq	#0, r0
	trap	#0
F201:	movq	#201, r0
	trap	#1
F202:	movq	#202, r0
	trap	#1
F203:	movq	#203, r0
	trap	#1
F204:	movq	#204, r0
	trap	#1
F205:	movq	#205, r0
	trap	#1
F206:	movq	#206, r0
	trap	#1
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	mfsr	r9, eva
	mfsr	r3, usp
	mfdp	r2
	movq	sp, r13
	add	#1, r10
	cbeq	r4, #0, 1f
	mtsr	epc, r4
1:	rti
h_ok:	movq	#0, r0
h_fail:	halt
h_k7:	lea	ustack_alt, r1
	mtsr	usp, r1
	rti
h_k8:	lea	sstack_top, r1
	mtsr	ssp, r1
	lea	sup, r1
	mtsr	epc, r1
	movq	#(MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV), r1
	mtsr	epsw, r1
	rti
	.data
	.align	8
vtab:
	.space	24
	.quad	h_gen
	.space	88
	.quad	h_gen
	.space	1920
	.quad	h_ok
	.quad	h_fail
	.space	24
	.quad	h_gen
	.space	8
	.quad	h_k7
	.quad	h_k8
	.space	1528
	.quad	h_gen
	.space	440
	.align	8
ksp_saved:	.quad	0
ustack:	.space	256
ustack_top:
ustack_alt:	.space	256
sstack_top:
