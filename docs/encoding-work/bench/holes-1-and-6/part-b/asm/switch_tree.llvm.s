	.text
	.globl	dense                           ; -- Begin function dense
	.align	2
dense:                                  ; @dense
; %bb.0:
	movzl r0, r1
	cbcs r1, #11, .LBB0_1
; %bb.2:
	movq #-1, r0
	movl r0, r0
	ret
.LBB0_1:
	lea 10(r0), r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	sparse                          ; -- Begin function sparse
	.align	2
sparse:                                 ; @sparse
; %bb.0:
	movzl r0, r1
	movq #69999, r0
	cbgt r1, r0, .LBB1_8
; %bb.1:
	cbgt r1, #49, .LBB1_5
; %bb.2:
	cbeq r1, #0, .LBB1_15
; %bb.3:
	cbne r1, #9, .LBB1_18
; %bb.4:
	movq #4, r0
	ret
.LBB1_8:
	movq =4294867295, r0
	cbgt r1, r0, .LBB1_12
; %bb.9:
	movq #70000, r0
	cbeq r1, r0, .LBB1_17
; %bb.10:
	movq #2000000000, r0
	cbne r1, r0, .LBB1_18
; %bb.11:
	movq #8, r0
	ret
.LBB1_5:
	cbeq r1, #50, .LBB1_16
; %bb.6:
	cbne r1, #1000, .LBB1_18
; %bb.7:
	movq #6, r0
	ret
.LBB1_12:
	movq #1, r0
	movq =4294867296, r2
	cbeq r1, r2, .LBB1_19
; %bb.13:
	movq =4294967289, r0
	cbne r1, r0, .LBB1_18
; %bb.14:
	movq #2, r0
	ret
.LBB1_15:
	movq #3, r0
	ret
.LBB1_17:
	movq #7, r0
	ret
.LBB1_16:
	movq #5, r0
	ret
.LBB1_18:
	clr r0
.LBB1_19:
	ret
                                        ; -- End function
	.globl	fall                            ; -- Begin function fall
	.align	2
fall:                                   ; @fall
; %bb.0:
	lea -1(r0), r0
	movzl r0, r1
	clr r0
	cbhi r1, #8, .LBB2_2
; %bb.1:
	lea .Lswitch.table.fall, r0
	movl 0(r0)(r1*4), r0
.LBB2_2:
	movl r0, r0
	ret
                                        ; -- End function
	.globl	u32                             ; -- Begin function u32
	.align	2
u32:                                    ; @u32
; %bb.0:
	movzl r0, r1
	cbhi r1, #8, .LBB3_1
; %bb.12:
	movq #1, r0
	lea .LJTI3_0, r2
	movq 0(r2)(r1*8), r1
	jmp (r1)
.LBB3_4:
	movq #2, r0
	ret
.LBB3_1:
	movq =4000000000, r0
	cbeq r1, r0, .LBB3_7
; %bb.2:
	movq =4000000001, r0
	cbne r1, r0, .LBB3_10
; %bb.3:
	movq #6, r0
	ret
.LBB3_10:
	clr r0
.LBB3_11:
	ret
.LBB3_6:
	movq #4, r0
	ret
.LBB3_8:
	movq #7, r0
	ret
.LBB3_5:
	movq #3, r0
	ret
.LBB3_9:
	movq #8, r0
	ret
.LBB3_7:
	movq #5, r0
	ret
	.data
	.align	8
.LJTI3_0:
	.quad	.LBB3_11
	.quad	.LBB3_4
	.quad	.LBB3_5
	.quad	.LBB3_6
	.quad	.LBB3_10
	.quad	.LBB3_10
	.quad	.LBB3_10
	.quad	.LBB3_8
	.quad	.LBB3_9
                                        ; -- End function
	.text
	.globl	l64                             ; -- Begin function l64
	.align	2
l64:                                    ; @l64
; %bb.0:
	movq =8999999999999, r1
	cbgt r0, r1, .LBB4_5
; %bb.1:
	lea 1(r0), r1
	cbhi r1, #9, .LBB4_2
; %bb.4:
	lea .LJTI4_0, r0
	movq 0(r0)(r1*8), r0
	jmp (r0)
.LBB4_8:
	movq #2, r0
	ret
.LBB4_5:
	movq =9000000000000, r1
	cbeq r0, r1, .LBB4_14
; %bb.6:
	movq =9000000000001, r1
	cbne r0, r1, .LBB4_3
; %bb.7:
	movq #9, r0
	ret
.LBB4_2:
	movq r0, r1
	movq #1, r0
	movq =-9000000000000, r2
	cbne r1, r2, .LBB4_3
; %bb.15:
	ret
.LBB4_3:
	clr r0
	ret
.LBB4_12:
	movq #6, r0
	ret
.LBB4_10:
	movq #4, r0
	ret
.LBB4_11:
	movq #5, r0
	ret
.LBB4_9:
	movq #3, r0
	ret
.LBB4_13:
	movq #7, r0
	ret
.LBB4_14:
	movq #8, r0
	ret
	.data
	.align	8
.LJTI4_0:
	.quad	.LBB4_8
	.quad	.LBB4_9
	.quad	.LBB4_3
	.quad	.LBB4_3
	.quad	.LBB4_3
	.quad	.LBB4_3
	.quad	.LBB4_10
	.quad	.LBB4_11
	.quad	.LBB4_12
	.quad	.LBB4_13
                                        ; -- End function
	.text
	.globl	"ch"                            ; -- Begin function ch
	.align	2
"ch":                                   ; @ch
; %bb.0:
	lea -97(r0), r1
	cbhi r1, #24, .LBB5_1
; %bb.3:
	movq #1, r0
	lea .LJTI5_0, r2
	movq 0(r2)(r1*8), r1
	jmp (r1)
.LBB5_4:
	movq #2, r0
	ret
.LBB5_1:
	cbne r0, #32, .LBB5_9
; %bb.2:
	movq #7, r0
	ret
.LBB5_9:
	clr r0
.LBB5_10:
	ret
.LBB5_5:
	movq #3, r0
	ret
.LBB5_8:
	movq #6, r0
	ret
.LBB5_6:
	movq #4, r0
	ret
.LBB5_7:
	movq #5, r0
	ret
	.data
	.align	8
.LJTI5_0:
	.quad	.LBB5_10
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_4
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_5
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_6
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_7
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_9
	.quad	.LBB5_8
                                        ; -- End function
	.text
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	movq =4294967294, r1
.LBB6_1:                                ; =>This Inner Loop Header: Depth=1
	lea 1(r1), r1
	movzl r1, r2
	cbne r2, #13, .LBB6_1
; %bb.2:
	movl r0, r0
	ret
                                        ; -- End function
	.data
	.align	4                               ; @switch.table.fall
.Lswitch.table.fall:
	.long	7                               ; 0x7
	.long	6                               ; 0x6
	.long	4                               ; 0x4
	.long	24                              ; 0x18
	.long	16                              ; 0x10
	.long	32                              ; 0x20
	.long	32                              ; 0x20
	.long	32                              ; 0x20
	.long	99                              ; 0x63

