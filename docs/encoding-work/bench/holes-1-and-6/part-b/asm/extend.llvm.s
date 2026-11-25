	.text
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #16, sp
	movq =4294967295, r0
	movl r0, -4(r13)
	movl r0, -8(r13)
	movq #255, r0
	movb r0, -9(r13)
	movb r0, -10(r13)
	movq #65534, r0
	movw r0, -12(r13)
	lea ub, r0
	movzb 0(r0), r1
	movq #2, r0
	cbne r1, #128, .LBB0_28
; %bb.1:
	lea sb, r0
	movzb 0(r0), r1
	movq #3, r0
	cbne r1, #128, .LBB0_28
; %bb.2:
	lea ss, r0
	movzw 0(r0), r2
	movq #4, r0
	movq #32768, r1
	cbne r2, r1, .LBB0_28
; %bb.3:
	lea us, r0
	movzw 0(r0), r2
	movq #5, r0
	cbne r2, r1, .LBB0_28
; %bb.4:
	lea is, r0
	movl 0(r0), r1
	movq #6, r0
	movq #-2147483648, r2
	cbne r1, r2, .LBB0_28
; %bb.5:
	lea un, r0
	movzl 0(r0), r2
	movq #7, r0
	movq =2147483648, r3
	cbne r2, r3, .LBB0_28
; %bb.6:
	movzb -9(r13), r3
	movq #8, r0
	cbne r3, #255, .LBB0_28
; %bb.7:
	movzb -9(r13), r3
	movq #9, r0
	cbne r3, #255, .LBB0_28
; %bb.8:
	movzl -4(r13), r4
	movq #10, r0
	movq =4294967295, r3
	cbne r4, r3, .LBB0_28
; %bb.9:
	movzl -8(r13), r4
	movq #11, r0
	cbne r4, r3, .LBB0_28
; %bb.10:
	movzl -4(r13), r0
	movzb r0, r3
	movq #12, r0
	cbne r3, #255, .LBB0_28
; %bb.11:
	movzl -4(r13), r0
	movzw r0, r3
	movq #13, r0
	movq #65535, r4
	cbne r3, r4, .LBB0_28
; %bb.12:
	movl -4(r13), r0
	movl -4(r13), r3
	movq #23, r0
	cble r3, #-1, .LBB0_13
.LBB0_28:
	movl r0, r0
	movq fp, sp
	pop fp
	ret
.LBB0_13:
	movzb -10(r13), r0
	cbeq r0, #0, .LBB0_14
; %bb.15:
	movb -9(r13), r3
	movq #25, r0
	cbgt r3, #-1, .LBB0_28
; %bb.16:
	movzl -8(r13), r0
	cbeq r0, #0, .LBB0_17
; %bb.18:
	lea is+4, r0
	movl 0(r0), r3
	movq #27, r0
	cbge r1, r3, .LBB0_28
; %bb.19:
	lea un+4, r0
	movzl 0(r0), r1
	movq #28, r0
	cbcc r2, r1, .LBB0_28
; %bb.20:
	movl -4(r13), r0
	lea 1(r0), r0
	movzl r0, r1
	movq #32, r0
	cbhi r1, #2, .LBB0_28
; %bb.21:
	movzl -8(r13), r1
	movq #34, r0
	movq =4294967294, r2
	cbcs r1, r2, .LBB0_28
; %bb.22:
	movw -12(r13), r0
	movw -12(r13), r1
	mul r0, r1
	movq #35, r0
	cbne r1, #4, .LBB0_28
; %bb.23:
	movzw -12(r13), r1
	movq #36, r0
	movq #65534, r2
	cbne r1, r2, .LBB0_28
; %bb.24:
	movzl -4(r13), r1
	movq #37, r0
	movq =4294967295, r2
	cbne r1, r2, .LBB0_28
; %bb.25:
	movzb -9(r13), r1
	movq #38, r0
	cbne r1, #255, .LBB0_28
; %bb.26:
	movzb -10(r13), r1
	movq #1, r0
	cbeq r1, #255, .LBB0_28
; %bb.27:
	movq #39, r0
	br .LBB0_28
.LBB0_14:
	movq #24, r0
	br .LBB0_28
.LBB0_17:
	movq #26, r0
	br .LBB0_28
                                        ; -- End function
	.data
	.globl	ub                              ; @ub
ub:
	.ascii	"\200\377"

	.globl	sb                              ; @sb
sb:
	.ascii	"\200\377"

	.globl	ss                              ; @ss
	.align	2
ss:
	.word	32768                           ; 0x8000
	.word	65535                           ; 0xffff

	.globl	us                              ; @us
	.align	2
us:
	.word	32768                           ; 0x8000
	.word	65535                           ; 0xffff

	.globl	is                              ; @is
	.align	4
is:
	.long	2147483648                      ; 0x80000000
	.long	4294967295                      ; 0xffffffff

	.globl	un                              ; @un
	.align	4
un:
	.long	2147483648                      ; 0x80000000
	.long	4294967295                      ; 0xffffffff

