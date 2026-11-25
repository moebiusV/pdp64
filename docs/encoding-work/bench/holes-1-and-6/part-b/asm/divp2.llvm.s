	.text
	.globl	d2                              ; -- Begin function d2
	.align	2
d2:                                     ; @d2
; %bb.0:
	movq =2147483648, r1
	and r0, r1
	shr #31, r1
	add r0, r1
	movl r1, r0
	sar #1, r0
	ret
                                        ; -- End function
	.globl	d8                              ; -- Begin function d8
	.align	2
d8:                                     ; @d8
; %bb.0:
	movl r0, r1
	shr #60, r1
	and #7, r1
	add r0, r1
	movl r1, r0
	sar #3, r0
	ret
                                        ; -- End function
	.globl	m8                              ; -- Begin function m8
	.align	2
m8:                                     ; @m8
; %bb.0:
	movl r0, r1
	shr #60, r1
	and #7, r1
	add r0, r1
	movq =4294967288, r2
	and r1, r2
	sub r2, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	m2                              ; -- Begin function m2
	.align	2
m2:                                     ; @m2
; %bb.0:
	movq =2147483648, r1
	and r0, r1
	shr #31, r1
	add r0, r1
	movq =4294967294, r2
	and r1, r2
	sub r2, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	ld4                             ; -- Begin function ld4
	.align	2
ld4:                                    ; @ld4
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #62, r1
	add r1, r0
	sar #2, r0
	ret
                                        ; -- End function
	.globl	lm16                            ; -- Begin function lm16
	.align	2
lm16:                                   ; @lm16
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #60, r1
	add r0, r1
	and #-16, r1
	sub r1, r0
	ret
                                        ; -- End function
	.globl	ld1k                            ; -- Begin function ld1k
	.align	2
ld1k:                                   ; @ld1k
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #54, r1
	add r1, r0
	sar #10, r0
	ret
                                        ; -- End function
	.globl	lm1k                            ; -- Begin function lm1k
	.align	2
lm1k:                                   ; @lm1k
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #54, r1
	add r0, r1
	and #-1024, r1
	sub r1, r0
	ret
                                        ; -- End function
	.globl	ld1g                            ; -- Begin function ld1g
	.align	2
ld1g:                                   ; @ld1g
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #34, r1
	add r1, r0
	sar #30, r0
	ret
                                        ; -- End function
	.globl	sd8                             ; -- Begin function sd8
	.align	2
sd8:                                    ; @sd8
; %bb.0:
	movq r0, r1
	shr #28, r1
	and #7, r1
	add r0, r1
	movw r1, r0
	sar #3, r0
	ret
                                        ; -- End function
	.globl	cm4                             ; -- Begin function cm4
	.align	2
cm4:                                    ; @cm4
; %bb.0:
	movq =3221225472, r1
	and r0, r1
	shr #30, r1
	add r0, r1
	and #-4, r1
	sub r1, r0
	ret
                                        ; -- End function
	.globl	lld32                           ; -- Begin function lld32
	.align	2
lld32:                                  ; @lld32
; %bb.0:
	movq r0, r1
	sar #63, r1
	shr #59, r1
	add r1, r0
	sar #5, r0
	ret
                                        ; -- End function
	.globl	dnoreg                          ; -- Begin function dnoreg
	.align	2
dnoreg:                                 ; @dnoreg
; %bb.0:
	movl 0(r0), r0
	movq r0, r1
	shr #61, r1
	and #3, r1
	add r0, r1
	movl r1, r0
	sar #2, r0
	ret
                                        ; -- End function
	.globl	fsum                            ; -- Begin function fsum
	.align	2
fsum:                                   ; @fsum
; %bb.0:
	movl r0, r1
	cblt r1, #0, .LBB13_1
; %bb.2:
	clr r3
	movq =9223372036854775804, r1
	movzl r0, r2
	neg r0
.LBB13_3:                               ; =>This Inner Loop Header: Depth=1
	movzl r0, r5
	movl r0, r6
	shr #61, r6
	and #3, r6
	add r0, r6
	movl r6, r4
	sar #2, r4
	and r1, r6
	lea 1(r0), r7
	sub r6, r0
	mul #10, r0
	add r3, r4
	add r0, r4
	movq r7, r0
	movq r4, r3
	cbne r5, r2, .LBB13_3
; %bb.4:
	movl r4, r0
	ret
.LBB13_1:
	clr r4
	movl r4, r0
	ret
                                        ; -- End function
	.globl	pdi                             ; -- Begin function pdi
	.align	2
pdi:                                    ; @pdi
; %bb.0:
	sub r1, r0
	sar #2, r0
	ret
                                        ; -- End function
	.globl	pdl                             ; -- Begin function pdl
	.align	2
pdl:                                    ; @pdl
; %bb.0:
	sub r1, r0
	sar #3, r0
	ret
                                        ; -- End function
	.globl	pdc                             ; -- Begin function pdc
	.align	2
pdc:                                    ; @pdc
; %bb.0:
	sub r1, r0
	ret
                                        ; -- End function
	.globl	pds                             ; -- Begin function pds
	.align	2
pds:                                    ; @pds
; %bb.0:
	sub r0, r1
	sar #1, r1
	movq r1, r0
	ret
                                        ; -- End function
	.globl	e1                              ; -- Begin function e1
	.align	2
e1:                                     ; @e1
; %bb.0:
	movq r1, r2
	mul r0, r2
	lea 7(r2), r2
	movl r2, r3
	shr #60, r3
	and #7, r3
	add r2, r3
	movl r3, r2
	shr #3, r2
	sub r1, r0
	movl r0, r1
	shr #61, r1
	and #3, r1
	add r0, r1
	movq =4294967292, r3
	and r1, r3
	sub r3, r0
	add r2, r0
	movl r0, r0
	ret
                                        ; -- End function
	.globl	e2                              ; -- Begin function e2
	.align	2
e2:                                     ; @e2
; %bb.0:
	mul #3, r0
	lea -5(r0), r1
	movq r1, r0
	sar #63, r0
	shr #60, r0
	add r1, r0
	sar #4, r0
	ret
                                        ; -- End function
	.globl	test                            ; -- Begin function test
	.align	2
test:                                   ; @test
; %bb.0:
	clr r0
	movq #-1013, r1
	movq #-3005, r2
	br .LBB20_1
.LBB20_3:                               ;   in Loop: Header=BB20_1 Depth=1
	lea 13(r1), r1
	lea 39(r2), r2
	cbge r1, #987, .LBB20_4
.LBB20_1:                               ; =>This Inner Loop Header: Depth=1
	movq r2, r3
	sar #63, r3
	shr #60, r3
	add r2, r3
	sar #4, r3
	movq r1, r4
	mul #3, r4
	lea 34(r4), r4
	movl r4, r5
	shr #59, r5
	and #15, r5
	add r4, r5
	movl r5, r4
	sar #4, r4
	cbeq r3, r4, .LBB20_3
; %bb.2:                                ;   in Loop: Header=BB20_1 Depth=1
	bis #4096, r0
	br .LBB20_3
.LBB20_4:
	movl r0, r0
	ret
                                        ; -- End function
