	.text
	.globl	d3                              ; -- Begin function d3
	.align	2
d3:                                     ; @d3
; %bb.0:
	movl r0, r0
	mul #1431655766, r0
	movq r0, r1
	shr #63, r1
	shr #32, r0
	add r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	d5                              ; -- Begin function d5
	.align	2
d5:                                     ; @d5
; %bb.0:
	movl r0, r0
	mul #1717986919, r0
	movq r0, r1
	shr #63, r1
	sar #33, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	d7                              ; -- Begin function d7
	.align	2
d7:                                     ; @d7
; %bb.0:
	movl r0, r1
	mul #-1840700269, r1
	shr #32, r1
	add r0, r1
	movq =2147483648, r2
	and r1, r2
	shr #31, r2
	movl r1, r0
	sar #2, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	d10                             ; -- Begin function d10
	.align	2
d10:                                    ; @d10
; %bb.0:
	movl r0, r0
	mul #1717986919, r0
	movq r0, r1
	shr #63, r1
	sar #34, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	d100                            ; -- Begin function d100
	.align	2
d100:                                   ; @d100
; %bb.0:
	movl r0, r0
	mul #1374389535, r0
	movq r0, r1
	shr #63, r1
	sar #37, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	d1000                           ; -- Begin function d1000
	.align	2
d1000:                                  ; @d1000
; %bb.0:
	movl r0, r0
	mul #274877907, r0
	movq r0, r1
	shr #63, r1
	sar #38, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	d12345                          ; -- Begin function d12345
	.align	2
d12345:                                 ; @d12345
; %bb.0:
	movl r0, r1
	mul #-1444876401, r1
	shr #32, r1
	add r0, r1
	movq =2147483648, r2
	and r1, r2
	shr #31, r2
	movl r1, r0
	sar #13, r0
	add r2, r0
	ret
                                        ; -- End function
	.globl	dbig                            ; -- Begin function dbig
	.align	2
dbig:                                   ; @dbig
; %bb.0:
	movl r0, r0
	mul #1073741825, r0
	movq r0, r1
	shr #63, r1
	sar #61, r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	d641                            ; -- Begin function d641
	.align	2
d641:                                   ; @d641
; %bb.0:
	movl r0, r0
	mul #6700417, r0
	movq r0, r1
	shr #63, r1
	shr #32, r0
	add r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	m3                              ; -- Begin function m3
	.align	2
m3:                                     ; @m3
; %bb.0:
	movl r0, r1
	mul #1431655766, r1
	movq r1, r2
	shr #63, r2
	shr #32, r1
	add r2, r1
	mul #3, r1
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	m10                             ; -- Begin function m10
	.align	2
m10:                                    ; @m10
; %bb.0:
	movl r0, r1
	mul #1717986919, r1
	movq r1, r2
	shr #63, r2
	sar #34, r1
	add r2, r1
	mul #10, r1
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	m60                             ; -- Begin function m60
	.align	2
m60:                                    ; @m60
; %bb.0:
	movl r0, r1
	mul #-2004318071, r1
	shr #32, r1
	add r0, r1
	movq =2147483648, r2
	and r1, r2
	shr #31, r2
	movl r1, r1
	shr #5, r1
	add r2, r1
	mul #60, r1
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	m65521                          ; -- Begin function m65521
	.align	2
m65521:                                 ; @m65521
; %bb.0:
	movl r0, r1
	mul #-2146992015, r1
	shr #32, r1
	add r0, r1
	movq =2147483648, r2
	and r1, r2
	shr #31, r2
	movl r1, r1
	shr #15, r1
	add r2, r1
	mul #65521, r1
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	mbig                            ; -- Begin function mbig
	.align	2
mbig:                                   ; @mbig
; %bb.0:
	movl r0, r1
	mul #1152921497, r1
	movq r1, r2
	shr #63, r2
	sar #60, r1
	add r2, r1
	mul #1000000007, r1
	sub r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	dm10                            ; -- Begin function dm10
	.align	2
dm10:                                   ; @dm10
; %bb.0:
	movl r0, r1
	mul #1717986919, r1
	movq r1, r2
	shr #63, r2
	sar #34, r1
	add r2, r1
	mul #100, r0
	mul #-999, r1
	add r0, r1
	movl r1, r0
	ret
                                        ; -- End function
	.globl	e1                              ; -- Begin function e1
	.align	2
e1:                                     ; @e1
; %bb.0:
	movq r1, r2
	mul r0, r2
	lea 7(r2), r2
	movl r2, r2
	mul #1717986919, r2
	movq r2, r3
	shr #63, r3
	sar #34, r2
	add r3, r2
	sub r1, r0
	movl r0, r1
	mul #715827883, r1
	movq r1, r3
	shr #63, r3
	sar #33, r1
	add r3, r1
	mul #12, r1
	sub r1, r0
	add r2, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	e2                              ; -- Begin function e2
	.align	2
e2:                                     ; @e2
; %bb.0:
	lea 1(r0), r1
	movl r1, r1
	mul #1431655766, r1
	movq r1, r2
	shr #63, r2
	shr #32, r1
	add r2, r1
	mul #5, r0
	movl r0, r2
	mul #-1840700269, r2
	shr #32, r2
	add r0, r2
	movq =2147483648, r3
	and r2, r3
	shr #31, r3
	movl r2, r2
	shr #2, r2
	add r3, r2
	mul #7, r2
	sub r0, r2
	add r1, r2
	movl r2, r0
	ret
                                        ; -- End function
	.globl	ref                             ; -- Begin function ref
	.align	2
ref:                                    ; @ref
; %bb.0:
	movl r0, r3
	movq r3, r4
	sar #63, r4
	movq r3, r0
	xor r4, r0
	sub r4, r0
	movl r1, r1
	clr r4
.LBB17_1:                               ; =>This Inner Loop Header: Depth=1
	movq r1, r5
	shl #1, r1
	lea 1(r4), r4
	cble r1, r0, .LBB17_1
; %bb.2:                                ; %.preheader
	clr r1
	br .LBB17_3
.LBB17_7:                               ;   in Loop: Header=BB17_3 Depth=1
	sub r6, r0
	add r7, r1
	movq r5, r6
	shr #63, r6
	add r5, r6
	sar #1, r6
	movq r6, r5
	cble r4, #0, .LBB17_8
.LBB17_3:                               ; =>This Inner Loop Header: Depth=1
	clr r6
	cblt r0, r5, .LBB17_5
; %bb.4:                                ;   in Loop: Header=BB17_3 Depth=1
	movq r5, r6
.LBB17_5:                               ;   in Loop: Header=BB17_3 Depth=1
	lea -1(r4), r4
	clr r7
	cblt r0, r5, .LBB17_7
; %bb.6:                                ;   in Loop: Header=BB17_3 Depth=1
	movq #1, r7
	shl r4, r7
	br .LBB17_7
.LBB17_8:
	cblt r3, #0, .LBB17_9
; %bb.10:
	cblt r3, #0, .LBB17_11
.LBB17_12:
	movzl r2, r2
	cbne r2, #0, .LBB17_13
.LBB17_14:
	movl r1, r0
	ret
.LBB17_9:
	neg r0
	cbge r3, #0, .LBB17_12
.LBB17_11:
	neg r1
	movzl r2, r2
	cbeq r2, #0, .LBB17_14
.LBB17_13:
	movq r0, r1
	movl r1, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #8, sp
	movq r8, -8(r13)                        ; 8-byte Folded Spill
	clr r1
	lea test.v, r2
	movq =2147483648, r3
	movq #2147483646, r4
	clr r0
	br .LBB18_1
.LBB18_162:                             ;   in Loop: Header=BB18_1 Depth=1
	lea 1(r1), r1
	cbeq r1, #38, .LBB18_163
.LBB18_1:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB18_2 Depth 2
                                        ;     Child Loop BB18_4 Depth 2
                                        ;     Child Loop BB18_13 Depth 2
                                        ;     Child Loop BB18_15 Depth 2
                                        ;     Child Loop BB18_24 Depth 2
                                        ;     Child Loop BB18_26 Depth 2
                                        ;     Child Loop BB18_35 Depth 2
                                        ;     Child Loop BB18_37 Depth 2
                                        ;     Child Loop BB18_46 Depth 2
                                        ;     Child Loop BB18_48 Depth 2
                                        ;     Child Loop BB18_58 Depth 2
                                        ;     Child Loop BB18_60 Depth 2
                                        ;     Child Loop BB18_69 Depth 2
                                        ;     Child Loop BB18_71 Depth 2
                                        ;     Child Loop BB18_85 Depth 2
                                        ;     Child Loop BB18_87 Depth 2
                                        ;     Child Loop BB18_97 Depth 2
                                        ;     Child Loop BB18_99 Depth 2
                                        ;     Child Loop BB18_106 Depth 2
                                        ;     Child Loop BB18_108 Depth 2
                                        ;     Child Loop BB18_115 Depth 2
                                        ;     Child Loop BB18_117 Depth 2
                                        ;     Child Loop BB18_124 Depth 2
                                        ;     Child Loop BB18_126 Depth 2
                                        ;     Child Loop BB18_133 Depth 2
                                        ;     Child Loop BB18_135 Depth 2
                                        ;     Child Loop BB18_143 Depth 2
                                        ;     Child Loop BB18_145 Depth 2
                                        ;     Child Loop BB18_153 Depth 2
                                        ;     Child Loop BB18_155 Depth 2
	movl 0(r2)(r1*4), r6
	movq r6, r7
	sar #63, r7
	movq r6, r5
	xor r7, r5
	sub r7, r5
	movq #3, r16
	movq #1, r18
.LBB18_2:                               ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r16, r17
	movq r18, r7
	shl #1, r16
	lea 1(r7), r18
	cble r16, r5, .LBB18_2
; %bb.3:                                ; %.preheader33
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r16
	movq r5, r18
	br .LBB18_4
.LBB18_8:                               ;   in Loop: Header=BB18_4 Depth=2
	sub r19, r18
	add r20, r16
	movq r17, r19
	shr #63, r19
	add r17, r19
	sar #1, r19
	movq r19, r17
	cble r7, #0, .LBB18_9
.LBB18_4:                               ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r19
	cblt r18, r17, .LBB18_6
; %bb.5:                                ;   in Loop: Header=BB18_4 Depth=2
	movq r17, r19
.LBB18_6:                               ;   in Loop: Header=BB18_4 Depth=2
	lea -1(r7), r7
	clr r20
	cblt r18, r17, .LBB18_8
; %bb.7:                                ;   in Loop: Header=BB18_4 Depth=2
	movq #1, r20
	shl r7, r20
	br .LBB18_8
.LBB18_9:                               ;   in Loop: Header=BB18_1 Depth=1
	movq =144955203620, r7
	shr r1, r7
	and #1, r7
	cbeq r7, #0, .LBB18_11
; %bb.10:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r16
.LBB18_11:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r17
	mul #1431655766, r17
	movq r17, r18
	shr #63, r18
	shr #32, r17
	add r18, r17
	movzl r17, r18
	movzl r16, r19
	movq r6, r16
	mul #1717986919, r16
	cbne r18, r19, .LBB18_56
; %bb.12:                               ; %.preheader32
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #5, r19
	movq #1, r21
.LBB18_13:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r19, r20
	movq r21, r18
	shl #1, r19
	lea 1(r18), r21
	cble r19, r5, .LBB18_13
; %bb.14:                               ; %.preheader31
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r19
	movq r5, r21
	br .LBB18_15
.LBB18_19:                              ;   in Loop: Header=BB18_15 Depth=2
	sub r22, r21
	add r23, r19
	movq r20, r22
	shr #63, r22
	add r20, r22
	sar #1, r22
	movq r22, r20
	cble r18, #0, .LBB18_20
.LBB18_15:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r22
	cblt r21, r20, .LBB18_17
; %bb.16:                               ;   in Loop: Header=BB18_15 Depth=2
	movq r20, r22
.LBB18_17:                              ;   in Loop: Header=BB18_15 Depth=2
	lea -1(r18), r18
	clr r23
	cblt r21, r20, .LBB18_19
; %bb.18:                               ;   in Loop: Header=BB18_15 Depth=2
	movq #1, r23
	shl r18, r23
	br .LBB18_19
.LBB18_20:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_22
; %bb.21:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r19
.LBB18_22:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r16, r18
	shr #63, r18
	movq r16, r20
	sar #33, r20
	add r18, r20
	movzl r20, r20
	movzl r19, r19
	cbne r20, r19, .LBB18_56
; %bb.23:                               ; %.preheader30
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #7, r19
	movq #1, r22
.LBB18_24:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r19, r21
	movq r22, r20
	shl #1, r19
	lea 1(r20), r22
	cble r19, r5, .LBB18_24
; %bb.25:                               ; %.preheader29
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r19
	movq r5, r22
	br .LBB18_26
.LBB18_30:                              ;   in Loop: Header=BB18_26 Depth=2
	sub r23, r22
	add r8, r19
	movq r21, r23
	shr #63, r23
	add r21, r23
	sar #1, r23
	movq r23, r21
	cble r20, #0, .LBB18_31
.LBB18_26:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r23
	cblt r22, r21, .LBB18_28
; %bb.27:                               ;   in Loop: Header=BB18_26 Depth=2
	movq r21, r23
.LBB18_28:                              ;   in Loop: Header=BB18_26 Depth=2
	lea -1(r20), r20
	clr r8
	cblt r22, r21, .LBB18_30
; %bb.29:                               ;   in Loop: Header=BB18_26 Depth=2
	movq #1, r8
	shl r20, r8
	br .LBB18_30
.LBB18_31:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_33
; %bb.32:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r19
.LBB18_33:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r20
	mul #-1840700269, r20
	shr #32, r20
	add r6, r20
	movl r20, r21
	and r3, r20
	shr #31, r20
	shr #2, r21
	add r20, r21
	movzl r21, r20
	movzl r19, r19
	cbne r20, r19, .LBB18_56
; %bb.34:                               ; %.preheader28
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #10, r19
	movq #1, r22
.LBB18_35:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r19, r21
	movq r22, r20
	shl #1, r19
	lea 1(r20), r22
	cble r19, r5, .LBB18_35
; %bb.36:                               ; %.preheader27
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r19
	movq r5, r22
	br .LBB18_37
.LBB18_41:                              ;   in Loop: Header=BB18_37 Depth=2
	sub r23, r22
	add r8, r19
	movq r21, r23
	shr #63, r23
	add r21, r23
	sar #1, r23
	movq r23, r21
	cble r20, #0, .LBB18_42
.LBB18_37:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r23
	cblt r22, r21, .LBB18_39
; %bb.38:                               ;   in Loop: Header=BB18_37 Depth=2
	movq r21, r23
.LBB18_39:                              ;   in Loop: Header=BB18_37 Depth=2
	lea -1(r20), r20
	clr r8
	cblt r22, r21, .LBB18_41
; %bb.40:                               ;   in Loop: Header=BB18_37 Depth=2
	movq #1, r8
	shl r20, r8
	br .LBB18_41
.LBB18_42:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_44
; %bb.43:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r19
.LBB18_44:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r16, r20
	sar #34, r20
	add r18, r20
	movzl r20, r18
	movzl r19, r19
	cbne r18, r19, .LBB18_56
; %bb.45:                               ; %.preheader26
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #100, r18
	movq #1, r21
.LBB18_46:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r18, r20
	movq r21, r19
	shl #1, r18
	lea 1(r19), r21
	cble r18, r5, .LBB18_46
; %bb.47:                               ; %.preheader25
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r18
	movq r5, r21
	br .LBB18_48
.LBB18_52:                              ;   in Loop: Header=BB18_48 Depth=2
	sub r22, r21
	add r23, r18
	movq r20, r22
	shr #63, r22
	add r20, r22
	sar #1, r22
	movq r22, r20
	cble r19, #0, .LBB18_53
.LBB18_48:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r22
	cblt r21, r20, .LBB18_50
; %bb.49:                               ;   in Loop: Header=BB18_48 Depth=2
	movq r20, r22
.LBB18_50:                              ;   in Loop: Header=BB18_48 Depth=2
	lea -1(r19), r19
	clr r23
	cblt r21, r20, .LBB18_52
; %bb.51:                               ;   in Loop: Header=BB18_48 Depth=2
	movq #1, r23
	shl r19, r23
	br .LBB18_52
.LBB18_53:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_55
; %bb.54:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r18
.LBB18_55:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r19
	mul #1374389535, r19
	movq r19, r20
	shr #63, r20
	sar #37, r19
	add r20, r19
	movzl r19, r19
	movzl r18, r18
	cbeq r19, r18, .LBB18_57
.LBB18_56:                              ;   in Loop: Header=BB18_1 Depth=1
	bis #1, r0
.LBB18_57:                              ;   in Loop: Header=BB18_1 Depth=1
	mul #3, r17
	movq r6, r18
	sub r17, r18
	movq #1000, r17
	movq #1, r21
.LBB18_58:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r20
	movq r21, r19
	shl #1, r17
	lea 1(r19), r21
	cble r17, r5, .LBB18_58
; %bb.59:                               ; %.preheader24
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r17
	movq r5, r21
	br .LBB18_60
.LBB18_64:                              ;   in Loop: Header=BB18_60 Depth=2
	sub r22, r21
	add r23, r17
	movq r20, r22
	shr #63, r22
	add r20, r22
	sar #1, r22
	movq r22, r20
	cble r19, #0, .LBB18_65
.LBB18_60:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r22
	cblt r21, r20, .LBB18_62
; %bb.61:                               ;   in Loop: Header=BB18_60 Depth=2
	movq r20, r22
.LBB18_62:                              ;   in Loop: Header=BB18_60 Depth=2
	lea -1(r19), r19
	clr r23
	cblt r21, r20, .LBB18_64
; %bb.63:                               ;   in Loop: Header=BB18_60 Depth=2
	movq #1, r23
	shl r19, r23
	br .LBB18_64
.LBB18_65:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_67
; %bb.66:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_67:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r19
	mul #274877907, r19
	movq r19, r20
	shr #63, r20
	sar #38, r19
	add r20, r19
	movzl r19, r19
	movzl r17, r17
	cbne r19, r17, .LBB18_95
; %bb.68:                               ; %.preheader23
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #12345, r17
	movq #1, r21
.LBB18_69:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r20
	movq r21, r19
	shl #1, r17
	lea 1(r19), r21
	cble r17, r5, .LBB18_69
; %bb.70:                               ; %.preheader22
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r17
	movq r5, r21
	br .LBB18_71
.LBB18_75:                              ;   in Loop: Header=BB18_71 Depth=2
	sub r22, r21
	add r23, r17
	movq r20, r22
	shr #63, r22
	add r20, r22
	sar #1, r22
	movq r22, r20
	cble r19, #0, .LBB18_76
.LBB18_71:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r22
	cblt r21, r20, .LBB18_73
; %bb.72:                               ;   in Loop: Header=BB18_71 Depth=2
	movq r20, r22
.LBB18_73:                              ;   in Loop: Header=BB18_71 Depth=2
	lea -1(r19), r19
	clr r23
	cblt r21, r20, .LBB18_75
; %bb.74:                               ;   in Loop: Header=BB18_71 Depth=2
	movq #1, r23
	shl r19, r23
	br .LBB18_75
.LBB18_76:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_78
; %bb.77:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_78:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r19
	mul #-1444876401, r19
	shr #32, r19
	add r6, r19
	movl r19, r20
	and r3, r19
	shr #31, r19
	shr #13, r20
	add r19, r20
	movzl r20, r19
	movzl r17, r17
	cbne r19, r17, .LBB18_95
; %bb.79:                               ;   in Loop: Header=BB18_1 Depth=1
	movzl r5, r19
	movq #1, r17
	cbhi r19, r4, .LBB18_81
; %bb.80:                               ;   in Loop: Header=BB18_1 Depth=1
	clr r17
.LBB18_81:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_83
; %bb.82:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_83:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r19
	mul #1073741825, r19
	movq r19, r20
	shr #63, r20
	sar #61, r19
	add r20, r19
	cbne r19, r17, .LBB18_95
; %bb.84:                               ; %.preheader21
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #641, r17
	movq #1, r21
.LBB18_85:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r20
	movq r21, r19
	shl #1, r17
	lea 1(r19), r21
	cble r17, r5, .LBB18_85
; %bb.86:                               ; %.preheader20
                                        ;   in Loop: Header=BB18_1 Depth=1
	clr r17
	movq r5, r21
	br .LBB18_87
.LBB18_91:                              ;   in Loop: Header=BB18_87 Depth=2
	sub r22, r21
	add r23, r17
	movq r20, r22
	shr #63, r22
	add r20, r22
	sar #1, r22
	movq r22, r20
	cble r19, #0, .LBB18_92
.LBB18_87:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r22
	cblt r21, r20, .LBB18_89
; %bb.88:                               ;   in Loop: Header=BB18_87 Depth=2
	movq r20, r22
.LBB18_89:                              ;   in Loop: Header=BB18_87 Depth=2
	lea -1(r19), r19
	clr r23
	cblt r21, r20, .LBB18_91
; %bb.90:                               ;   in Loop: Header=BB18_87 Depth=2
	movq #1, r23
	shl r19, r23
	br .LBB18_91
.LBB18_92:                              ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_94
; %bb.93:                               ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_94:                              ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r19
	mul #6700417, r19
	movq r19, r20
	shr #63, r20
	shr #32, r19
	add r20, r19
	movzl r19, r19
	movzl r17, r17
	cbeq r19, r17, .LBB18_96
.LBB18_95:                              ;   in Loop: Header=BB18_1 Depth=1
	bis #2, r0
.LBB18_96:                              ;   in Loop: Header=BB18_1 Depth=1
	movq #3, r17
	movq #1, r21
.LBB18_97:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r20
	movq r21, r19
	shl #1, r17
	lea 1(r19), r21
	cble r17, r5, .LBB18_97
; %bb.98:                               ; %.preheader19
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq r5, r17
	br .LBB18_99
.LBB18_101:                             ;   in Loop: Header=BB18_99 Depth=2
	sub r21, r17
	movq r20, r21
	shr #63, r21
	add r20, r21
	sar #1, r21
	lea -1(r19), r19
	movq r21, r20
	cble r19, #0, .LBB18_102
.LBB18_99:                              ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r21
	cblt r17, r20, .LBB18_101
; %bb.100:                              ;   in Loop: Header=BB18_99 Depth=2
	movq r20, r21
	br .LBB18_101
.LBB18_102:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_104
; %bb.103:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_104:                             ;   in Loop: Header=BB18_1 Depth=1
	movzl r17, r17
	movzl r18, r18
	cbne r18, r17, .LBB18_141
; %bb.105:                              ; %.preheader18
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #10, r17
	movq #1, r20
.LBB18_106:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r19
	movq r20, r18
	shl #1, r17
	lea 1(r18), r20
	cble r17, r5, .LBB18_106
; %bb.107:                              ; %.preheader17
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq r5, r17
	br .LBB18_108
.LBB18_110:                             ;   in Loop: Header=BB18_108 Depth=2
	sub r20, r17
	movq r19, r20
	shr #63, r20
	add r19, r20
	sar #1, r20
	lea -1(r18), r18
	movq r20, r19
	cble r18, #0, .LBB18_111
.LBB18_108:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r20
	cblt r17, r19, .LBB18_110
; %bb.109:                              ;   in Loop: Header=BB18_108 Depth=2
	movq r19, r20
	br .LBB18_110
.LBB18_111:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_113
; %bb.112:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_113:                             ;   in Loop: Header=BB18_1 Depth=1
	movq r16, r18
	shr #63, r18
	movq r16, r19
	sar #34, r19
	add r18, r19
	mul #10, r19
	movq r6, r18
	sub r19, r18
	movzl r18, r18
	movzl r17, r17
	cbne r18, r17, .LBB18_141
; %bb.114:                              ; %.preheader16
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #60, r17
	movq #1, r20
.LBB18_115:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r19
	movq r20, r18
	shl #1, r17
	lea 1(r18), r20
	cble r17, r5, .LBB18_115
; %bb.116:                              ; %.preheader15
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq r5, r17
	br .LBB18_117
.LBB18_119:                             ;   in Loop: Header=BB18_117 Depth=2
	sub r20, r17
	movq r19, r20
	shr #63, r20
	add r19, r20
	sar #1, r20
	lea -1(r18), r18
	movq r20, r19
	cble r18, #0, .LBB18_120
.LBB18_117:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r20
	cblt r17, r19, .LBB18_119
; %bb.118:                              ;   in Loop: Header=BB18_117 Depth=2
	movq r19, r20
	br .LBB18_119
.LBB18_120:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_122
; %bb.121:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_122:                             ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r18
	mul #-2004318071, r18
	shr #32, r18
	add r6, r18
	movl r18, r19
	and r3, r18
	shr #31, r18
	shr #5, r19
	add r18, r19
	mul #60, r19
	movq r6, r18
	sub r19, r18
	movzl r18, r18
	movzl r17, r17
	cbne r18, r17, .LBB18_141
; %bb.123:                              ; %.preheader14
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #65521, r17
	movq #1, r20
.LBB18_124:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r19
	movq r20, r18
	shl #1, r17
	lea 1(r18), r20
	cble r17, r5, .LBB18_124
; %bb.125:                              ; %.preheader13
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq r5, r17
	br .LBB18_126
.LBB18_128:                             ;   in Loop: Header=BB18_126 Depth=2
	sub r20, r17
	movq r19, r20
	shr #63, r20
	add r19, r20
	sar #1, r20
	lea -1(r18), r18
	movq r20, r19
	cble r18, #0, .LBB18_129
.LBB18_126:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r20
	cblt r17, r19, .LBB18_128
; %bb.127:                              ;   in Loop: Header=BB18_126 Depth=2
	movq r19, r20
	br .LBB18_128
.LBB18_129:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_131
; %bb.130:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_131:                             ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r18
	mul #-2146992015, r18
	shr #32, r18
	add r6, r18
	movl r18, r19
	and r3, r18
	shr #31, r18
	shr #15, r19
	add r18, r19
	mul #65521, r19
	movq r6, r18
	sub r19, r18
	movzl r18, r18
	movzl r17, r17
	cbne r18, r17, .LBB18_141
; %bb.132:                              ; %.preheader12
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq #1000000007, r17
	movq #1, r20
.LBB18_133:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r19
	movq r20, r18
	shl #1, r17
	lea 1(r18), r20
	cble r17, r5, .LBB18_133
; %bb.134:                              ; %.preheader11
                                        ;   in Loop: Header=BB18_1 Depth=1
	movq r5, r17
	br .LBB18_135
.LBB18_137:                             ;   in Loop: Header=BB18_135 Depth=2
	sub r20, r17
	movq r19, r20
	shr #63, r20
	add r19, r20
	sar #1, r20
	lea -1(r18), r18
	movq r20, r19
	cble r18, #0, .LBB18_138
.LBB18_135:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r20
	cblt r17, r19, .LBB18_137
; %bb.136:                              ;   in Loop: Header=BB18_135 Depth=2
	movq r19, r20
	br .LBB18_137
.LBB18_138:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_140
; %bb.139:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_140:                             ;   in Loop: Header=BB18_1 Depth=1
	movq r6, r18
	mul #1152921497, r18
	movq r18, r19
	shr #63, r19
	sar #60, r18
	add r19, r18
	mul #1000000007, r18
	movq r6, r19
	sub r18, r19
	movzl r19, r18
	movzl r17, r17
	cbeq r18, r17, .LBB18_142
.LBB18_141:                             ;   in Loop: Header=BB18_1 Depth=1
	bis #4, r0
.LBB18_142:                             ;   in Loop: Header=BB18_1 Depth=1
	movq r16, r17
	shr #63, r17
	sar #34, r16
	add r17, r16
	mul #-999, r16
	movq #10, r17
	movq #1, r20
.LBB18_143:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r17, r19
	movq r20, r18
	shl #1, r17
	lea 1(r18), r20
	cble r17, r5, .LBB18_143
; %bb.144:                              ;   in Loop: Header=BB18_1 Depth=1
	mul #100, r6
	clr r17
	movq r5, r20
	br .LBB18_145
.LBB18_149:                             ;   in Loop: Header=BB18_145 Depth=2
	sub r21, r20
	add r22, r17
	movq r19, r21
	shr #63, r21
	add r19, r21
	sar #1, r21
	movq r21, r19
	cble r18, #0, .LBB18_150
.LBB18_145:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r21
	cblt r20, r19, .LBB18_147
; %bb.146:                              ;   in Loop: Header=BB18_145 Depth=2
	movq r19, r21
.LBB18_147:                             ;   in Loop: Header=BB18_145 Depth=2
	lea -1(r18), r18
	clr r22
	cblt r20, r19, .LBB18_149
; %bb.148:                              ;   in Loop: Header=BB18_145 Depth=2
	movq #1, r22
	shl r18, r22
	br .LBB18_149
.LBB18_150:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_152
; %bb.151:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r17
.LBB18_152:                             ;   in Loop: Header=BB18_1 Depth=1
	movq #10, r20
	movq #1, r21
.LBB18_153:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r20, r19
	movq r21, r18
	shl #1, r20
	lea 1(r18), r21
	cble r20, r5, .LBB18_153
; %bb.154:                              ;   in Loop: Header=BB18_1 Depth=1
	add r6, r16
	br .LBB18_155
.LBB18_157:                             ;   in Loop: Header=BB18_155 Depth=2
	sub r6, r5
	movq r19, r6
	shr #63, r6
	add r19, r6
	sar #1, r6
	lea -1(r18), r18
	movq r6, r19
	cble r18, #0, .LBB18_158
.LBB18_155:                             ;   Parent Loop BB18_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r6
	cblt r5, r19, .LBB18_157
; %bb.156:                              ;   in Loop: Header=BB18_155 Depth=2
	movq r19, r6
	br .LBB18_157
.LBB18_158:                             ;   in Loop: Header=BB18_1 Depth=1
	cbeq r7, #0, .LBB18_160
; %bb.159:                              ;   in Loop: Header=BB18_1 Depth=1
	neg r5
.LBB18_160:                             ;   in Loop: Header=BB18_1 Depth=1
	mul #100, r5
	add r17, r5
	movzl r5, r5
	movzl r16, r6
	cbeq r6, r5, .LBB18_162
; %bb.161:                              ;   in Loop: Header=BB18_1 Depth=1
	bis #8, r0
	br .LBB18_162
.LBB18_163:                             ; %.preheader10
	clr r1
	movq #12345, r2
	movq =4294967294, r3
	movq =2147483648, r4
.LBB18_165:                             ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB18_168 Depth 2
                                        ;     Child Loop BB18_170 Depth 2
                                        ;     Child Loop BB18_179 Depth 2
                                        ;     Child Loop BB18_181 Depth 2
                                        ;     Child Loop BB18_188 Depth 2
                                        ;     Child Loop BB18_190 Depth 2
                                        ;     Child Loop BB18_199 Depth 2
                                        ;     Child Loop BB18_201 Depth 2
                                        ;     Child Loop BB18_208 Depth 2
                                        ;     Child Loop BB18_210 Depth 2
	mul #1103515245, r2
	lea 12345(r2), r2
	movq r2, r6
	and r3, r6
	shr #1, r6
	movq #1073741824, r5
	bic r2, r5
	sub r5, r6
	movq r1, r7
	and #1, r7
	movq r6, r5
	cbeq r7, #0, .LBB18_167
; %bb.166:                              ;   in Loop: Header=BB18_165 Depth=1
	movq r6, r5
	neg r5
.LBB18_167:                             ;   in Loop: Header=BB18_165 Depth=1
	movl r5, r5
	movl r6, r6
	movq r6, r7
	sar #63, r7
	xor r7, r6
	sub r7, r6
	movq #10, r7
	movq #1, r18
.LBB18_168:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r7, r17
	movq r18, r16
	shl #1, r7
	lea 1(r16), r18
	cble r7, r6, .LBB18_168
; %bb.169:                              ; %.preheader9
                                        ;   in Loop: Header=BB18_165 Depth=1
	clr r7
	movq r6, r18
	br .LBB18_170
.LBB18_174:                             ;   in Loop: Header=BB18_170 Depth=2
	sub r19, r18
	add r20, r7
	movq r17, r19
	shr #63, r19
	add r17, r19
	sar #1, r19
	movq r19, r17
	cble r16, #0, .LBB18_175
.LBB18_170:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r19
	cblt r18, r17, .LBB18_172
; %bb.171:                              ;   in Loop: Header=BB18_170 Depth=2
	movq r17, r19
.LBB18_172:                             ;   in Loop: Header=BB18_170 Depth=2
	lea -1(r16), r16
	clr r20
	cblt r18, r17, .LBB18_174
; %bb.173:                              ;   in Loop: Header=BB18_170 Depth=2
	movq #1, r20
	shl r16, r20
	br .LBB18_174
.LBB18_175:                             ;   in Loop: Header=BB18_165 Depth=1
	cbge r5, #0, .LBB18_177
; %bb.176:                              ;   in Loop: Header=BB18_165 Depth=1
	neg r7
.LBB18_177:                             ;   in Loop: Header=BB18_165 Depth=1
	movq r5, r16
	mul #1717986919, r16
	movq r16, r17
	shr #63, r17
	sar #34, r16
	add r17, r16
	movzl r16, r17
	movzl r7, r7
	cbne r17, r7, .LBB18_218
; %bb.178:                              ; %.preheader8
                                        ;   in Loop: Header=BB18_165 Depth=1
	mul #10, r16
	movq r5, r7
	sub r16, r7
	movq #10, r16
	movq #1, r19
.LBB18_179:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r16, r18
	movq r19, r17
	shl #1, r16
	lea 1(r17), r19
	cble r16, r6, .LBB18_179
; %bb.180:                              ; %.preheader7
                                        ;   in Loop: Header=BB18_165 Depth=1
	movq r6, r16
	br .LBB18_181
.LBB18_183:                             ;   in Loop: Header=BB18_181 Depth=2
	sub r19, r16
	movq r18, r19
	shr #63, r19
	add r18, r19
	sar #1, r19
	lea -1(r17), r17
	movq r19, r18
	cble r17, #0, .LBB18_184
.LBB18_181:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r19
	cblt r16, r18, .LBB18_183
; %bb.182:                              ;   in Loop: Header=BB18_181 Depth=2
	movq r18, r19
	br .LBB18_183
.LBB18_184:                             ;   in Loop: Header=BB18_165 Depth=1
	cbge r5, #0, .LBB18_186
; %bb.185:                              ;   in Loop: Header=BB18_165 Depth=1
	neg r16
.LBB18_186:                             ;   in Loop: Header=BB18_165 Depth=1
	movzl r16, r16
	movzl r7, r7
	cbne r7, r16, .LBB18_218
; %bb.187:                              ; %.preheader6
                                        ;   in Loop: Header=BB18_165 Depth=1
	movq #7, r7
	movq #1, r18
.LBB18_188:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r7, r17
	movq r18, r16
	shl #1, r7
	lea 1(r16), r18
	cble r7, r6, .LBB18_188
; %bb.189:                              ; %.preheader5
                                        ;   in Loop: Header=BB18_165 Depth=1
	clr r7
	movq r6, r18
	br .LBB18_190
.LBB18_194:                             ;   in Loop: Header=BB18_190 Depth=2
	sub r19, r18
	add r20, r7
	movq r17, r19
	shr #63, r19
	add r17, r19
	sar #1, r19
	movq r19, r17
	cble r16, #0, .LBB18_195
.LBB18_190:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r19
	cblt r18, r17, .LBB18_192
; %bb.191:                              ;   in Loop: Header=BB18_190 Depth=2
	movq r17, r19
.LBB18_192:                             ;   in Loop: Header=BB18_190 Depth=2
	lea -1(r16), r16
	clr r20
	cblt r18, r17, .LBB18_194
; %bb.193:                              ;   in Loop: Header=BB18_190 Depth=2
	movq #1, r20
	shl r16, r20
	br .LBB18_194
.LBB18_195:                             ;   in Loop: Header=BB18_165 Depth=1
	cbge r5, #0, .LBB18_197
; %bb.196:                              ;   in Loop: Header=BB18_165 Depth=1
	neg r7
.LBB18_197:                             ;   in Loop: Header=BB18_165 Depth=1
	movq r5, r16
	mul #-1840700269, r16
	shr #32, r16
	add r5, r16
	movl r16, r17
	and r4, r16
	shr #31, r16
	shr #2, r17
	add r16, r17
	movzl r17, r16
	movzl r7, r7
	cbne r16, r7, .LBB18_218
; %bb.198:                              ; %.preheader4
                                        ;   in Loop: Header=BB18_165 Depth=1
	movq #60, r7
	movq #1, r18
.LBB18_199:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r7, r17
	movq r18, r16
	shl #1, r7
	lea 1(r16), r18
	cble r7, r6, .LBB18_199
; %bb.200:                              ; %.preheader3
                                        ;   in Loop: Header=BB18_165 Depth=1
	movq r6, r7
	br .LBB18_201
.LBB18_203:                             ;   in Loop: Header=BB18_201 Depth=2
	sub r18, r7
	movq r17, r18
	shr #63, r18
	add r17, r18
	sar #1, r18
	lea -1(r16), r16
	movq r18, r17
	cble r16, #0, .LBB18_204
.LBB18_201:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r18
	cblt r7, r17, .LBB18_203
; %bb.202:                              ;   in Loop: Header=BB18_201 Depth=2
	movq r17, r18
	br .LBB18_203
.LBB18_204:                             ;   in Loop: Header=BB18_165 Depth=1
	cbge r5, #0, .LBB18_206
; %bb.205:                              ;   in Loop: Header=BB18_165 Depth=1
	neg r7
.LBB18_206:                             ;   in Loop: Header=BB18_165 Depth=1
	movq r5, r16
	mul #-2004318071, r16
	shr #32, r16
	add r5, r16
	movl r16, r17
	and r4, r16
	shr #31, r16
	shr #5, r17
	add r16, r17
	mul #60, r17
	movq r5, r16
	sub r17, r16
	movzl r16, r16
	movzl r7, r7
	cbne r16, r7, .LBB18_218
; %bb.207:                              ; %.preheader2
                                        ;   in Loop: Header=BB18_165 Depth=1
	movq #12345, r7
	movq #1, r18
.LBB18_208:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r7, r17
	movq r18, r16
	shl #1, r7
	lea 1(r16), r18
	cble r7, r6, .LBB18_208
; %bb.209:                              ; %.preheader1
                                        ;   in Loop: Header=BB18_165 Depth=1
	clr r7
	br .LBB18_210
.LBB18_214:                             ;   in Loop: Header=BB18_210 Depth=2
	sub r18, r6
	add r19, r7
	movq r17, r18
	shr #63, r18
	add r17, r18
	sar #1, r18
	movq r18, r17
	cble r16, #0, .LBB18_215
.LBB18_210:                             ;   Parent Loop BB18_165 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r18
	cblt r6, r17, .LBB18_212
; %bb.211:                              ;   in Loop: Header=BB18_210 Depth=2
	movq r17, r18
.LBB18_212:                             ;   in Loop: Header=BB18_210 Depth=2
	lea -1(r16), r16
	clr r19
	cblt r6, r17, .LBB18_214
; %bb.213:                              ;   in Loop: Header=BB18_210 Depth=2
	movq #1, r19
	shl r16, r19
	br .LBB18_214
.LBB18_215:                             ;   in Loop: Header=BB18_165 Depth=1
	cbge r5, #0, .LBB18_217
; %bb.216:                              ;   in Loop: Header=BB18_165 Depth=1
	neg r7
.LBB18_217:                             ;   in Loop: Header=BB18_165 Depth=1
	movq r5, r6
	mul #-1444876401, r6
	shr #32, r6
	add r5, r6
	movl r6, r5
	and r4, r6
	shr #31, r6
	shr #13, r5
	add r6, r5
	movzl r5, r5
	movzl r7, r6
	cbne r5, r6, .LBB18_218
; %bb.164:                              ;   in Loop: Header=BB18_165 Depth=1
	lea 1(r1), r1
	movzl r1, r5
	cbne r5, #3000, .LBB18_165
	br .LBB18_219
.LBB18_218:
	bis #16, r0
.LBB18_219:
	movq =4294967246, r1
	br .LBB18_220
.LBB18_242:                             ;   in Loop: Header=BB18_220 Depth=1
	lea 7(r1), r2
	movl r1, r3
	movq r2, r1
	cbge r3, #43, .LBB18_243
.LBB18_220:                             ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB18_221 Depth 2
                                        ;       Child Loop BB18_222 Depth 3
                                        ;       Child Loop BB18_224 Depth 3
                                        ;       Child Loop BB18_232 Depth 3
                                        ;       Child Loop BB18_234 Depth 3
	movq =4294967266, r3
	br .LBB18_221
.LBB18_241:                             ;   in Loop: Header=BB18_221 Depth=2
	lea 5(r2), r3
	movl r2, r2
	cbge r2, #35, .LBB18_242
.LBB18_221:                             ;   Parent Loop BB18_220 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB18_222 Depth 3
                                        ;       Child Loop BB18_224 Depth 3
                                        ;       Child Loop BB18_232 Depth 3
                                        ;       Child Loop BB18_234 Depth 3
	movq r3, r2
	mul r1, r3
	movl r3, r7
	lea 7(r3), r4
	movq r1, r5
	sub r2, r5
	movl r5, r3
	movq r3, r6
	mul #715827883, r6
	movq r6, r16
	shr #63, r16
	sar #33, r6
	add r16, r6
	mul #12, r6
	sub r6, r5
	movl r4, r4
	movq r4, r6
	sar #63, r6
	movq r4, r16
	xor r6, r16
	sub r6, r16
	movq #10, r6
	movq #1, r19
.LBB18_222:                             ;   Parent Loop BB18_220 Depth=1
                                        ;     Parent Loop BB18_221 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	movq r6, r18
	movq r19, r17
	shl #1, r6
	lea 1(r17), r19
	cble r6, r16, .LBB18_222
; %bb.223:                              ;   in Loop: Header=BB18_221 Depth=2
	mul #1717986919, r4
	movq r4, r6
	shr #63, r6
	sar #34, r4
	add r6, r4
	clr r6
	br .LBB18_224
.LBB18_228:                             ;   in Loop: Header=BB18_224 Depth=3
	sub r19, r16
	add r20, r6
	movq r18, r19
	shr #63, r19
	add r18, r19
	sar #1, r19
	movq r19, r18
	cble r17, #0, .LBB18_229
.LBB18_224:                             ;   Parent Loop BB18_220 Depth=1
                                        ;     Parent Loop BB18_221 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	clr r19
	cblt r16, r18, .LBB18_226
; %bb.225:                              ;   in Loop: Header=BB18_224 Depth=3
	movq r18, r19
.LBB18_226:                             ;   in Loop: Header=BB18_224 Depth=3
	lea -1(r17), r17
	clr r20
	cblt r16, r18, .LBB18_228
; %bb.227:                              ;   in Loop: Header=BB18_224 Depth=3
	movq #1, r20
	shl r17, r20
	br .LBB18_228
.LBB18_229:                             ;   in Loop: Header=BB18_221 Depth=2
	cbge r7, #-7, .LBB18_231
; %bb.230:                              ;   in Loop: Header=BB18_221 Depth=2
	neg r6
.LBB18_231:                             ;   in Loop: Header=BB18_221 Depth=2
	movq r3, r16
	sar #63, r16
	movq r3, r7
	xor r16, r7
	sub r16, r7
	movq #12, r18
	movq #1, r19
.LBB18_232:                             ;   Parent Loop BB18_220 Depth=1
                                        ;     Parent Loop BB18_221 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	movq r18, r17
	movq r19, r16
	shl #1, r18
	lea 1(r16), r19
	cble r18, r7, .LBB18_232
; %bb.233:                              ;   in Loop: Header=BB18_221 Depth=2
	add r5, r4
	br .LBB18_234
.LBB18_236:                             ;   in Loop: Header=BB18_234 Depth=3
	sub r5, r7
	movq r17, r5
	shr #63, r5
	add r17, r5
	sar #1, r5
	lea -1(r16), r16
	movq r5, r17
	cble r16, #0, .LBB18_237
.LBB18_234:                             ;   Parent Loop BB18_220 Depth=1
                                        ;     Parent Loop BB18_221 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	clr r5
	cblt r7, r17, .LBB18_236
; %bb.235:                              ;   in Loop: Header=BB18_234 Depth=3
	movq r17, r5
	br .LBB18_236
.LBB18_237:                             ;   in Loop: Header=BB18_221 Depth=2
	cbge r3, #0, .LBB18_239
; %bb.238:                              ;   in Loop: Header=BB18_221 Depth=2
	neg r7
.LBB18_239:                             ;   in Loop: Header=BB18_221 Depth=2
	add r6, r7
	movzl r7, r3
	movzl r4, r4
	cbeq r4, r3, .LBB18_241
; %bb.240:                              ;   in Loop: Header=BB18_221 Depth=2
	bis #32, r0
	br .LBB18_241
.LBB18_243:                             ; %.preheader
	movq =4294966296, r1
	movq =2147483648, r2
	br .LBB18_244
.LBB18_264:                             ;   in Loop: Header=BB18_244 Depth=1
	lea 13(r1), r1
	cbge r7, #987, .LBB18_265
.LBB18_244:                             ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB18_245 Depth 2
                                        ;     Child Loop BB18_247 Depth 2
                                        ;     Child Loop BB18_255 Depth 2
                                        ;     Child Loop BB18_257 Depth 2
	lea 1(r1), r4
	movq r1, r5
	mul #5, r5
	movl r5, r3
	movq r3, r6
	mul #-1840700269, r6
	shr #32, r6
	add r5, r6
	movl r6, r7
	and r2, r6
	shr #31, r6
	sar #2, r7
	add r6, r7
	mul #7, r7
	sub r7, r5
	movl r4, r4
	movq r4, r6
	sar #63, r6
	movq r4, r7
	xor r6, r7
	sub r6, r7
	movq #3, r6
	movq #1, r18
.LBB18_245:                             ;   Parent Loop BB18_244 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r6, r17
	movq r18, r16
	shl #1, r6
	lea 1(r16), r18
	cble r6, r7, .LBB18_245
; %bb.246:                              ;   in Loop: Header=BB18_244 Depth=1
	mul #1431655766, r4
	movq r4, r6
	shr #63, r6
	shr #32, r4
	add r6, r4
	clr r6
	br .LBB18_247
.LBB18_251:                             ;   in Loop: Header=BB18_247 Depth=2
	sub r18, r7
	add r19, r6
	movq r17, r18
	shr #63, r18
	add r17, r18
	sar #1, r18
	movq r18, r17
	cble r16, #0, .LBB18_252
.LBB18_247:                             ;   Parent Loop BB18_244 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r18
	cblt r7, r17, .LBB18_249
; %bb.248:                              ;   in Loop: Header=BB18_247 Depth=2
	movq r17, r18
.LBB18_249:                             ;   in Loop: Header=BB18_247 Depth=2
	lea -1(r16), r16
	clr r19
	cblt r7, r17, .LBB18_251
; %bb.250:                              ;   in Loop: Header=BB18_247 Depth=2
	movq #1, r19
	shl r16, r19
	br .LBB18_251
.LBB18_252:                             ;   in Loop: Header=BB18_244 Depth=1
	movl r1, r7
	cbge r7, #-1, .LBB18_254
; %bb.253:                              ;   in Loop: Header=BB18_244 Depth=1
	neg r6
.LBB18_254:                             ;   in Loop: Header=BB18_244 Depth=1
	movq r3, r16
	sar #63, r16
	xor r16, r3
	sub r16, r3
	movq #7, r18
	movq #1, r19
.LBB18_255:                             ;   Parent Loop BB18_244 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r18, r17
	movq r19, r16
	shl #1, r18
	lea 1(r16), r19
	cble r18, r3, .LBB18_255
; %bb.256:                              ;   in Loop: Header=BB18_244 Depth=1
	sub r5, r4
	br .LBB18_257
.LBB18_259:                             ;   in Loop: Header=BB18_257 Depth=2
	sub r5, r3
	movq r17, r5
	shr #63, r5
	add r17, r5
	sar #1, r5
	lea -1(r16), r16
	movq r5, r17
	cble r16, #0, .LBB18_260
.LBB18_257:                             ;   Parent Loop BB18_244 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	clr r5
	cblt r3, r17, .LBB18_259
; %bb.258:                              ;   in Loop: Header=BB18_257 Depth=2
	movq r17, r5
	br .LBB18_259
.LBB18_260:                             ;   in Loop: Header=BB18_244 Depth=1
	cblt r7, #0, .LBB18_262
; %bb.261:                              ;   in Loop: Header=BB18_244 Depth=1
	neg r3
.LBB18_262:                             ;   in Loop: Header=BB18_244 Depth=1
	add r6, r3
	movzl r3, r3
	movzl r4, r4
	cbeq r4, r3, .LBB18_264
; %bb.263:                              ;   in Loop: Header=BB18_244 Depth=1
	bis #64, r0
	br .LBB18_264
.LBB18_265:
	movl r0, r0
	movq -8(r13), r8                        ; 8-byte Folded Reload
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.data
	.align	16                              ; @test.v
test.v:
	.long	0                               ; 0x0
	.long	1                               ; 0x1
	.long	4294967295                      ; 0xffffffff
	.long	2                               ; 0x2
	.long	3                               ; 0x3
	.long	4294967293                      ; 0xfffffffd
	.long	5                               ; 0x5
	.long	9                               ; 0x9
	.long	10                              ; 0xa
	.long	11                              ; 0xb
	.long	99                              ; 0x63
	.long	100                             ; 0x64
	.long	101                             ; 0x65
	.long	4294967197                      ; 0xffffff9d
	.long	4294967196                      ; 0xffffff9c
	.long	4294967195                      ; 0xffffff9b
	.long	999                             ; 0x3e7
	.long	1000                            ; 0x3e8
	.long	1001                            ; 0x3e9
	.long	12344                           ; 0x3038
	.long	12345                           ; 0x3039
	.long	12346                           ; 0x303a
	.long	65520                           ; 0xfff0
	.long	65521                           ; 0xfff1
	.long	65522                           ; 0xfff2
	.long	1000000006                      ; 0x3b9aca06
	.long	1000000007                      ; 0x3b9aca07
	.long	1000000008                      ; 0x3b9aca08
	.long	2147483646                      ; 0x7ffffffe
	.long	2147483647                      ; 0x7fffffff
	.long	2147483649                      ; 0x80000001
	.long	2147483648                      ; 0x80000000
	.long	2147483650                      ; 0x80000002
	.long	641                             ; 0x281
	.long	640                             ; 0x280
	.long	642                             ; 0x282
	.long	1234567890                      ; 0x499602d2
	.long	3060399406                      ; 0xb669fd2e

