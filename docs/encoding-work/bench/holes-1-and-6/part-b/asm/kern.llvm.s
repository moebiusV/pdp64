	.text
	.globl	sys_null                        ; -- Begin function sys_null
	.align	2
sys_null:                               ; @sys_null
; %bb.0:
	clr r0
	ret
                                        ; -- End function
	.globl	sys_getpid                      ; -- Begin function sys_getpid
	.align	2
sys_getpid:                             ; @sys_getpid
; %bb.0:
	movq 24(r0), r0
	ret
                                        ; -- End function
	.globl	copyin_bytes                    ; -- Begin function copyin_bytes
	.align	2
copyin_bytes:                           ; @copyin_bytes
; %bb.0:
	movq #-14, r3
	cbcs r1, #4096, .LBB2_6
; %bb.1:
	movq r1, r4
	add r2, r4
	bis r2, r4
	shr #39, r4
	cbne r4, #0, .LBB2_6
; %bb.2:
	cbeq r2, #0, .LBB2_5
; %bb.3:                                ; %.preheader
	clr r3
.LBB2_4:                                ; =>This Inner Loop Header: Depth=1
	movb 0(r1)(r3*1), r4
	movb r4, 0(r0)(r3*1)
	lea 1(r3), r3
	cbne r2, r3, .LBB2_4
.LBB2_5:
	movq r2, r3
.LBB2_6:
	movq r3, r0
	ret
                                        ; -- End function
	.globl	copyout_words                   ; -- Begin function copyout_words
	.align	2
copyout_words:                          ; @copyout_words
; %bb.0:
	movq r2, r4
	and #7, r4
	movq #-14, r3
	cbne r4, #0, .LBB3_7
; %bb.1:
	cbcs r0, #4096, .LBB3_7
; %bb.2:
	movq r0, r4
	add r2, r4
	bis r2, r4
	shr #39, r4
	cbne r4, #0, .LBB3_7
; %bb.3:
	cbeq r2, #0, .LBB3_6
; %bb.4:                                ; %.preheader
	movq r2, r3
	shr #3, r3
.LBB3_5:                                ; =>This Inner Loop Header: Depth=1
	movq (r1)+, r4
	movq r4, (r0)+
	lea -1(r3), r3
	cbne r3, #0, .LBB3_5
.LBB3_6:
	movq r2, r3
.LBB3_7:
	movq r3, r0
	ret
                                        ; -- End function
	.globl	sys_dup                         ; -- Begin function sys_dup
	.align	2
sys_dup:                                ; @sys_dup
; %bb.0:
	movq r0, r1
	movq #-9, r0
	cbhi r1, #63, .LBB4_3
; %bb.1:
	lea fdtab, r2
	movq 0(r2)(r1*8), r1
	cbeq r1, #0, .LBB4_3
; %bb.2:
	movq 0(r1), r0
	lea 1(r0), r0
	movq r0, 0(r1)
	movq 24(r1), r0
.LBB4_3:
	ret
                                        ; -- End function
	.globl	hash_lookup                     ; -- Begin function hash_lookup
	.align	2
hash_lookup:                            ; @hash_lookup
; %bb.0:
	movq =-7046029254386353131, r2
	mul r0, r2
	shr #56, r2
	clr r4
	lea htab, r3
.LBB5_1:                                ; =>This Inner Loop Header: Depth=1
	movzl r2, r1
	shl #4, r1
	movq 0(r1)(r3*1), r5
	cbeq r5, r0, .LBB5_2
; %bb.3:                                ;   in Loop: Header=BB5_1 Depth=1
	movq #-2, r1
	cbeq r5, #0, .LBB5_5
; %bb.4:                                ;   in Loop: Header=BB5_1 Depth=1
	lea 1(r4), r4
	movzl r4, r5
	lea 1(r2), r2
	movzb r2, r2
	cbne r5, #256, .LBB5_1
.LBB5_5:
	movq r1, r0
	ret
.LBB5_2:
	add r3, r1
	movq 8(r1), r1
	movq r1, r0
	ret
                                        ; -- End function
	.globl	checksum                        ; -- Begin function checksum
	.align	2
checksum:                               ; @checksum
; %bb.0:
	movq r0, r2
	clr r0
	cbcs r1, #2, .LBB6_2
.LBB6_1:                                ; =>This Inner Loop Header: Depth=1
	movzb 0(r2), r3
	movzb 1(r2), r4
	shl #8, r4
	bis r3, r4
	add r4, r0
	lea 2(r2), r2
	lea -2(r1), r1
	cbhi r1, #1, .LBB6_1
.LBB6_2:
	cbeq r1, #0, .LBB6_6
; %bb.3:
	movzb 0(r2), r1
	br .LBB6_5
.LBB6_4:
	movzw r0, r1
	shr #16, r0
.LBB6_5:
	add r1, r0
.LBB6_6:
	movq r0, r1
	shr #16, r1
	cbne r1, #0, .LBB6_4
; %bb.7:
	xor #65535, r0
	ret
                                        ; -- End function
	.globl	crc32                           ; -- Begin function crc32
	.align	2
crc32:                                  ; @crc32
; %bb.0:
	cbeq r1, #0, .LBB7_1
; %bb.4:                                ; %.preheader
	movq =4294967295, r5
	clr r2
	movq =4294967294, r3
.LBB7_5:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB7_6 Depth 2
	movzb 0(r0)(r2*1), r4
	xor r5, r4
	clr r5
.LBB7_6:                                ;   Parent Loop BB7_5 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	movq r4, r6
	and r3, r6
	shr #1, r6
	and #1, r4
	neg r4
	and #-306674912, r4
	xor r6, r4
	lea 1(r5), r5
	movzl r5, r6
	cbne r6, #8, .LBB7_6
; %bb.7:                                ;   in Loop: Header=BB7_5 Depth=1
	lea 1(r2), r2
	movq r4, r5
	cbne r2, r1, .LBB7_5
; %bb.2:
	com r4
	movzl r4, r0
	ret
.LBB7_1:
	clr r0
	ret
                                        ; -- End function
	.globl	chacha_block                    ; -- Begin function chacha_block
	.align	2
chacha_block:                           ; @chacha_block
; %bb.0:
	push fp
	movq sp, fp
	sub #72, sp
	movq r8, -8(r13)                        ; 8-byte Folded Spill
	movq r9, -16(r13)                       ; 8-byte Folded Spill
	movq r10, -24(r13)                      ; 8-byte Folded Spill
	movq r11, -32(r13)                      ; 8-byte Folded Spill
	movq r15, -40(r13)                      ; 8-byte Folded Spill
	movq r24, -48(r13)                      ; 8-byte Folded Spill
	movq r25, -56(r13)                      ; 8-byte Folded Spill
	movq r26, -64(r13)                      ; 8-byte Folded Spill
	movq r27, -72(r13)                      ; 8-byte Folded Spill
	movq r14, r1
	lea -64(r1), r1
	and #-16, r1
	movq r1, r14
	clr r2
.LBB8_1:                                ; =>This Inner Loop Header: Depth=1
	movl 0(r0)(r2*4), r3
	movl r3, 0(r1)(r2*4)
	lea 1(r2), r2
	cbne r2, #16, .LBB8_1
; %bb.2:
	movl 16(r1), r8
	movl 0(r1), r2
	movl 48(r1), r15
	movl 32(r1), r3
	movl 20(r1), r9
	movl 4(r1), r4
	movl 52(r1), r24
	movl 36(r1), r5
	movl 24(r1), r10
	movl 8(r1), r6
	movl 56(r1), r25
	movl 40(r1), r7
	movl 28(r1), r11
	movl 12(r1), r16
	movl 60(r1), r23
	movl 44(r1), r17
	clr r18
	movq =4294901760, r19
	movq =4293918720, r20
	movq =4278190080, r21
	movq =4261412864, r22
.LBB8_3:                                ; =>This Inner Loop Header: Depth=1
	add r8, r2
	xor r2, r15
	movq r15, r26
	and r19, r26
	shl #16, r15
	shr #16, r26
	bis r15, r26
	add r26, r3
	xor r3, r8
	movq r8, r27
	and r20, r27
	shl #12, r8
	shr #20, r27
	bis r8, r27
	add r27, r2
	xor r2, r26
	movq r26, r15
	and r21, r15
	shl #8, r26
	shr #24, r15
	bis r26, r15
	add r15, r3
	xor r3, r27
	movq r27, r8
	and r22, r8
	shl #7, r27
	shr #25, r8
	bis r27, r8
	add r9, r4
	xor r4, r24
	movq r24, r26
	and r19, r26
	shl #16, r24
	shr #16, r26
	bis r24, r26
	add r26, r5
	xor r5, r9
	movq r9, r27
	and r20, r27
	shl #12, r9
	shr #20, r27
	bis r9, r27
	add r27, r4
	xor r4, r26
	movq r26, r24
	and r21, r24
	shl #8, r26
	shr #24, r24
	bis r26, r24
	add r24, r5
	xor r5, r27
	movq r27, r9
	and r22, r9
	shl #7, r27
	shr #25, r9
	bis r27, r9
	add r10, r6
	xor r6, r25
	movq r25, r26
	and r19, r26
	shl #16, r25
	shr #16, r26
	bis r25, r26
	add r26, r7
	xor r7, r10
	movq r10, r27
	and r20, r27
	shl #12, r10
	shr #20, r27
	bis r10, r27
	add r27, r6
	xor r6, r26
	movq r26, r25
	and r21, r25
	shl #8, r26
	shr #24, r25
	bis r26, r25
	add r25, r7
	xor r7, r27
	movq r27, r10
	and r22, r10
	shl #7, r27
	shr #25, r10
	bis r27, r10
	add r11, r16
	xor r16, r23
	movq r23, r26
	and r19, r26
	shl #16, r23
	shr #16, r26
	bis r23, r26
	add r26, r17
	xor r17, r11
	movq r11, r23
	and r20, r23
	shl #12, r11
	shr #20, r23
	bis r11, r23
	add r23, r16
	xor r16, r26
	movq r26, r27
	and r21, r27
	shl #8, r26
	shr #24, r27
	bis r26, r27
	add r27, r17
	xor r17, r23
	movq r23, r11
	and r22, r11
	shl #7, r23
	shr #25, r11
	bis r23, r11
	add r9, r2
	xor r2, r27
	movq r27, r26
	and r19, r26
	shl #16, r27
	shr #16, r26
	bis r27, r26
	add r26, r7
	xor r7, r9
	movq r9, r27
	and r20, r27
	shl #12, r9
	shr #20, r27
	bis r9, r27
	add r27, r2
	xor r2, r26
	movq r26, r23
	and r21, r23
	shl #8, r26
	shr #24, r23
	bis r26, r23
	add r23, r7
	xor r7, r27
	movq r27, r9
	and r22, r9
	shl #7, r27
	shr #25, r9
	bis r27, r9
	add r10, r4
	xor r4, r15
	movq r15, r26
	and r19, r26
	shl #16, r15
	shr #16, r26
	bis r15, r26
	add r26, r17
	xor r17, r10
	movq r10, r27
	and r20, r27
	shl #12, r10
	shr #20, r27
	bis r10, r27
	add r27, r4
	xor r4, r26
	movq r26, r15
	and r21, r15
	shl #8, r26
	shr #24, r15
	bis r26, r15
	add r15, r17
	xor r17, r27
	movq r27, r10
	and r22, r10
	shl #7, r27
	shr #25, r10
	bis r27, r10
	add r11, r6
	xor r6, r24
	movq r24, r26
	and r19, r26
	shl #16, r24
	shr #16, r26
	bis r24, r26
	add r26, r3
	xor r3, r11
	movq r11, r27
	and r20, r27
	shl #12, r11
	shr #20, r27
	bis r11, r27
	add r27, r6
	xor r6, r26
	movq r26, r24
	and r21, r24
	shl #8, r26
	shr #24, r24
	bis r26, r24
	add r24, r3
	xor r3, r27
	movq r27, r11
	and r22, r11
	shl #7, r27
	shr #25, r11
	bis r27, r11
	add r8, r16
	xor r16, r25
	movq r25, r26
	and r19, r26
	shl #16, r25
	shr #16, r26
	bis r25, r26
	add r26, r5
	xor r5, r8
	movq r8, r27
	and r20, r27
	shl #12, r8
	shr #20, r27
	bis r8, r27
	add r27, r16
	xor r16, r26
	movq r26, r25
	and r21, r25
	shl #8, r26
	shr #24, r25
	bis r26, r25
	add r25, r5
	xor r5, r27
	movq r27, r8
	and r22, r8
	shl #7, r27
	shr #25, r8
	bis r27, r8
	lea 1(r18), r18
	movzl r18, r26
	cbne r26, #10, .LBB8_3
; %bb.4:
	movl r8, 16(r1)
	movl r2, 0(r1)
	movl r15, 48(r1)
	movl r3, 32(r1)
	movl r9, 20(r1)
	movl r4, 4(r1)
	movl r24, 52(r1)
	movl r5, 36(r1)
	movl r10, 24(r1)
	movl r6, 8(r1)
	movl r25, 56(r1)
	movl r7, 40(r1)
	movl r11, 28(r1)
	movl r16, 12(r1)
	movl r23, 60(r1)
	movl r17, 44(r1)
	clr r2
	clr r4
.LBB8_5:                                ; =>This Inner Loop Header: Depth=1
	movl 0(r1)(r2*4), r3
	movl 0(r0)(r2*4), r5
	add r4, r3
	add r5, r3
	lea 1(r2), r2
	movq r3, r4
	cbne r2, #16, .LBB8_5
; %bb.6:
	movzl r3, r0
	movq -72(r13), r27                      ; 8-byte Folded Reload
	movq -64(r13), r26                      ; 8-byte Folded Reload
	movq -56(r13), r25                      ; 8-byte Folded Reload
	movq -48(r13), r24                      ; 8-byte Folded Reload
	movq -40(r13), r15                      ; 8-byte Folded Reload
	movq -32(r13), r11                      ; 8-byte Folded Reload
	movq -24(r13), r10                      ; 8-byte Folded Reload
	movq -16(r13), r9                       ; 8-byte Folded Reload
	movq -8(r13), r8                        ; 8-byte Folded Reload
	movq fp, sp
	pop fp
	ret
                                        ; -- End function
	.globl	dispatch                        ; -- Begin function dispatch
	.align	2
dispatch:                               ; @dispatch
; %bb.0:
	cbhi r0, #5, .LBB9_1
; %bb.2:
	lea .LJTI9_0, r4
	movq 0(r4)(r0*8), r0
	jmp (r0)
.LBB9_3:
	clr r0
	ret
.LBB9_13:
	clr r0
	cbcs r2, #2, .LBB9_15
.LBB9_14:                               ; =>This Inner Loop Header: Depth=1
	movzb 0(r1), r3
	movzb 1(r1), r4
	shl #8, r4
	bis r3, r4
	add r4, r0
	lea 2(r1), r1
	lea -2(r2), r2
	cbhi r2, #1, .LBB9_14
.LBB9_15:
	cbeq r2, #0, .LBB9_19
; %bb.16:
	movzb 0(r1), r1
	br .LBB9_18
.LBB9_5:
	movq #-9, r0
	cbhi r1, #63, .LBB9_27
; %bb.6:
	lea fdtab, r2
	movq 0(r2)(r1*8), r1
	cbeq r1, #0, .LBB9_27
; %bb.7:
	movq 0(r1), r0
	lea 1(r0), r0
	movq r0, 0(r1)
	movq 24(r1), r0
	ret
.LBB9_8:
	movq =-7046029254386353131, r2
	mul r1, r2
	shr #56, r2
	clr r4
	lea htab, r3
.LBB9_9:                                ; =>This Inner Loop Header: Depth=1
	movzl r2, r0
	shl #4, r0
	movq 0(r0)(r3*1), r5
	cbeq r5, r1, .LBB9_10
; %bb.11:                               ;   in Loop: Header=BB9_9 Depth=1
	movq #-2, r0
	cbeq r5, #0, .LBB9_27
; %bb.12:                               ;   in Loop: Header=BB9_9 Depth=1
	lea 1(r4), r4
	movzl r4, r5
	lea 1(r2), r2
	movzb r2, r2
	cbne r5, #256, .LBB9_9
.LBB9_27:
	ret
.LBB9_4:
	movq 24(r1), r0
	ret
.LBB9_21:
	movq #-14, r0
	cbcs r2, #4096, .LBB9_27
; %bb.22:
	movq r3, r4
	add r2, r4
	bis r3, r4
	shr #39, r4
	cbne r4, #0, .LBB9_27
; %bb.23:
	cbeq r3, #0, .LBB9_26
; %bb.24:                               ; %.preheader4
	clr r0
.LBB9_25:                               ; =>This Inner Loop Header: Depth=1
	movb 0(r2)(r0*1), r4
	movb r4, 0(r1)(r0*1)
	lea 1(r0), r0
	cbne r3, r0, .LBB9_25
.LBB9_26:
	movq r3, r0
	ret
.LBB9_1:
	movq #-38, r0
	ret
.LBB9_10:
	add r3, r0
	movq 8(r0), r0
	ret
.LBB9_17:
	movzw r0, r1
	shr #16, r0
.LBB9_18:
	add r1, r0
.LBB9_19:
	movq r0, r1
	shr #16, r1
	cbne r1, #0, .LBB9_17
; %bb.20:
	xor #65535, r0
	ret
	.data
	.align	8
.LJTI9_0:
	.quad	.LBB9_3
	.quad	.LBB9_4
	.quad	.LBB9_5
	.quad	.LBB9_8
	.quad	.LBB9_13
	.quad	.LBB9_21
                                        ; -- End function
	.bss
	.globl	fdtab                           ; @fdtab
	.align	16
fdtab:
	.space	512

	.globl	htab                            ; @htab
	.align	16
htab:
	.space	4096

