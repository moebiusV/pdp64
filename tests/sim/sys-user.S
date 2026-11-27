; System v1 user mode (sim64 -K): the kernel enters user mode with rti; the privileged instructions abort with vector 3; mtps is privileged; trap (a small and a large vector number) and bpt enter the kernel at
; vector 256 + n and 15; the stack pointer and DP are banked per mode (usp seen from the kernel, changed while the user is stopped); the supervisor mode has its own bank.  Generated.
#include "pdp64-consts.h"
	.text
	.globl	_start
_start:
	lea	vtab, r1
	mtsr	vbr, r1
	mov	sp, ksp_saved
	lea	ustack_top, r1
	mtsr	usp, r1
	mov	$0x1111, r1
	mtdp	r1
	lea	user, r1
	mtsr	epc, r1
	mov	$(MODE_USER<<PSW_MODE), r1
	mtsr	epsw, r1
	rti	$RTIMASK_ALL
user:
	mfps	r1
	cbne r1, $(MODE_USER<<PSW_MODE), F1 ; check 1
	lea	ustack_top, r11
	cbne sp, r11, F2 ; check 2
	mfdp	r1
	cbne r1, $(0), F3 ; check 3
	mov	$0x2222, r1
	mtdp	r1
	mfdp	r5
	cbne r5, $(8738), F4 ; check 4
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr0, r4
pi0:
	mfsr	r1, ptbr
pr0:
	cbne r10, $(1), F5 ; check 5
	lea	pi0, r11
	cbne r6, r11, F6 ; check 6
	cbne r8, $(VECTOR_PRIVILEGED), F7 ; check 7
	cbne r9, $(0), F8 ; check 8
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F9 ; check 9
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F10 ; check 10
	mov	ksp_saved, r1
	cbne r13, r1, F11 ; check 11
	cbne r2, $(4369), F12 ; check 12
	cbne r3, sp, F13 ; check 13
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr1, r4
pi1:
	mtsr	ptbr, r1
pr1:
	cbne r10, $(1), F14 ; check 14
	lea	pi1, r11
	cbne r6, r11, F15 ; check 15
	cbne r8, $(VECTOR_PRIVILEGED), F16 ; check 16
	cbne r9, $(0), F17 ; check 17
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F18 ; check 18
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F19 ; check 19
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr2, r4
pi2:
	spl	$5
pr2:
	cbne r10, $(1), F20 ; check 20
	lea	pi2, r11
	cbne r6, r11, F21 ; check 21
	cbne r8, $(VECTOR_PRIVILEGED), F22 ; check 22
	cbne r9, $(0), F23 ; check 23
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F24 ; check 24
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F25 ; check 25
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr3, r4
pi3:
	halt
pr3:
	cbne r10, $(1), F26 ; check 26
	lea	pi3, r11
	cbne r6, r11, F27 ; check 27
	cbne r8, $(VECTOR_PRIVILEGED), F28 ; check 28
	cbne r9, $(0), F29 ; check 29
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F30 ; check 30
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F31 ; check 31
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr4, r4
pi4:
	rti	$RTIMASK_ALL
pr4:
	cbne r10, $(1), F32 ; check 32
	lea	pi4, r11
	cbne r6, r11, F33 ; check 33
	cbne r8, $(VECTOR_PRIVILEGED), F34 ; check 34
	cbne r9, $(0), F35 ; check 35
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F36 ; check 36
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F37 ; check 37
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr5, r4
pi5:
	rtt	$RTIMASK_ALL
pr5:
	cbne r10, $(1), F38 ; check 38
	lea	pi5, r11
	cbne r6, r11, F39 ; check 39
	cbne r8, $(VECTOR_PRIVILEGED), F40 ; check 40
	cbne r9, $(0), F41 ; check 41
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F42 ; check 42
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F43 ; check 43
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr6, r4
pi6:
	tlbi	r1
pr6:
	cbne r10, $(1), F44 ; check 44
	lea	pi6, r11
	cbne r6, r11, F45 ; check 45
	cbne r8, $(VECTOR_PRIVILEGED), F46 ; check 46
	cbne r9, $(0), F47 ; check 47
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F48 ; check 48
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F49 ; check 49
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr7, r4
pi7:
	tlbia
pr7:
	cbne r10, $(1), F50 ; check 50
	lea	pi7, r11
	cbne r6, r11, F51 ; check 51
	cbne r8, $(VECTOR_PRIVILEGED), F52 ; check 52
	cbne r9, $(0), F53 ; check 53
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F54 ; check 54
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F55 ; check 55
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr8, r4
pi8:
	tlbsync
pr8:
	cbne r10, $(1), F56 ; check 56
	lea	pi8, r11
	cbne r6, r11, F57 ; check 57
	cbne r8, $(VECTOR_PRIVILEGED), F58 ; check 58
	cbne r9, $(0), F59 ; check 59
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F60 ; check 60
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F61 ; check 61
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr9, r4
pi9:
	mtsr	asid, r1
pr9:
	cbne r10, $(1), F62 ; check 62
	lea	pi9, r11
	cbne r6, r11, F63 ; check 63
	cbne r8, $(VECTOR_PRIVILEGED), F64 ; check 64
	cbne r9, $(0), F65 ; check 65
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F66 ; check 66
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F67 ; check 67
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr10, r4
pi10:
	mfsr	r1, asid
pr10:
	cbne r10, $(1), F68 ; check 68
	lea	pi10, r11
	cbne r6, r11, F69 ; check 69
	cbne r8, $(VECTOR_PRIVILEGED), F70 ; check 70
	cbne r9, $(0), F71 ; check 71
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F72 ; check 72
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F73 ; check 73
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr12, r4
pi12:
	wfe
pr12:
	cbne r10, $(1), F80 ; check 80
	lea	pi12, r11
	cbne r6, r11, F81 ; check 81
	cbne r8, $(VECTOR_PRIVILEGED), F82 ; check 82
	cbne r9, $(0), F83 ; check 83
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F84 ; check 84
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F85 ; check 85
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr13, r4
pi13:
	pushx
pr13:
	cbne r10, $(1), F86 ; check 86
	lea	pi13, r11
	cbne r6, r11, F87 ; check 87
	cbne r8, $(VECTOR_PRIVILEGED), F88 ; check 88
	cbne r9, $(0), F89 ; check 89
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F90 ; check 90
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F91 ; check 91
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr14, r4
pi14:
	popx
pr14:
	cbne r10, $(1), F92 ; check 92
	lea	pi14, r11
	cbne r6, r11, F93 ; check 93
	cbne r8, $(VECTOR_PRIVILEGED), F94 ; check 94
	cbne r9, $(0), F95 ; check 95
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F96 ; check 96
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F97 ; check 97
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr15, r4
pi15:
	prober	r2, r1
pr15:
	cbne r10, $(1), F98 ; check 98
	lea	pi15, r11
	cbne r6, r11, F99 ; check 99
	cbne r8, $(VECTOR_PRIVILEGED), F100 ; check 100
	cbne r9, $(0), F101 ; check 101
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F102 ; check 102
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F103 ; check 103
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	mov	$0, r2
	mov	$0, r3
	mov	$0, r13
	lea	pr16, r4
pi16:
	probew	r2, r1
pr16:
	cbne r10, $(1), F104 ; check 104
	lea	pi16, r11
	cbne r6, r11, F105 ; check 105
	cbne r8, $(VECTOR_PRIVILEGED), F106 ; check 106
	cbne r9, $(0), F107 ; check 107
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F108 ; check 108
	cbne r12, $((MODE_KERNEL<<PSW_MODE|MODE_USER<<PSW_PREV|7<<PSW_PRI)), F109 ; check 109
	mfdp	r5
	cbne r5, $(8738), F110 ; check 110
	mfps	r5
	cbne r5, $(MODE_USER<<PSW_MODE), F111 ; check 111: the flag bits of the PSW read as zero
	mov	$0, r10
	mov	$0, r6
	mov	$0, r8
	mov	$0xFFF, r1
	lea	pr17, r4
pi17:
	mtps	r1
pr17:
	cbne r10, $(1), F112 ; check 112: mtps is privileged, in user mode it aborts
	lea	pi17, r11
	cbne r6, r11, F207 ; check 207
	cbne r8, $(VECTOR_PRIVILEGED), F208 ; check 208
	mfps	r5
	cbne r5, $(MODE_USER<<PSW_MODE), F209 ; check 209: nothing was written
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	nop
	fence
	sev
	icinva
	icinv	r1
	isync
	mov	$7, r1
	mtdp	r1
	mfdp	r5
	push	r1
	pop	r5
	cbne r10, $(0), F113 ; check 113
	cbne r5, $(7), F114 ; check 114
	mov	$0x2222, r1
	mtdp	r1
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$5
aft1:
	cbne r10, $(1), F115 ; check 115
	lea	aft1, r11
	cbne r6, r11, F116 ; check 116
	cbne r8, $(VECTOR_TRAP_BASE+5), F117 ; check 117
	cbne r7, $((MODE_USER<<PSW_MODE|MODE_KERNEL<<PSW_PREV)), F118 ; check 118
	cbne r9, $(0), F119 ; check 119
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	trap	$200
aft2:
	cbne r10, $(1), F120 ; check 120
	lea	aft2, r11
	cbne r6, r11, F121 ; check 121
	cbne r8, $(VECTOR_TRAP_BASE+200), F122 ; check 122
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	bpt
aft3:
	cbne r10, $(1), F123 ; check 123
	lea	aft3, r11
	cbne r6, r11, F124 ; check 124
	cbne r8, $(VECTOR_BPT), F125 ; check 125
	mfdp	r5
	cbne r5, $(8738), F126 ; check 126
	trap	$7
	lea	ustack_alt, r11
	cbne sp, r11, F127 ; check 127
	trap	$8
	mov	$99, r0
	trap	$1
F1:	mov	$1, r0
	trap	$1
F2:	mov	$2, r0
	trap	$1
F3:	mov	$3, r0
	trap	$1
F4:	mov	$4, r0
	trap	$1
F5:	mov	$5, r0
	trap	$1
F6:	mov	$6, r0
	trap	$1
F7:	mov	$7, r0
	trap	$1
F8:	mov	$8, r0
	trap	$1
F9:	mov	$9, r0
	trap	$1
F10:	mov	$10, r0
	trap	$1
F11:	mov	$11, r0
	trap	$1
F12:	mov	$12, r0
	trap	$1
F13:	mov	$13, r0
	trap	$1
F14:	mov	$14, r0
	trap	$1
F15:	mov	$15, r0
	trap	$1
F16:	mov	$16, r0
	trap	$1
F17:	mov	$17, r0
	trap	$1
F18:	mov	$18, r0
	trap	$1
F19:	mov	$19, r0
	trap	$1
F20:	mov	$20, r0
	trap	$1
F21:	mov	$21, r0
	trap	$1
F22:	mov	$22, r0
	trap	$1
F23:	mov	$23, r0
	trap	$1
F24:	mov	$24, r0
	trap	$1
F25:	mov	$25, r0
	trap	$1
F26:	mov	$26, r0
	trap	$1
F27:	mov	$27, r0
	trap	$1
F28:	mov	$28, r0
	trap	$1
F29:	mov	$29, r0
	trap	$1
F30:	mov	$30, r0
	trap	$1
F31:	mov	$31, r0
	trap	$1
F32:	mov	$32, r0
	trap	$1
F33:	mov	$33, r0
	trap	$1
F34:	mov	$34, r0
	trap	$1
F35:	mov	$35, r0
	trap	$1
F36:	mov	$36, r0
	trap	$1
F37:	mov	$37, r0
	trap	$1
F38:	mov	$38, r0
	trap	$1
F39:	mov	$39, r0
	trap	$1
F40:	mov	$40, r0
	trap	$1
F41:	mov	$41, r0
	trap	$1
F42:	mov	$42, r0
	trap	$1
F43:	mov	$43, r0
	trap	$1
F44:	mov	$44, r0
	trap	$1
F45:	mov	$45, r0
	trap	$1
F46:	mov	$46, r0
	trap	$1
F47:	mov	$47, r0
	trap	$1
F48:	mov	$48, r0
	trap	$1
F49:	mov	$49, r0
	trap	$1
F50:	mov	$50, r0
	trap	$1
F51:	mov	$51, r0
	trap	$1
F52:	mov	$52, r0
	trap	$1
F53:	mov	$53, r0
	trap	$1
F54:	mov	$54, r0
	trap	$1
F55:	mov	$55, r0
	trap	$1
F56:	mov	$56, r0
	trap	$1
F57:	mov	$57, r0
	trap	$1
F58:	mov	$58, r0
	trap	$1
F59:	mov	$59, r0
	trap	$1
F60:	mov	$60, r0
	trap	$1
F61:	mov	$61, r0
	trap	$1
F62:	mov	$62, r0
	trap	$1
F63:	mov	$63, r0
	trap	$1
F64:	mov	$64, r0
	trap	$1
F65:	mov	$65, r0
	trap	$1
F66:	mov	$66, r0
	trap	$1
F67:	mov	$67, r0
	trap	$1
F68:	mov	$68, r0
	trap	$1
F69:	mov	$69, r0
	trap	$1
F70:	mov	$70, r0
	trap	$1
F71:	mov	$71, r0
	trap	$1
F72:	mov	$72, r0
	trap	$1
F73:	mov	$73, r0
	trap	$1
F80:	mov	$80, r0
	trap	$1
F81:	mov	$81, r0
	trap	$1
F82:	mov	$82, r0
	trap	$1
F83:	mov	$83, r0
	trap	$1
F84:	mov	$84, r0
	trap	$1
F85:	mov	$85, r0
	trap	$1
F86:	mov	$86, r0
	trap	$1
F87:	mov	$87, r0
	trap	$1
F88:	mov	$88, r0
	trap	$1
F89:	mov	$89, r0
	trap	$1
F90:	mov	$90, r0
	trap	$1
F91:	mov	$91, r0
	trap	$1
F92:	mov	$92, r0
	trap	$1
F93:	mov	$93, r0
	trap	$1
F94:	mov	$94, r0
	trap	$1
F95:	mov	$95, r0
	trap	$1
F96:	mov	$96, r0
	trap	$1
F97:	mov	$97, r0
	trap	$1
F98:	mov	$98, r0
	trap	$1
F99:	mov	$99, r0
	trap	$1
F100:	mov	$100, r0
	trap	$1
F101:	mov	$101, r0
	trap	$1
F102:	mov	$102, r0
	trap	$1
F103:	mov	$103, r0
	trap	$1
F104:	mov	$104, r0
	trap	$1
F105:	mov	$105, r0
	trap	$1
F106:	mov	$106, r0
	trap	$1
F107:	mov	$107, r0
	trap	$1
F108:	mov	$108, r0
	trap	$1
F109:	mov	$109, r0
	trap	$1
F110:	mov	$110, r0
	trap	$1
F111:	mov	$111, r0
	trap	$1
F112:	mov	$112, r0
	trap	$1
F113:	mov	$113, r0
	trap	$1
F114:	mov	$114, r0
	trap	$1
F115:	mov	$115, r0
	trap	$1
F116:	mov	$116, r0
	trap	$1
F117:	mov	$117, r0
	trap	$1
F118:	mov	$118, r0
	trap	$1
F119:	mov	$119, r0
	trap	$1
F120:	mov	$120, r0
	trap	$1
F121:	mov	$121, r0
	trap	$1
F122:	mov	$122, r0
	trap	$1
F123:	mov	$123, r0
	trap	$1
F124:	mov	$124, r0
	trap	$1
F125:	mov	$125, r0
	trap	$1
F126:	mov	$126, r0
	trap	$1
F127:	mov	$127, r0
	trap	$1
sup:
	mfps	r1
	cbne r1, $(MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV), F201 ; check 201
	lea	sstack_top, r11
	cbne sp, r11, F202 ; check 202
	mov	$0, r4
	mov	$0, r10
	mov	$0, r6
	mov	$0, r7
	mov	$0, r8
	mov	$0, r9
	mov	$0, r12
	lea	sr1, r4
sp1:
	mfsr	r1, ptbr
sr1:
	cbne r10, $(1), F203 ; check 203
	lea	sp1, r11
	cbne r6, r11, F204 ; check 204
	cbne r8, $(VECTOR_PRIVILEGED), F205 ; check 205
	cbne r7, $((MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV)), F206 ; check 206
	mov	$0, r0
	trap	$0
F201:	mov	$201, r0
	trap	$1
F202:	mov	$202, r0
	trap	$1
F203:	mov	$203, r0
	trap	$1
F204:	mov	$204, r0
	trap	$1
F205:	mov	$205, r0
	trap	$1
F206:	mov	$206, r0
	trap	$1
F207:	mov	$207, r0
	trap	$1
F208:	mov	$208, r0
	trap	$1
F209:	mov	$209, r0
	trap	$1
h_gen:	mfps	r12
	mfsr	r6, epc
	mfsr	r7, epsw
	mfsr	r8, ecause
	mfsr	r9, eva
	mfsr	r3, usp
	mfdp	r2
	mov	sp, r13
	add	$1, r10
	cbeq	r4, $0, 1f
	mtsr	epc, r4
1:	rti	$RTIMASK_ALL
h_ok:	mov	$0, r0
h_fail:	halt
h_k7:	lea	ustack_alt, r1
	mtsr	usp, r1
	rti	$RTIMASK_ALL
h_k8:	lea	sstack_top, r1
	mtsr	ssp, r1
	lea	sup, r1
	mtsr	epc, r1
	mov	$(MODE_SUPERVISOR<<PSW_MODE|MODE_USER<<PSW_PREV), r1
	mtsr	epsw, r1
	rti	$RTIMASK_ALL
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
