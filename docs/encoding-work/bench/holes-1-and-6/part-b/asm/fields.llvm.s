	.text
	.globl	fb                              ; -- Begin function fb
	.align	2
fb:                                     ; @fb
; %bb.0:
	movl 0(r0), r0
	shr #3, r0
	and #31, r0
	ret
                                        ; -- End function
	.globl	fc                              ; -- Begin function fc
	.align	2
fc:                                     ; @fc
; %bb.0:
	movl 0(r0), r0
	shr #8, r0
	and #511, r0
	ret
                                        ; -- End function
	.globl	fd                              ; -- Begin function fd
	.align	2
fd:                                     ; @fd
; %bb.0:
	movzl 0(r0), r0
	shl #43, r0
	sar #60, r0
	ret
                                        ; -- End function
	.globl	ff                              ; -- Begin function ff
	.align	2
ff:                                     ; @ff
; %bb.0:
	movzl 4(r0), r0
	shl #59, r0
	sar #59, r0
	ret
                                        ; -- End function
	.globl	fe                              ; -- Begin function fe
	.align	2
fe:                                     ; @fe
; %bb.0:
	movl 0(r0), r0
	shr #21, r0
	and #127, r0
	ret
                                        ; -- End function
	.globl	sb                              ; -- Begin function sb
	.align	2
sb:                                     ; @sb
; %bb.0:
	movzl 0(r0), r2
	shl #3, r1
	and #248, r1
	movq =4294967047, r3
	and r2, r3
	bis r1, r3
	movl r3, 0(r0)
	ret
                                        ; -- End function
	.globl	sc                              ; -- Begin function sc
	.align	2
sc:                                     ; @sc
; %bb.0:
	movzl 0(r0), r2
	shl #8, r1
	and #130816, r1
	movq =4294836479, r3
	and r2, r3
	bis r1, r3
	movl r3, 0(r0)
	ret
                                        ; -- End function
	.globl	sd                              ; -- Begin function sd
	.align	2
sd:                                     ; @sd
; %bb.0:
	movzl 0(r0), r2
	shl #17, r1
	and #1966080, r1
	movq =4293001215, r3
	and r2, r3
	bis r1, r3
	movl r3, 0(r0)
	ret
                                        ; -- End function
	.globl	sf                              ; -- Begin function sf
	.align	2
sf:                                     ; @sf
; %bb.0:
	movzl 4(r0), r2
	shl #32, r2
	and #31, r1
	shl #32, r1
	movq =-137438953472, r3
	and r2, r3
	bis r1, r3
	shr #32, r3
	movl r3, 4(r0)
	ret
                                        ; -- End function
	.globl	sa                              ; -- Begin function sa
	.align	2
sa:                                     ; @sa
; %bb.0:
	movzl 0(r0), r2
	and #7, r1
	movq =4294967288, r3
	and r2, r3
	bis r1, r3
	movl r3, 0(r0)
	ret
                                        ; -- End function
	.globl	qb                              ; -- Begin function qb
	.align	2
qb:                                     ; @qb
; %bb.0:
	movq 0(r0), r1
	shr #5, r1
	movq =1099511627775, r0
	and r1, r0
	ret
                                        ; -- End function
	.globl	qd                              ; -- Begin function qd
	.align	2
qd:                                     ; @qd
; %bb.0:
	movb 8(r0), r0
	ret
                                        ; -- End function
	.globl	qsb                             ; -- Begin function qsb
	.align	2
qsb:                                    ; @qsb
; %bb.0:
	movq 0(r0), r2
	shl #5, r1
	movq =35184372088800, r3
	and r1, r3
	movq =-35184372088801, r1
	and r2, r1
	bis r3, r1
	movq r1, 0(r0)
	ret
                                        ; -- End function
	.globl	qsc                             ; -- Begin function qsc
	.align	2
qsc:                                    ; @qsc
; %bb.0:
	movq 0(r0), r2
	shl #45, r1
	movq =35184372088831, r3
	and r2, r3
	bis r1, r3
	movq r3, 0(r0)
	ret
                                        ; -- End function
	.globl	qsd                             ; -- Begin function qsd
	.align	2
qsd:                                    ; @qsd
; %bb.0:
	movb r1, 8(r0)
	ret
                                        ; -- End function
	.globl	ex                              ; -- Begin function ex
	.align	2
ex:                                     ; @ex
; %bb.0:
	shr #3, r0
	and #31, r0
	ret
                                        ; -- End function
	.globl	ex2                             ; -- Begin function ex2
	.align	2
ex2:                                    ; @ex2
; %bb.0:
	shr #11, r0
	and #4095, r0
	ret
                                        ; -- End function
	.globl	ex3                             ; -- Begin function ex3
	.align	2
ex3:                                    ; @ex3
; %bb.0:
	shr #5, r0
	movq =36028797018963967, r1
	and r1, r0
	ret
                                        ; -- End function
	.globl	ex4                             ; -- Begin function ex4
	.align	2
ex4:                                    ; @ex4
; %bb.0:
	shl #4, r0
	sar #9, r0
	ret
                                        ; -- End function
	.globl	ex5                             ; -- Begin function ex5
	.align	2
ex5:                                    ; @ex5
; %bb.0:
	shr #23, r0
	and #15, r0
	ret
                                        ; -- End function
	.globl	ex6                             ; -- Begin function ex6
	.align	2
ex6:                                    ; @ex6
; %bb.0:
	shl #5, r0
	movl r0, r0
	sar #28, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	ret
                                        ; -- End function
