; The routines and the data of the IOMMU tests (errata 194): included at the bottom of a test, after iommu-lib.h at the top.
; Registers: r11 the unit's register block, r12 the register window of the active test function (r22 of the second function: lib_swap12 exchanges them),
; r13 the active function's configuration space.  The routines clobber r1 to r9 and r16 to r27; a test keeps its own values in r10, r14 (the stack), r15, r28 and r29;
; r30 counts the interrupts of the unit, r31 is free for the interrupt routine.  A failed check halts with the number of the check in r0 (the caller passes it in r3 where
; a routine has checks of its own); the machine check and the bus fault, which the unit must never cause, halt with 50 and 51.
	.text
; ---- enumeration: the first test function (device 2) gets its window at MAP_PCIE_MMIO, memory space and bus mastering on ----
lib_pci_up:
	mov	=(MAP_PCIE_ECAM+(2<<15)), r13
	mov.u32	(r13), r1
	mov	=((DMATEST_ID_DEVICE<<16)|DMATEST_ID_VENDOR), r2
	cbeq r1, r2, 1f
	mov	$101, r0
	halt
1:	mov	=MAP_PCIE_MMIO, r1
	mov.s32	r1, 16(r13)
	shr	$32, r1
	mov.s32	r1, 20(r13)
	mov	$6, r1
	mov.s16	r1, 4(r13)
	mov	=MAP_PCIE_MMIO, r12
	mov	=MAP_IOMMU, r11
	ret
; the second function (device 3): its window is 64 KiB above; r22 is its window
lib_pci_up2:
	mov	=(MAP_PCIE_ECAM+(3<<15)), r1
	mov.u32	(r1), r2
	mov	=((DMATEST_ID_DEVICE<<16)|DMATEST_ID_VENDOR), r3
	cbeq r2, r3, 1f
	mov	$102, r0
	halt
1:	mov	=(MAP_PCIE_MMIO+0x10000), r2
	mov.s32	r2, 16(r1)
	shr	$32, r2
	mov.s32	r2, 20(r1)
	mov	$6, r2
	mov.s16	r2, 4(r1)
	mov	=(MAP_PCIE_MMIO+0x10000), r22
	ret
lib_swap12:
	mov	r12, r1
	mov	r22, r12
	mov	r1, r22
	ret
; ---- the unit: the fault ring (16 records), the command ring (8 commands), the device table (two levels: directory dirpage, leaf page leafpage), everything on ----
lib_unit_up:
	lea	fring, r1
	mov	r1, IOMMU_REG_FAULT_BASE(r11)
	mov	$16, r1
	mov	r1, IOMMU_REG_FAULT_SIZE(r11)
	lea	cring, r1
	mov	r1, IOMMU_REG_RING_BASE(r11)
	mov	$8, r1
	mov	r1, IOMMU_REG_RING_SIZE(r11)
	lea	leafpage, r1
	bis	$(1<<IOMMU_DIR_V), r1
	lea	dirpage, r2
	mov	r1, (r2)
	lea	dirpage, r1
	bis	$IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	$CTL_ON, r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	ret
; the device entry of the requester identity r4 (its index in the leaf page is the low 7 bits): r1 word 0, r2 the root of stage A, r3 the root of stage B, word 3 zero
lib_dte:
	and	$127, r4
	shl	$5, r4
	lea	leafpage, r5
	add	r5, r4
	mov	r2, 8(r4)
	mov	r3, 16(r4)
	mov	$0, r5
	mov	r5, 24(r4)
	mov	r1, (r4)
	ret
; ---- page tables: a block is three pages (root, level 1, level 0) at the physical address r1; the device addresses are below 2 MiB ----
lib_tbl_clear:
	mov	$0, r2
	mov	=1536, r3
1:	mov	r2, (r1)+
	sub	$1, r3
	cbne	r3, $0, 1b
	ret
; r1 the block (where the tables are written), r5 the address that the pointers hold (the same for a table read by the unit; a guest-physical address for stage A of A then B)
lib_tbl_init:
	mov	r5, r2
	add	$4096, r2
	bis	$PTRL, r2
	mov	r2, (r1)
	mov	r5, r2
	add	$8192, r2
	bis	$PTRL, r2
	mov	r2, 4096(r1)
	ret
; a 4 KB leaf: r1 the block, r2 the device address, r3 the entry
lib_map:
	shr	$12, r2
	and	$511, r2
	shl	$3, r2
	add	r1, r2
	add	$8192, r2
	mov	r3, (r2)
	ret
; a leaf at level 1 (2 MB): r1 the block, r2 the device address, r3 the entry
lib_map_l1:
	shr	$21, r2
	and	$511, r2
	shl	$3, r2
	add	r1, r2
	add	$4096, r2
	mov	r3, (r2)
	ret
; ---- transfers: r1 the device address, r2 the length.  A write moves the function buffer to the device address, a read the other way.  They return r1 = the status, and
; a read r2 = the result; the status is cleared again ----
lib_dma_w:
	mov	r1, DMATEST_REG_DST(r12)
	mov	r2, DMATEST_REG_LEN(r12)
	mov	$((1<<DMATEST_CTL_START)|(1<<DMATEST_CTL_WRITE)), r2
	mov	r2, DMATEST_REG_CONTROL(r12)
	mov	DMATEST_REG_STATUS(r12), r1
	mov	r1, DMATEST_REG_STATUS(r12)
	ret
lib_dma_r:
	mov	r1, DMATEST_REG_SRC(r12)
	mov	r2, DMATEST_REG_LEN(r12)
	mov	$(1<<DMATEST_CTL_START), r2
	mov	r2, DMATEST_REG_CONTROL(r12)
	mov	DMATEST_REG_STATUS(r12), r1
	mov	DMATEST_REG_RESULT(r12), r2
	mov	r1, DMATEST_REG_STATUS(r12)
	ret
; ---- the commands: r1 word 0, r2 word 1; by the invalidate register, and by the command ring ----
lib_cmd:
	mov	r1, IOMMU_REG_INV0(r11)
	mov	r2, IOMMU_REG_INV1(r11)
	ret
lib_ring:
	lea	ringtail, r3
	mov	(r3), r4
	lea	cring, r5
	mov	r4, r6
	shl	$4, r6
	add	r5, r6
	mov	r1, (r6)
	mov	r2, 8(r6)
	add	$1, r4
	and	$7, r4
	mov	r4, (r3)
	mov	r4, IOMMU_REG_DOORBELL(r11)
	ret
; a sync by the register path (r1 = 0) or the ring (r1 = 1): clears syncflag, syncs, and halts with r3 if the unit did not write 1
lib_sync:
	mov	r3, r18
	lea	syncflag, r2
	mov	$0, r4
	mov	r4, (r2)
	cbne r1, $0, 1f
	mov	$IOMMU_OP_SYNC, r1
	call	lib_cmd
	br	2f
1:	mov	$IOMMU_OP_SYNC, r1
	call	lib_ring
2:	lea	syncflag, r2
	mov	(r2), r4
	cbne r4, $1, lib_fail
	ret
; ---- the fault ring ----
lib_drain:
	mov	IOMMU_REG_FAULT_TAIL(r11), r1
	mov	r1, IOMMU_REG_FAULT_HEAD(r11)
	ret
; the last record: r1 to r4 = its four words
lib_lastrec:
	mov	IOMMU_REG_FAULT_TAIL(r11), r5
	mov	IOMMU_REG_FAULT_SIZE(r11), r6
	sub	$1, r6
	sub	$1, r5
	and	r6, r5
	shl	$5, r5
	lea	fring, r6
	add	r6, r5
	mov	(r5), r1
	mov	8(r5), r2
	mov	16(r5), r3
	mov	24(r5), r4
	ret
lib_fail:
	mov	r18, r0
	halt
; the write at the device address r1 must reach exactly the pages of the mask r2 (see lib_which); r3 the number of the check
lib_expect:
	mov	r2, r17
	mov	r3, r18
	call	lib_which
	cbne r1, r17, lib_fail
	ret
; map the device address r2 to the page r3 (read and write) in the block r1
lib_mappage:
	bis	$RWL, r3
	br	lib_map
; ---- checks ----
; an access of 8 bytes at the device address r1 must be refused: r2 the cause, r3 the number of the check, r4 the stage, r5 the kind (1 a write, 0 a read).  A read must give
; the status of a failed transfer with a nonzero result and leave the buffer alone; a write has no answer (status done), and the count of dropped writes must go up by one.
; Exactly one record must have been written, with the cause, the stage, the kind, the valid bit and the device address; the ring is drained afterwards.
lib_chk_ref:
	mov	r1, r16
	mov	r2, r17
	mov	r3, r18
	mov	r4, r19
	mov	r5, r20
	mov	IOMMU_REG_FAULT_TAIL(r11), r21
	mov	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	mov	=0x5a5a5a5a5a5a5a5a, r27
	mov	r27, (r26)
	cbne r20, $0, 3f
	mov	IOMMU_REG_REFUSED_READS(r11), r23
	mov	r16, r1
	mov	$8, r2
	call	lib_dma_r
	cbne r1, $ST_ERR, lib_fail
	cbeq r2, $0, lib_fail
	mov	(r26), r6
	cbne r6, r27, lib_fail
	mov	IOMMU_REG_REFUSED_READS(r11), r6
	sub	r23, r6
	cbne r6, $1, lib_fail
	br	2f
3:	mov	IOMMU_REG_DROPPED_WRITES(r11), r23
	mov	r16, r1
	mov	$8, r2
	call	lib_dma_w
	cbne r1, $ST_DONE, lib_fail
	mov	IOMMU_REG_DROPPED_WRITES(r11), r6
	sub	r23, r6
	cbne r6, $1, lib_fail
2:	mov	IOMMU_REG_FAULT_TAIL(r11), r6
	sub	r21, r6
	mov	IOMMU_REG_FAULT_SIZE(r11), r7
	sub	$1, r7
	and	r7, r6
	cbne r6, $1, lib_fail
	call	lib_lastrec
	mov	r1, r5
	and	$0xff, r5
	cbne r5, r17, lib_fail
	mov	r1, r5
	shr	$8, r5
	and	$3, r5
	cbne r5, r19, lib_fail
	mov	r1, r5
	shr	$10, r5
	and	$1, r5
	cbne r5, r20, lib_fail
	mov	r1, r5
	shr	$62, r5
	and	$1, r5
	cbne r5, $1, lib_fail
	cbne r3, r16, lib_fail
	call	lib_drain
	ret
; the last record must have the cause r1, the stage r2, the word of identities r3 (requester identity | guest tag << 16), the device address r4 and the guest-physical address r5
; (r6 the number of the check); the ring is drained afterwards
lib_chk_rec:
	mov	r1, r17
	mov	r2, r19
	mov	r3, r20
	mov	r4, r21
	mov	r5, r23
	mov	r6, r18
	call	lib_lastrec
	mov	r1, r5
	and	$0xff, r5
	cbne r5, r17, lib_fail
	mov	r1, r5
	shr	$8, r5
	and	$3, r5
	cbne r5, r19, lib_fail
	cbne r2, r20, lib_fail
	cbne r3, r21, lib_fail
	cbne r4, r23, lib_fail
	call	lib_drain
	ret
; a write of 8 bytes at the device address r1 must arrive at the physical address r2 (r3 the number of the check), with no refusal
lib_chk_ok_w:
	mov	r1, r16
	mov	r2, r17
	mov	r3, r18
	mov	$0, r6
	mov	r6, (r17)
	mov	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	mov	=0x6b6c6d6e6f707172, r27
	mov	r27, (r26)
	mov	IOMMU_REG_DROPPED_WRITES(r11), r23
	mov	IOMMU_REG_FAULT_TAIL(r11), r21
	mov	r16, r1
	mov	$8, r2
	call	lib_dma_w
	cbne r1, $ST_DONE, lib_fail
	mov	(r17), r6
	cbne r6, r27, lib_fail
	mov	IOMMU_REG_DROPPED_WRITES(r11), r6
	cbne r6, r23, lib_fail
	mov	IOMMU_REG_FAULT_TAIL(r11), r6
	cbne r6, r21, lib_fail
	ret
; a read of 8 bytes at the device address r1 must give the 8 bytes at the physical address r2 (r3 the number of the check), with no refusal
lib_chk_ok_r:
	mov	r1, r16
	mov	r2, r17
	mov	r3, r18
	mov	=0x7172737475767778, r27
	mov	r27, (r17)
	mov	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	mov	$0, r6
	mov	r6, (r26)
	mov	IOMMU_REG_REFUSED_READS(r11), r23
	mov	IOMMU_REG_FAULT_TAIL(r11), r21
	mov	r16, r1
	mov	$8, r2
	call	lib_dma_r
	cbne r1, $ST_DONE, lib_fail
	cbne r2, $0, lib_fail
	mov	(r26), r6
	cbne r6, r27, lib_fail
	mov	IOMMU_REG_REFUSED_READS(r11), r6
	cbne r6, r23, lib_fail
	mov	IOMMU_REG_FAULT_TAIL(r11), r6
	cbne r6, r21, lib_fail
	ret
; which page does a write at the page-aligned device address r1 reach?  Returns r1: bit 0 pg1, bit 1 pg2, bit 2 pg3 hold the pattern now; 0 if none (it was refused).  The ring is drained.
lib_which:
	mov	r1, r16
	mov	=DMATEST_MAP_BUFFER, r26
	add	r12, r26
	mov	=0x600dcafe00000042, r27
	mov	r27, (r26)
	mov	$0, r6
	lea	pg1, r3
	mov	r6, (r3)
	lea	pg2, r3
	mov	r6, (r3)
	lea	pg3, r3
	mov	r6, (r3)
	mov	r16, r1
	mov	$8, r2
	call	lib_dma_w
	mov	$0, r6
	lea	pg1, r3
	mov	(r3), r4
	cbne r4, r27, 1f
	bis	$1, r6
1:	lea	pg2, r3
	mov	(r3), r4
	cbne r4, r27, 1f
	bis	$2, r6
1:	lea	pg3, r3
	mov	(r3), r4
	cbne r4, r27, 1f
	bis	$4, r6
1:	mov	r6, r26
	call	lib_drain
	mov	r26, r1
	ret
; ---- the interrupt routines and the traps that must never happen ----
h_iommu:
	add	$1, r30
	mov	$CTL_QUIET, r31
	mov	r31, IOMMU_REG_CONTROL(r11)
	rti	$0xffffffff
fail_mc:
	mov	$50, r0			; a machine check: the unit must never cause one
	halt
fail_bus:
	mov	$51, r0			; a bus fault
	halt
	.data
	.align	8
vtab:
	.quad	0			; 0
	.quad	fail_mc			; 1: machine check
	.space	88			; 2 to 12
	.quad	fail_bus		; 13: bus fault
	.space	144			; 14 to 31
	.space	56			; 32 to 38: the timer, the console, the four pins of the host bridge
	.quad	h_iommu			; 39: the unit
	.space	3776
	.align	4096
dirpage:	.space	4096
leafpage:	.space	4096
dirpage2:	.space	4096
leafpage2:	.space	4096
ts_a:	.space	12288
ts_b:	.space	12288
ts_c:	.space	12288
r4page:	.space	4096
r5page:	.space	4096
idpage:	.space	4096
pg1:	.space	4096
pg2:	.space	4096
pg3:	.space	4096
fring:	.space	1024
	.align	4096
cring:	.space	128
ringtail:	.quad	0
syncflag:	.quad	0
	.space	4096
stk_top:
