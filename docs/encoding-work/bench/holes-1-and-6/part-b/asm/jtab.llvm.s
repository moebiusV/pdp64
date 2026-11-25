	.text
	.globl	dense                           ; -- Begin function dense
	.align	2
dense:                                  ; @dense
; %bb.0:
	movzl r0, r1
	movq =4294967295, r0
	cbhi r1, #9, .LBB0_2
; %bb.1:
	lea .Lswitch.table.test, r0
	movl 0(r0)(r1*4), r0
.LBB0_2:
	movl r0, r0
	ret
                                        ; -- End function
	.globl	nodefault                       ; -- Begin function nodefault
	.align	2
nodefault:                              ; @nodefault
; %bb.0:
	lea 3(r0), r0
	movzl r0, r1
	movq #100, r0
	cbhi r1, #9, .LBB1_2
; %bb.1:
	lea .Lswitch.table.test.1, r0
	movl 0(r0)(r1*4), r0
.LBB1_2:
	movl r0, r0
	ret
                                        ; -- End function
	.globl	lsw                             ; -- Begin function lsw
	.align	2
lsw:                                    ; @lsw
; %bb.0:
	lea -100(r0), r2
	clr r1
	cbhi r2, #8, .LBB2_2
; %bb.1:
	lea .Lswitch.table.test.2-800, r1
	movq 0(r1)(r0*8), r1
.LBB2_2:
	movq r1, r0
	ret
                                        ; -- End function
	.globl	csw                             ; -- Begin function csw
	.align	2
csw:                                    ; @csw
; %bb.0:
	lea -97(r0), r0
	movzb r0, r0
	cbcs r0, #9, .LBB3_1
; %bb.2:
	clr r0
	ret
.LBB3_1:
	lea 1(r0), r0
	ret
                                        ; -- End function
	.globl	usw                             ; -- Begin function usw
	.align	2
usw:                                    ; @usw
; %bb.0:
	movq =4294967288, r1
	and r0, r1
	shr #3, r1
	movq #500000000, r2
	cbeq r1, r2, .LBB4_1
; %bb.2:
	movq #99, r0
	movl r0, r0
	ret
.LBB4_1:
	add #294967297, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	fall                            ; -- Begin function fall
	.align	2
fall:                                   ; @fall
; %bb.0:
	movzl r0, r1
	movq =4294967291, r0
	cbhi r1, #7, .LBB5_2
; %bb.1:
	lea .Lswitch.table.fall, r0
	movl 0(r0)(r1*4), r0
.LBB5_2:
	movl r0, r0
	ret
                                        ; -- End function
	.globl	vm                              ; -- Begin function vm
	.align	2
vm:                                     ; @vm
; %bb.0:
	movl r1, r2
	cblt r2, #1, .LBB6_1
; %bb.2:
	movzl r1, r2
	clr r1
	lea .LJTI6_0, r3
	br .LBB6_3
.LBB6_9:                                ;   in Loop: Header=BB6_3 Depth=1
	xor #5, r1
.LBB6_15:                               ;   in Loop: Header=BB6_3 Depth=1
	lea -1(r2), r2
	cbeq r2, #0, .LBB6_16
.LBB6_3:                                ; =>This Inner Loop Header: Depth=1
	movzl (r0)+, r4
	cbhi r4, #8, .LBB6_14
; %bb.4:                                ;   in Loop: Header=BB6_3 Depth=1
	movq 0(r3)(r4*8), r4
	jmp (r4)
.LBB6_5:                                ;   in Loop: Header=BB6_3 Depth=1
	lea 1(r1), r1
	br .LBB6_15
.LBB6_7:                                ;   in Loop: Header=BB6_3 Depth=1
	mul #3, r1
	br .LBB6_15
.LBB6_8:                                ;   in Loop: Header=BB6_3 Depth=1
	lea -4(r1), r1
	br .LBB6_15
.LBB6_12:                               ;   in Loop: Header=BB6_3 Depth=1
	shl #1, r1
	br .LBB6_15
.LBB6_6:                                ;   in Loop: Header=BB6_3 Depth=1
	lea 2(r1), r1
	br .LBB6_15
.LBB6_10:                               ;   in Loop: Header=BB6_3 Depth=1
	bis #8, r1
	br .LBB6_15
.LBB6_11:                               ;   in Loop: Header=BB6_3 Depth=1
	movzb r1, r1
	br .LBB6_15
.LBB6_13:                               ;   in Loop: Header=BB6_3 Depth=1
	movl r1, r1
	sar #1, r1
	br .LBB6_15
.LBB6_14:                               ;   in Loop: Header=BB6_3 Depth=1
	lea 1000(r1), r1
	br .LBB6_15
.LBB6_16:
	movl r1, r0
	ret
.LBB6_1:
	clr r1
	movl r1, r0
	ret
	.data
	.align	8
.LJTI6_0:
	.quad	.LBB6_5
	.quad	.LBB6_6
	.quad	.LBB6_7
	.quad	.LBB6_8
	.quad	.LBB6_9
	.quad	.LBB6_10
	.quad	.LBB6_11
	.quad	.LBB6_12
	.quad	.LBB6_13
                                        ; -- End function
	.text
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r1
	lea .Lswitch.table.test, r2
	lea test.dr, r3
	clr r0
	br .LBB7_1
.LBB7_5:                                ;   in Loop: Header=BB7_1 Depth=1
	lea 1(r1), r1
	cbeq r1, #12, .LBB7_6
.LBB7_1:                                ; =>This Inner Loop Header: Depth=1
	movq =4294967295, r4
	cbhi r1, #9, .LBB7_3
; %bb.2:                                ;   in Loop: Header=BB7_1 Depth=1
	movl 0(r2)(r1*4), r4
.LBB7_3:                                ;   in Loop: Header=BB7_1 Depth=1
	movzl 0(r3)(r1*4), r5
	movzl r4, r4
	cbeq r4, r5, .LBB7_5
; %bb.4:                                ;   in Loop: Header=BB7_1 Depth=1
	movq #1, r0
	br .LBB7_5
.LBB7_6:                                ; %.preheader5
	movq #-3, r1
	lea .Lswitch.table.test.1, r2
	lea test.nr+12, r3
	br .LBB7_7
.LBB7_11:                               ;   in Loop: Header=BB7_7 Depth=1
	lea 1(r1), r1
	cbeq r1, #8, .LBB7_12
.LBB7_7:                                ; =>This Inner Loop Header: Depth=1
	lea 3(r1), r4
	movzl r4, r5
	movq #100, r4
	cbhi r5, #9, .LBB7_9
; %bb.8:                                ;   in Loop: Header=BB7_7 Depth=1
	movl 0(r2)(r5*4), r4
.LBB7_9:                                ;   in Loop: Header=BB7_7 Depth=1
	movzl 0(r3)(r1*4), r5
	movzl r4, r4
	cbeq r4, r5, .LBB7_11
; %bb.10:                               ;   in Loop: Header=BB7_7 Depth=1
	bis #4, r0
	br .LBB7_11
.LBB7_12:                               ; %.preheader4
	movq #99, r1
	lea .Lswitch.table.test.2, r2
	movq =4294967287, r3
	br .LBB7_13
.LBB7_21:                               ;   in Loop: Header=BB7_13 Depth=1
	lea 1(r1), r1
	cbeq r1, #111, .LBB7_22
.LBB7_13:                               ; =>This Inner Loop Header: Depth=1
	lea -100(r1), r4
	movzl r4, r6
	clr r4
	clr r5
	cbhi r6, #8, .LBB7_15
; %bb.14:                               ;   in Loop: Header=BB7_13 Depth=1
	movq 0(r2)(r6*8), r5
.LBB7_15:                               ;   in Loop: Header=BB7_13 Depth=1
	lea -109(r1), r6
	movzl r6, r7
	clr r6
	cbcc r7, r3, .LBB7_16
; %bb.17:                               ;   in Loop: Header=BB7_13 Depth=1
	cbne r1, #104, .LBB7_18
.LBB7_19:                               ;   in Loop: Header=BB7_13 Depth=1
	cbeq r5, r4, .LBB7_21
	br .LBB7_20
.LBB7_16:                               ;   in Loop: Header=BB7_13 Depth=1
	lea -99(r1), r6
	cbeq r1, #104, .LBB7_19
.LBB7_18:                               ;   in Loop: Header=BB7_13 Depth=1
	movq r6, r4
	cbeq r5, r4, .LBB7_21
.LBB7_20:                               ;   in Loop: Header=BB7_13 Depth=1
	bis #16, r0
	br .LBB7_21
.LBB7_22:                               ; %.preheader3
	movq #96, r1
	br .LBB7_23
.LBB7_28:                               ;   in Loop: Header=BB7_23 Depth=1
	lea 1(r1), r1
	movzl r1, r2
	cbeq r2, #106, .LBB7_29
.LBB7_23:                               ; =>This Inner Loop Header: Depth=1
	lea -97(r1), r2
	movzb r2, r2
	cbcs r2, #9, .LBB7_24
; %bb.25:                               ;   in Loop: Header=BB7_23 Depth=1
	clr r2
	br .LBB7_26
.LBB7_24:                               ;   in Loop: Header=BB7_23 Depth=1
	lea 1(r2), r2
.LBB7_26:                               ;   in Loop: Header=BB7_23 Depth=1
	lea -96(r1), r3
	movzl r3, r3
	cbeq r2, r3, .LBB7_28
; %bb.27:                               ;   in Loop: Header=BB7_23 Depth=1
	bis #64, r0
	br .LBB7_28
.LBB7_29:                               ; %.preheader2
	clr r1
	movq =4294967295, r2
	br .LBB7_30
.LBB7_38:                               ;   in Loop: Header=BB7_30 Depth=1
	lea 1(r1), r1
	movzl r1, r3
	cbeq r3, #10, .LBB7_39
.LBB7_30:                               ; =>This Inner Loop Header: Depth=1
	movzl r1, r6
	movq r6, r3
	add r2, r3
	movzl r3, r5
	movq r1, r4
	cbcc r5, #8, .LBB7_31
; %bb.32:                               ;   in Loop: Header=BB7_30 Depth=1
	movq r1, r7
	cbeq r6, #9, .LBB7_33
.LBB7_34:                               ;   in Loop: Header=BB7_30 Depth=1
	cbne r5, r3, .LBB7_36
.LBB7_35:                               ;   in Loop: Header=BB7_30 Depth=1
	movq #99, r7
.LBB7_36:                               ;   in Loop: Header=BB7_30 Depth=1
	movzl r4, r3
	movzl r7, r4
	cbeq r3, r4, .LBB7_38
; %bb.37:                               ;   in Loop: Header=BB7_30 Depth=1
	bis #256, r0
	br .LBB7_38
.LBB7_31:                               ;   in Loop: Header=BB7_30 Depth=1
	movq #99, r4
	movq r1, r7
	cbne r6, #9, .LBB7_34
.LBB7_33:                               ;   in Loop: Header=BB7_30 Depth=1
	movq #99, r7
	cbeq r5, r3, .LBB7_35
	br .LBB7_36
.LBB7_39:                               ; %.preheader1
	clr r3
	lea test.code, r1
	lea .LJTI7_0, r4
	clr r2
	br .LBB7_40
.LBB7_46:                               ;   in Loop: Header=BB7_40 Depth=1
	xor #5, r2
.LBB7_52:                               ;   in Loop: Header=BB7_40 Depth=1
	lea 1(r3), r3
	cbeq r3, #15, .LBB7_53
.LBB7_40:                               ; =>This Inner Loop Header: Depth=1
	movzl 0(r1)(r3*4), r5
	cbhi r5, #8, .LBB7_51
; %bb.41:                               ;   in Loop: Header=BB7_40 Depth=1
	movq 0(r4)(r5*8), r5
	jmp (r5)
.LBB7_42:                               ;   in Loop: Header=BB7_40 Depth=1
	lea 1(r2), r2
	br .LBB7_52
.LBB7_44:                               ;   in Loop: Header=BB7_40 Depth=1
	mul #3, r2
	br .LBB7_52
.LBB7_45:                               ;   in Loop: Header=BB7_40 Depth=1
	lea -4(r2), r2
	br .LBB7_52
.LBB7_49:                               ;   in Loop: Header=BB7_40 Depth=1
	shl #1, r2
	br .LBB7_52
.LBB7_43:                               ;   in Loop: Header=BB7_40 Depth=1
	lea 2(r2), r2
	br .LBB7_52
.LBB7_47:                               ;   in Loop: Header=BB7_40 Depth=1
	bis #8, r2
	br .LBB7_52
.LBB7_48:                               ;   in Loop: Header=BB7_40 Depth=1
	movzb r2, r2
	br .LBB7_52
.LBB7_50:                               ;   in Loop: Header=BB7_40 Depth=1
	movl r2, r2
	sar #1, r2
	br .LBB7_52
.LBB7_51:                               ;   in Loop: Header=BB7_40 Depth=1
	lea 1000(r2), r2
	br .LBB7_52
.LBB7_53:                               ; %.preheader
	clr r3
	lea .LJTI7_1, r5
	clr r4
	br .LBB7_54
.LBB7_60:                               ;   in Loop: Header=BB7_54 Depth=1
	xor #5, r4
.LBB7_66:                               ;   in Loop: Header=BB7_54 Depth=1
	lea 1(r3), r3
	cbeq r3, #15, .LBB7_67
.LBB7_54:                               ; =>This Inner Loop Header: Depth=1
	movzl 0(r1)(r3*4), r6
	cbhi r6, #8, .LBB7_65
; %bb.55:                               ;   in Loop: Header=BB7_54 Depth=1
	movq 0(r5)(r6*8), r6
	jmp (r6)
.LBB7_56:                               ;   in Loop: Header=BB7_54 Depth=1
	lea 1(r4), r4
	br .LBB7_66
.LBB7_58:                               ;   in Loop: Header=BB7_54 Depth=1
	mul #3, r4
	br .LBB7_66
.LBB7_59:                               ;   in Loop: Header=BB7_54 Depth=1
	lea -4(r4), r4
	br .LBB7_66
.LBB7_63:                               ;   in Loop: Header=BB7_54 Depth=1
	shl #1, r4
	br .LBB7_66
.LBB7_57:                               ;   in Loop: Header=BB7_54 Depth=1
	lea 2(r4), r4
	br .LBB7_66
.LBB7_61:                               ;   in Loop: Header=BB7_54 Depth=1
	bis #8, r4
	br .LBB7_66
.LBB7_62:                               ;   in Loop: Header=BB7_54 Depth=1
	movzb r4, r4
	br .LBB7_66
.LBB7_64:                               ;   in Loop: Header=BB7_54 Depth=1
	movl r4, r4
	sar #1, r4
	br .LBB7_66
.LBB7_65:                               ;   in Loop: Header=BB7_54 Depth=1
	lea 1000(r4), r4
	br .LBB7_66
.LBB7_67:
	movzl r2, r1
	movzl r4, r2
	cbeq r2, r1, .LBB7_69
; %bb.68:
	bis #2048, r0
.LBB7_69:
	movl r0, r0
	ret
	.data
	.align	8
.LJTI7_0:
	.quad	.LBB7_42
	.quad	.LBB7_43
	.quad	.LBB7_44
	.quad	.LBB7_45
	.quad	.LBB7_46
	.quad	.LBB7_47
	.quad	.LBB7_48
	.quad	.LBB7_49
	.quad	.LBB7_50
.LJTI7_1:
	.quad	.LBB7_56
	.quad	.LBB7_57
	.quad	.LBB7_58
	.quad	.LBB7_59
	.quad	.LBB7_60
	.quad	.LBB7_61
	.quad	.LBB7_62
	.quad	.LBB7_63
	.quad	.LBB7_64
                                        ; -- End function
	.align	16                              ; @test.code
test.code:
	.long	0                               ; 0x0
	.long	1                               ; 0x1
	.long	2                               ; 0x2
	.long	3                               ; 0x3
	.long	4                               ; 0x4
	.long	5                               ; 0x5
	.long	6                               ; 0x6
	.long	7                               ; 0x7
	.long	8                               ; 0x8
	.long	9                               ; 0x9
	.long	10                              ; 0xa
	.long	2                               ; 0x2
	.long	7                               ; 0x7
	.long	3                               ; 0x3
	.long	8                               ; 0x8

	.align	16                              ; @test.dr
test.dr:
	.long	10                              ; 0xa
	.long	11                              ; 0xb
	.long	12                              ; 0xc
	.long	13                              ; 0xd
	.long	4294967295                      ; 0xffffffff
	.long	15                              ; 0xf
	.long	16                              ; 0x10
	.long	17                              ; 0x11
	.long	18                              ; 0x12
	.long	19                              ; 0x13
	.long	4294967295                      ; 0xffffffff
	.long	4294967295                      ; 0xffffffff

	.align	16                              ; @test.nr
test.nr:
	.long	1                               ; 0x1
	.long	2                               ; 0x2
	.long	3                               ; 0x3
	.long	4                               ; 0x4
	.long	5                               ; 0x5
	.long	6                               ; 0x6
	.long	100                             ; 0x64
	.long	8                               ; 0x8
	.long	9                               ; 0x9
	.long	10                              ; 0xa
	.long	100                             ; 0x64

	.align	4                               ; @switch.table.fall
.Lswitch.table.fall:
	.long	15                              ; 0xf
	.long	14                              ; 0xe
	.long	12                              ; 0xc
	.long	8                               ; 0x8
	.long	240                             ; 0xf0
	.long	224                             ; 0xe0
	.long	192                             ; 0xc0
	.long	128                             ; 0x80

	.align	4                               ; @switch.table.test
.Lswitch.table.test:
	.long	10                              ; 0xa
	.long	11                              ; 0xb
	.long	12                              ; 0xc
	.long	13                              ; 0xd
	.long	4294967295                      ; 0xffffffff
	.long	15                              ; 0xf
	.long	16                              ; 0x10
	.long	17                              ; 0x11
	.long	18                              ; 0x12
	.long	19                              ; 0x13

	.align	4                               ; @switch.table.test.1
.Lswitch.table.test.1:
	.long	1                               ; 0x1
	.long	2                               ; 0x2
	.long	3                               ; 0x3
	.long	4                               ; 0x4
	.long	5                               ; 0x5
	.long	6                               ; 0x6
	.long	100                             ; 0x64
	.long	8                               ; 0x8
	.long	9                               ; 0x9
	.long	10                              ; 0xa

	.align	8                               ; @switch.table.test.2
.Lswitch.table.test.2:
	.quad	1                               ; 0x1
	.quad	2                               ; 0x2
	.quad	3                               ; 0x3
	.quad	4                               ; 0x4
	.quad	0                               ; 0x0
	.quad	6                               ; 0x6
	.quad	7                               ; 0x7
	.quad	8                               ; 0x8
	.quad	9                               ; 0x9

