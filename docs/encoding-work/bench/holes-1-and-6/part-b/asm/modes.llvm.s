	.text
	.globl	inc1                            ; -- Begin function inc1
	.align	2
inc1:                                   ; @inc1
; %bb.0:
	movq 0(r0), r1
	lea 1(r1), r1
	movq r1, 0(r0)
	ret
                                        ; -- End function
	.globl	dec1                            ; -- Begin function dec1
	.align	2
dec1:                                   ; @dec1
; %bb.0:
	movq 0(r0), r1
	lea -1(r1), r1
	movq r1, 0(r0)
	ret
                                        ; -- End function
	.globl	neg1                            ; -- Begin function neg1
	.align	2
neg1:                                   ; @neg1
; %bb.0:
	movq 0(r0), r1
	neg r1
	movq r1, 0(r0)
	ret
                                        ; -- End function
	.globl	com1                            ; -- Begin function com1
	.align	2
com1:                                   ; @com1
; %bb.0:
	movq 0(r0), r1
	com r1
	movq r1, 0(r0)
	ret
                                        ; -- End function
	.globl	add2                            ; -- Begin function add2
	.align	2
add2:                                   ; @add2
; %bb.0:
	movq 0(r0), r2
	add r1, r2
	movq r2, 0(r0)
	ret
                                        ; -- End function
	.globl	sub2                            ; -- Begin function sub2
	.align	2
sub2:                                   ; @sub2
; %bb.0:
	movq 0(r0), r2
	sub r1, r2
	movq r2, 0(r0)
	ret
                                        ; -- End function
	.globl	or2                             ; -- Begin function or2
	.align	2
or2:                                    ; @or2
; %bb.0:
	movq 0(r0), r2
	bis r1, r2
	movq r2, 0(r0)
	ret
                                        ; -- End function
	.globl	clr2                            ; -- Begin function clr2
	.align	2
clr2:                                   ; @clr2
; %bb.0:
	movq 0(r0), r2
	bic r1, r2
	movq r2, 0(r0)
	ret
                                        ; -- End function
	.globl	idx                             ; -- Begin function idx
	.align	2
idx:                                    ; @idx
; %bb.0:
	lea 0(r0)(r1*8), r3
	movq 0(r0)(r1*8), r4
	add r2, r4
	movq r4, 0(r0)(r1*8)
	movq 8(r3), r0
	lea 1(r0), r0
	movq r0, 8(r3)
	ret
                                        ; -- End function
	.globl	incg                            ; -- Begin function incg
	.align	2
incg:                                   ; @incg
; %bb.0:
	lea g, r0
	movq 0(r0), r1
	lea 1(r1), r1
	movq r1, 0(r0)
	lea gi, r0
	movl 0(r0), r1
	lea 1(r1), r1
	movl r1, 0(r0)
	lea gs, r0
	movw 0(r0), r1
	lea 1(r1), r1
	movw r1, 0(r0)
	lea gc, r0
	movb 0(r0), r1
	lea 1(r1), r1
	movb r1, 0(r0)
	ret
                                        ; -- End function
	.globl	flds                            ; -- Begin function flds
	.align	2
flds:                                   ; @flds
; %bb.0:
	movq 0(r0), r2
	add r1, r2
	movq r2, 0(r0)
	movq 8(r0), r2
	sub r1, r2
	movq r2, 8(r0)
	movl 16(r0), r2
	lea 3(r2), r2
	movl r2, 16(r0)
	movq 40(r0), r2
	bis r1, r2
	movq r2, 40(r0)
	movq 32(r0), r1
	lea -1(r1), r1
	movq r1, 32(r0)
	ret
                                        ; -- End function
	.globl	andn                            ; -- Begin function andn
	.align	2
andn:                                   ; @andn
; %bb.0:
	bic r1, r0
	ret
                                        ; -- End function
	.globl	andn2                           ; -- Begin function andn2
	.align	2
andn2:                                  ; @andn2
; %bb.0:
	xor r1, r0
	ret
                                        ; -- End function
	.globl	andn3                           ; -- Begin function andn3
	.align	2
andn3:                                  ; @andn3
; %bb.0:
	bic r1, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	loop1                           ; -- Begin function loop1
	.align	2
loop1:                                  ; @loop1
; %bb.0:
	lea -1(r0), r1
	lea -2(r0), r2
	movq r1, r3
	mul r2, r3
	mulhu r1, r2, r2
	shl #63, r2
	shr #1, r3
	bis r2, r3
	mul r1, r1
	add r1, r0
	sub r3, r0
	ret
                                        ; -- End function
	.globl	loop2                           ; -- Begin function loop2
	.align	2
loop2:                                  ; @loop2
; %bb.0:
	movq r0, r2
	clr r0
.LBB15_1:                               ; =>This Inner Loop Header: Depth=1
	lea 0(r1)(r2*8), r3
	movq -8(r3), r3
	add r3, r0
	lea -1(r2), r2
	cbne r2, #0, .LBB15_1
; %bb.2:
	ret
                                        ; -- End function
	.globl	loop3                           ; -- Begin function loop3
	.align	2
loop3:                                  ; @loop3
; %bb.0:
	ret
                                        ; -- End function
	.globl	loop4                           ; -- Begin function loop4
	.align	2
loop4:                                  ; @loop4
; %bb.0:
	movq r0, r2
	cblt r0, #1, .LBB17_2
; %bb.1:
	movq #1, r2
.LBB17_2:
	movq r2, r3
	com r3
	add r0, r3
	sub r2, r0
	mulhu r3, r0, r2
	mul r0, r3
	shl #63, r2
	shr #1, r3
	bis r2, r3
	lea 1(r1), r2
	mul r0, r2
	add r1, r2
	add r3, r2
	movq r2, r0
	ret
                                        ; -- End function
	.globl	loop5                           ; -- Begin function loop5
	.align	2
loop5:                                  ; @loop5
; %bb.0:
	lea -1(r0), r0
	movzl r0, r0
	shl #1, r0
	lea 2(r0), r0
	ret
                                        ; -- End function
	.globl	w1                              ; -- Begin function w1
	.align	2
w1:                                     ; @w1
; %bb.0:
	cbeq r2, #0, .LBB19_1
; %bb.2:                                ; %.preheader
	movq r2, r3
.LBB19_3:                               ; =>This Inner Loop Header: Depth=1
	lea -1(r3), r3
	movb (r1)+, r4
	movb r4, (r0)+
	cbne r3, #0, .LBB19_3
; %bb.4:
	movq r2, r0
	ret
.LBB19_1:
	clr r2
	movq r2, r0
	ret
                                        ; -- End function
	.globl	w2                              ; -- Begin function w2
	.align	2
w2:                                     ; @w2
; %bb.0:
	movq r0, r2
	cbeq r2, #0, .LBB20_1
; %bb.2:                                ; %.preheader
	clr r0
	br .LBB20_3
.LBB20_5:                               ;   in Loop: Header=BB20_3 Depth=1
	lea -1(r2), r2
	add r3, r0
	cbeq r2, #0, .LBB20_6
.LBB20_3:                               ; =>This Inner Loop Header: Depth=1
	movq (r1)+, r4
	movq #1, r3
	cbne r4, #3, .LBB20_5
; %bb.4:                                ;   in Loop: Header=BB20_3 Depth=1
	clr r3
	br .LBB20_5
.LBB20_6:
	ret
.LBB20_1:
	clr r0
	ret
                                        ; -- End function
	.globl	w3                              ; -- Begin function w3
	.align	2
w3:                                     ; @w3
; %bb.0:
	cbeq r0, #0, .LBB21_1
; %bb.2:
	lea -1(r0), r0
	cbcs r0, #3, .LBB21_4
; %bb.3:
	movq #3, r0
.LBB21_4:
	lea 1(r0), r0
	ret
.LBB21_1:
	clr r0
	ret
                                        ; -- End function
	.globl	w4                              ; -- Begin function w4
	.align	2
w4:                                     ; @w4
; %bb.0:
	cbeq r0, #0, .LBB22_1
; %bb.2:
	lea -1(r0), r1
	lea -2(r0), r2
	mulhu r1, r2, r3
	shl #63, r3
	mul r2, r1
	movq r0, r2
	movq r1, r0
	shr #1, r0
	bis r3, r0
	add r2, r1
	com r0
	add r1, r0
	ret
.LBB22_1:
	clr r0
	ret
                                        ; -- End function
	.globl	w5                              ; -- Begin function w5
	.align	2
w5:                                     ; @w5
; %bb.0:
	lea -1(r0), r0
	ret
                                        ; -- End function
	.globl	w6                              ; -- Begin function w6
	.align	2
w6:                                     ; @w6
; %bb.0:
	movq r0, r1
	cbcs r1, #10, .LBB24_2
; %bb.1:
	movq #10, r0
.LBB24_2:
	shl #1, r0
	lea 1(r1), r2
	movq #-2, r1
.LBB24_3:                               ; =>This Inner Loop Header: Depth=1
	lea -1(r2), r2
	cbeq r2, #0, .LBB24_6
; %bb.4:                                ;   in Loop: Header=BB24_3 Depth=1
	lea 2(r1), r1
	cbcs r1, #19, .LBB24_3
; %bb.5:                                ; %._crit_edge
	lea 2(r1), r0
.LBB24_6:
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	push fp
	movq sp, fp
	sub #16, sp
	movq r14, r0
	lea -48(r0), r3
	and #-16, r3
	movq r3, r14
	movq r14, r0
	lea -40(r0), r0
	and #-16, r0
	movq r0, r14
	movq r3, r1
	bis #8, r1
	movq #1, r2
	movq r2, 0(r3)
	movq #2, r2
	movq r2, 0(r1)
	movq #5, r1
	movq r1, 32(r3)
	movq #6, r4
	movq r4, 40(r3)
	movq #13, r4
	movq r4, 16(r3)
	movq r1, 24(r3)
	lea g, r4
	lea gi, r5
	lea gs, r6
	lea gc, r7
	movq r2, 0(r4)
	clr r2
	movl r2, 0(r5)
	movq #32768, r4
	movw r4, 0(r6)
	movq #128, r4
	movb r4, 0(r7)
	movq #5, r4
.LBB25_1:                               ; =>This Inner Loop Header: Depth=1
	movq 0(r3)(r4*8), r5
	add r5, r2
	lea -1(r4), r4
	cbne r4, #-1, .LBB25_1
; %bb.2:
	movq =29104508263162465, r3
	movq r3, -8(r13)
	movq #1, r3
	movq r3, 0(r0)
	movq #3, r3
	movq r3, 8(r0)
	movq r3, 16(r0)
	movq #4, r3
	movq r3, 24(r0)
	movq #5, r3
	movq r3, 32(r0)
	clr r3
	lea -8(r13), r4
	lea -16(r13), r5
.LBB25_3:                               ; =>This Inner Loop Header: Depth=1
	movq r4, r6
	add r3, r6
	movq r5, r7
	add r3, r7
	movb 0(r6), r6
	movb r6, 0(r7)
	lea 1(r3), r3
	cbne r3, #7, .LBB25_3
; %bb.4:
	movb -10(r13), r4
	clr r6
	movb -16(r13), r5
	clr r3
	br .LBB25_5
.LBB25_7:                               ;   in Loop: Header=BB25_5 Depth=1
	add r7, r3
	lea 1(r6), r6
	cbeq r6, #5, .LBB25_8
.LBB25_5:                               ; =>This Inner Loop Header: Depth=1
	movq 0(r0)(r6*8), r16
	movq #1, r7
	cbne r16, #3, .LBB25_7
; %bb.6:                                ;   in Loop: Header=BB25_5 Depth=1
	clr r7
	br .LBB25_7
.LBB25_8:
	clr r0
	cbeq r1, #5, .LBB25_10
; %bb.9:
	movq #256, r0
.LBB25_10:
	movzb r5, r5
	cbeq r2, #32, .LBB25_12
; %bb.11:
	bis #8192, r0
.LBB25_12:
	movzb r4, r2
	movq r0, r1
	bis #131072, r1
	movq r1, r4
	cbeq r5, #97, .LBB25_13
; %bb.14:
	cbeq r2, #103, .LBB25_15
.LBB25_16:
	cbeq r3, #3, .LBB25_18
.LBB25_17:
	bis #262144, r1
.LBB25_18:
	movl r1, r0
	movq fp, sp
	pop fp
	ret
.LBB25_13:
	movq r0, r4
	cbne r2, #103, .LBB25_16
.LBB25_15:
	movq r4, r1
	cbne r3, #3, .LBB25_17
	br .LBB25_18
                                        ; -- End function
	.bss
	.globl	g                               ; @g
	.align	8
g:
	.quad	0                               ; 0x0

	.globl	gi                              ; @gi
	.align	4
gi:
	.long	0                               ; 0x0

	.globl	gs                              ; @gs
	.align	2
gs:
	.word	0                               ; 0x0

	.globl	gc                              ; @gc
gc:
	.byte	0                               ; 0x0

	.globl	rr                              ; @rr
	.align	8
rr:
	.space	56

