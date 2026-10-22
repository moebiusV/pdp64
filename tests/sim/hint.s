; hint #n (SYSX sub 3, page-2 0x2D): not privileged, no flags, no register or memory effect, whatever n is: all 256 codes in the two-byte form the assembler picks, and the
; four-byte form written out, with the flags set and registers loaded.  (Defined codes: 0 nop, 1 pause, 2 speculation barrier; the others are reserved no-ops.)  Exit n on failure.
	.text
	.globl	_start
_start:
	movq	#11, r1
	movq	#22, r2
	movq	#-3, r3
	movq	#15, r6
	mtps	r6
	mfps	r10
	movq	sp, r13
	movq	#7, r0
	hint	#0
	hint	#1
	hint	#2
	hint	#3
	hint	#4
	hint	#5
	hint	#6
	hint	#7
	hint	#8
	hint	#9
	hint	#10
	hint	#11
	hint	#12
	hint	#13
	hint	#14
	hint	#15
	mfps	r9
	cmp	r9, r10
	bne	f1
	cmp	r1, #11
	bne	f1
	cmp	r2, #22
	bne	f1
	cmp	r3, #-3
	bne	f1
	cmp	sp, r13
	bne	f1
	movq	#15, r6
	mtps	r6
	hint	#16
	hint	#17
	hint	#18
	hint	#19
	hint	#20
	hint	#21
	hint	#22
	hint	#23
	hint	#24
	hint	#25
	hint	#26
	hint	#27
	hint	#28
	hint	#29
	hint	#30
	hint	#31
	mfps	r9
	cmp	r9, r10
	bne	f2
	cmp	r1, #11
	bne	f2
	cmp	r2, #22
	bne	f2
	cmp	r3, #-3
	bne	f2
	cmp	sp, r13
	bne	f2
	movq	#15, r6
	mtps	r6
	hint	#32
	hint	#33
	hint	#34
	hint	#35
	hint	#36
	hint	#37
	hint	#38
	hint	#39
	hint	#40
	hint	#41
	hint	#42
	hint	#43
	hint	#44
	hint	#45
	hint	#46
	hint	#47
	mfps	r9
	cmp	r9, r10
	bne	f3
	cmp	r1, #11
	bne	f3
	cmp	r2, #22
	bne	f3
	cmp	r3, #-3
	bne	f3
	cmp	sp, r13
	bne	f3
	movq	#15, r6
	mtps	r6
	hint	#48
	hint	#49
	hint	#50
	hint	#51
	hint	#52
	hint	#53
	hint	#54
	hint	#55
	hint	#56
	hint	#57
	hint	#58
	hint	#59
	hint	#60
	hint	#61
	hint	#62
	hint	#63
	mfps	r9
	cmp	r9, r10
	bne	f4
	cmp	r1, #11
	bne	f4
	cmp	r2, #22
	bne	f4
	cmp	r3, #-3
	bne	f4
	cmp	sp, r13
	bne	f4
	movq	#15, r6
	mtps	r6
	hint	#64
	hint	#65
	hint	#66
	hint	#67
	hint	#68
	hint	#69
	hint	#70
	hint	#71
	hint	#72
	hint	#73
	hint	#74
	hint	#75
	hint	#76
	hint	#77
	hint	#78
	hint	#79
	mfps	r9
	cmp	r9, r10
	bne	f5
	cmp	r1, #11
	bne	f5
	cmp	r2, #22
	bne	f5
	cmp	r3, #-3
	bne	f5
	cmp	sp, r13
	bne	f5
	movq	#15, r6
	mtps	r6
	hint	#80
	hint	#81
	hint	#82
	hint	#83
	hint	#84
	hint	#85
	hint	#86
	hint	#87
	hint	#88
	hint	#89
	hint	#90
	hint	#91
	hint	#92
	hint	#93
	hint	#94
	hint	#95
	mfps	r9
	cmp	r9, r10
	bne	f6
	cmp	r1, #11
	bne	f6
	cmp	r2, #22
	bne	f6
	cmp	r3, #-3
	bne	f6
	cmp	sp, r13
	bne	f6
	movq	#15, r6
	mtps	r6
	hint	#96
	hint	#97
	hint	#98
	hint	#99
	hint	#100
	hint	#101
	hint	#102
	hint	#103
	hint	#104
	hint	#105
	hint	#106
	hint	#107
	hint	#108
	hint	#109
	hint	#110
	hint	#111
	mfps	r9
	cmp	r9, r10
	bne	f7
	cmp	r1, #11
	bne	f7
	cmp	r2, #22
	bne	f7
	cmp	r3, #-3
	bne	f7
	cmp	sp, r13
	bne	f7
	movq	#15, r6
	mtps	r6
	hint	#112
	hint	#113
	hint	#114
	hint	#115
	hint	#116
	hint	#117
	hint	#118
	hint	#119
	hint	#120
	hint	#121
	hint	#122
	hint	#123
	hint	#124
	hint	#125
	hint	#126
	hint	#127
	mfps	r9
	cmp	r9, r10
	bne	f8
	cmp	r1, #11
	bne	f8
	cmp	r2, #22
	bne	f8
	cmp	r3, #-3
	bne	f8
	cmp	sp, r13
	bne	f8
	movq	#15, r6
	mtps	r6
	hint	#128
	hint	#129
	hint	#130
	hint	#131
	hint	#132
	hint	#133
	hint	#134
	hint	#135
	hint	#136
	hint	#137
	hint	#138
	hint	#139
	hint	#140
	hint	#141
	hint	#142
	hint	#143
	mfps	r9
	cmp	r9, r10
	bne	f9
	cmp	r1, #11
	bne	f9
	cmp	r2, #22
	bne	f9
	cmp	r3, #-3
	bne	f9
	cmp	sp, r13
	bne	f9
	movq	#15, r6
	mtps	r6
	hint	#144
	hint	#145
	hint	#146
	hint	#147
	hint	#148
	hint	#149
	hint	#150
	hint	#151
	hint	#152
	hint	#153
	hint	#154
	hint	#155
	hint	#156
	hint	#157
	hint	#158
	hint	#159
	mfps	r9
	cmp	r9, r10
	bne	f10
	cmp	r1, #11
	bne	f10
	cmp	r2, #22
	bne	f10
	cmp	r3, #-3
	bne	f10
	cmp	sp, r13
	bne	f10
	movq	#15, r6
	mtps	r6
	hint	#160
	hint	#161
	hint	#162
	hint	#163
	hint	#164
	hint	#165
	hint	#166
	hint	#167
	hint	#168
	hint	#169
	hint	#170
	hint	#171
	hint	#172
	hint	#173
	hint	#174
	hint	#175
	mfps	r9
	cmp	r9, r10
	bne	f11
	cmp	r1, #11
	bne	f11
	cmp	r2, #22
	bne	f11
	cmp	r3, #-3
	bne	f11
	cmp	sp, r13
	bne	f11
	movq	#15, r6
	mtps	r6
	hint	#176
	hint	#177
	hint	#178
	hint	#179
	hint	#180
	hint	#181
	hint	#182
	hint	#183
	hint	#184
	hint	#185
	hint	#186
	hint	#187
	hint	#188
	hint	#189
	hint	#190
	hint	#191
	mfps	r9
	cmp	r9, r10
	bne	f12
	cmp	r1, #11
	bne	f12
	cmp	r2, #22
	bne	f12
	cmp	r3, #-3
	bne	f12
	cmp	sp, r13
	bne	f12
	movq	#15, r6
	mtps	r6
	hint	#192
	hint	#193
	hint	#194
	hint	#195
	hint	#196
	hint	#197
	hint	#198
	hint	#199
	hint	#200
	hint	#201
	hint	#202
	hint	#203
	hint	#204
	hint	#205
	hint	#206
	hint	#207
	mfps	r9
	cmp	r9, r10
	bne	f13
	cmp	r1, #11
	bne	f13
	cmp	r2, #22
	bne	f13
	cmp	r3, #-3
	bne	f13
	cmp	sp, r13
	bne	f13
	movq	#15, r6
	mtps	r6
	hint	#208
	hint	#209
	hint	#210
	hint	#211
	hint	#212
	hint	#213
	hint	#214
	hint	#215
	hint	#216
	hint	#217
	hint	#218
	hint	#219
	hint	#220
	hint	#221
	hint	#222
	hint	#223
	mfps	r9
	cmp	r9, r10
	bne	f14
	cmp	r1, #11
	bne	f14
	cmp	r2, #22
	bne	f14
	cmp	r3, #-3
	bne	f14
	cmp	sp, r13
	bne	f14
	movq	#15, r6
	mtps	r6
	hint	#224
	hint	#225
	hint	#226
	hint	#227
	hint	#228
	hint	#229
	hint	#230
	hint	#231
	hint	#232
	hint	#233
	hint	#234
	hint	#235
	hint	#236
	hint	#237
	hint	#238
	hint	#239
	mfps	r9
	cmp	r9, r10
	bne	f15
	cmp	r1, #11
	bne	f15
	cmp	r2, #22
	bne	f15
	cmp	r3, #-3
	bne	f15
	cmp	sp, r13
	bne	f15
	movq	#15, r6
	mtps	r6
	hint	#240
	hint	#241
	hint	#242
	hint	#243
	hint	#244
	hint	#245
	hint	#246
	hint	#247
	hint	#248
	hint	#249
	hint	#250
	hint	#251
	hint	#252
	hint	#253
	hint	#254
	hint	#255
	mfps	r9
	cmp	r9, r10
	bne	f16
	cmp	r1, #11
	bne	f16
	cmp	r2, #22
	bne	f16
	cmp	r3, #-3
	bne	f16
	cmp	sp, r13
	bne	f16
	movq	#15, r6
	mtps	r6
	.word	0x540f, 0x0300	; hint #0, four bytes
	.word	0x540f, 0x0301	; hint #1, four bytes
	.word	0x540f, 0x0302	; hint #2, four bytes
	.word	0x540f, 0x0303	; hint #3, four bytes
	.word	0x540f, 0x03c8	; hint #200, four bytes
	.word	0x540f, 0x03ff	; hint #255, four bytes
	mfps	r9
	cmp	r9, r10
	bne	f17
	cmp	r1, #11
	bne	f17
	cmp	r2, #22
	bne	f17
	cmp	r3, #-3
	bne	f17
	cmp	sp, r13
	bne	f17
	movq	#15, r6
	mtps	r6
	movq	#0, r0
	trap	#0
f1:	movq	#1, r0
	trap	#0
f2:	movq	#2, r0
	trap	#0
f3:	movq	#3, r0
	trap	#0
f4:	movq	#4, r0
	trap	#0
f5:	movq	#5, r0
	trap	#0
f6:	movq	#6, r0
	trap	#0
f7:	movq	#7, r0
	trap	#0
f8:	movq	#8, r0
	trap	#0
f9:	movq	#9, r0
	trap	#0
f10:	movq	#10, r0
	trap	#0
f11:	movq	#11, r0
	trap	#0
f12:	movq	#12, r0
	trap	#0
f13:	movq	#13, r0
	trap	#0
f14:	movq	#14, r0
	trap	#0
f15:	movq	#15, r0
	trap	#0
f16:	movq	#16, r0
	trap	#0
f17:	movq	#17, r0
	trap	#0
