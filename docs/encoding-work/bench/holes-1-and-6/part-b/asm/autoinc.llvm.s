	.text
	.globl	cpy                             ; -- Begin function cpy
	.align	2
cpy:                                    ; @cpy
; %bb.0:
	cbeq r2, #0, .LBB0_2
.LBB0_1:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r2), r2
	movb (r1)+, r3
	movb r3, (r0)+
	cbne r2, #0, .LBB0_1
.LBB0_2:
	ret
                                        ; -- End function
	.globl	len                             ; -- Begin function len
	.align	2
len:                                    ; @len
; %bb.0:
	lea -1(r0), r2
.LBB1_1:                                ; =>This Inner Loop Header: Depth=1
	lea 1(r2), r1
	movzb 1(r2), r3
	movq r1, r2
	cbne r3, #0, .LBB1_1
; %bb.2:
	sub r0, r1
	movq r1, r0
	ret
                                        ; -- End function
	.globl	cpyz                            ; -- Begin function cpyz
	.align	2
cpyz:                                   ; @cpyz
; %bb.0:
.LBB2_1:                                ; =>This Inner Loop Header: Depth=1
	movzb (r1)+, r2
	movb r2, (r0)+
	cbne r2, #0, .LBB2_1
; %bb.2:
	ret
                                        ; -- End function
	.globl	sumi                            ; -- Begin function sumi
	.align	2
sumi:                                   ; @sumi
; %bb.0:
	movq r0, r2
	clr r0
	cbeq r1, #0, .LBB3_2
.LBB3_1:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r1), r1
	movl (r2)+, r3
	add r3, r0
	cbne r1, #0, .LBB3_1
.LBB3_2:
	ret
                                        ; -- End function
	.globl	sums                            ; -- Begin function sums
	.align	2
sums:                                   ; @sums
; %bb.0:
	movq r0, r2
	clr r0
	cblt r1, #1, .LBB4_2
.LBB4_1:                                ; =>This Inner Loop Header: Depth=1
	movw (r2)+, r3
	add r3, r0
	lea -1(r1), r1
	cbne r1, #0, .LBB4_1
.LBB4_2:
	ret
                                        ; -- End function
	.globl	suml                            ; -- Begin function suml
	.align	2
suml:                                   ; @suml
; %bb.0:
	movq r0, r2
	clr r0
	cblt r1, #1, .LBB5_2
.LBB5_1:                                ; =>This Inner Loop Header: Depth=1
	movq (r2)+, r3
	add r3, r0
	lea -1(r1), r1
	cbne r1, #0, .LBB5_1
.LBB5_2:
	ret
                                        ; -- End function
	.globl	sumr                            ; -- Begin function sumr
	.align	2
sumr:                                   ; @sumr
; %bb.0:
	movq r0, r2
	clr r0
	cbeq r1, #0, .LBB6_2
.LBB6_1:                                ; =>This Inner Loop Header: Depth=1
	lea -1(r1), r3
	lea 0(r2)(r1*4), r1
	movl -4(r1), r1
	add r1, r0
	movq r3, r1
	cbne r3, #0, .LBB6_1
.LBB6_2:
	ret
                                        ; -- End function
	.globl	sumst                           ; -- Begin function sumst
	.align	2
sumst:                                  ; @sumst
; %bb.0:
	cblt r1, #1, .LBB7_1
; %bb.2:                                ; %.preheader
	lea 4(r0), r2
	clr r0
.LBB7_3:                                ; =>This Inner Loop Header: Depth=1
	movl 0(r2), r3
	add r3, r0
	lea -1(r1), r1
	lea 12(r2), r2
	cbne r1, #0, .LBB7_3
; %bb.4:
	ret
.LBB7_1:
	clr r0
	ret
                                        ; -- End function
	.globl	sums3                           ; -- Begin function sums3
	.align	2
sums3:                                  ; @sums3
; %bb.0:
	movq r0, r2
	clr r0
	cblt r1, #1, .LBB8_2
.LBB8_1:                                ; =>This Inner Loop Header: Depth=1
	movb 0(r2), r3
	add r3, r0
	lea 3(r2), r2
	lea -1(r1), r1
	cbne r1, #0, .LBB8_1
.LBB8_2:
	ret
                                        ; -- End function
	.globl	after                           ; -- Begin function after
	.align	2
after:                                  ; @after
; %bb.0:
	movb (r0)+, r2
	movb r2, 0(r1)
	ret
                                        ; -- End function
	.globl	both                            ; -- Begin function both
	.align	2
both:                                   ; @both
; %bb.0:
	movl 0(r0), r1
	movl 4(r0), r2
	mul #10, r1
	add r2, r1
	movl 8(r0), r0
	add r1, r0
	ret
                                        ; -- End function
	.globl	rev                             ; -- Begin function rev
	.align	2
rev:                                    ; @rev
; %bb.0:
	cbeq r2, #0, .LBB11_2
.LBB11_1:                               ; =>This Inner Loop Header: Depth=1
	lea -1(r2), r3
	add r1, r2
	movb -1(r2), r2
	movb r2, (r0)+
	movq r3, r2
	cbne r3, #0, .LBB11_1
.LBB11_2:
	ret
                                        ; -- End function
	.globl	ubytes                          ; -- Begin function ubytes
	.align	2
ubytes:                                 ; @ubytes
; %bb.0:
	movzb 0(r0), r3
	shl #8, r3
	lea 2(r0), r2
	movzb 1(r0), r0
	bis r3, r0
	movq r0, 0(r1)
	movq r2, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #8, sp
	movq r14, r0
	lea -16(r0), r1
	and #-16, r1
	movq r1, r14
	movq r14, r0
	lea -16(r0), r0
	and #-16, r0
	movq r0, r14
	movq =11259127918755850, r2
	movq r2, -8(r13)
	movq #1, r2
.LBB13_1:                               ; =>This Inner Loop Header: Depth=1
	movq r1, r3
	add r2, r3
	movb r2, -1(r3)
	lea 1(r2), r2
	cbne r2, #17, .LBB13_1
; %bb.2:                                ; %.preheader2
	clr r2
.LBB13_3:                               ; =>This Inner Loop Header: Depth=1
	movb 0(r1)(r2*1), r3
	movb r3, 0(r0)(r2*1)
	lea 1(r2), r2
	cbne r2, #16, .LBB13_3
; %bb.4:                                ; %.preheader1
	clr r2
	movq #1, r3
	br .LBB13_5
.LBB13_7:                               ;   in Loop: Header=BB13_5 Depth=1
	lea 1(r3), r3
	cbeq r3, #17, .LBB13_8
.LBB13_5:                               ; =>This Inner Loop Header: Depth=1
	movq r0, r4
	add r3, r4
	movb -1(r4), r4
	movzl r4, r4
	cbeq r3, r4, .LBB13_7
; %bb.6:                                ;   in Loop: Header=BB13_5 Depth=1
	movq #1, r2
	br .LBB13_7
.LBB13_8:                               ; %.preheader
	clr r4
	lea .L.str.1, r3
.LBB13_9:                               ; =>This Inner Loop Header: Depth=1
	movb 0(r4)(r3*1), r5
	lea 1(r4), r6
	movb r5, 0(r0)(r4*1)
	movq r6, r4
	cbne r6, #4, .LBB13_9
; %bb.10:
	movb 0(r0), r4
	movb 2(r0), r6
	movb 3(r0), r7
	clr r5
	lea -8(r13), r16
	clr r3
.LBB13_11:                              ; =>This Inner Loop Header: Depth=1
	lea 0(r16)(r5*2), r17
	movw 0(r17), r17
	add r17, r3
	lea 1(r5), r5
	cbne r5, #4, .LBB13_11
; %bb.12:
	movb 0(r1), r5
	movb r5, 0(r0)
	movq #5, r17
	movq r0, r16
.LBB13_13:                              ; =>This Inner Loop Header: Depth=1
	lea -1(r17), r18
	add r1, r17
	movb -1(r17), r17
	movb r17, (r16)+
	movq r18, r17
	cbne r18, #0, .LBB13_13
; %bb.14:
	movzb r6, r6
	movzb r7, r16
	movq r2, r1
	bis #4, r1
	movq r1, r7
	cbne r16, #0, .LBB13_16
; %bb.15:
	movq r2, r7
.LBB13_16:
	movzb r4, r2
	movq r1, r4
	cbeq r6, #99, .LBB13_17
; %bb.18:
	cbeq r2, #97, .LBB13_19
.LBB13_20:
	movzb r5, r2
	cbne r3, #100, .LBB13_21
.LBB13_22:
	cbeq r2, #1, .LBB13_24
.LBB13_23:
	bis #512, r1
.LBB13_24:
	movzb 0(r0), r2
	movb 4(r0), r0
	movzb r0, r4
	movq r1, r0
	bis #2048, r0
	movq r0, r3
	cbne r4, #1, .LBB13_26
; %bb.25:
	movq r1, r3
.LBB13_26:
	cbne r2, #5, .LBB13_28
; %bb.27:
	movq r3, r0
.LBB13_28:
	movl r0, r0
	movq fp, sp
	pop fp
	ret
.LBB13_17:
	movq r7, r4
	cbne r2, #97, .LBB13_20
.LBB13_19:
	movq r4, r1
	movzb r5, r2
	cbeq r3, #100, .LBB13_22
.LBB13_21:
	bis #16, r1
	cbne r2, #1, .LBB13_23
	br .LBB13_24
                                        ; -- End function
	.data
.L.str.1:                               ; @.str.1
	.ascii	"abc\000"

