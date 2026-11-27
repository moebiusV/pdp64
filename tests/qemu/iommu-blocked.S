; (f) The unit is BLOCKED at reset: before it is configured no DMA of any function reaches memory (a write is dropped and counted, a read gets the error completion), and
; with the logging not yet configured nothing is logged; blocked with a good table in memory, the refusal has the cause "blocked"; set to the two-level mode the same DMA works;
; and the reset bit makes it blocked again.  (g) A BAD TABLE FAILS CLOSED (errata 194; manual 2.11.1, 2.11.3, 2.11.6): a reserved bit in the device entry or the directory
; entry, stages 0, a level count that is not 3, 4 or 5, a misaligned or too wide root, a nonzero reserved word: every access is refused with the cause "bad entry" and nothing is
; delivered (a read leaves the buffer alone: never all ones); a table that cannot be read (the device-table pointer, a directory entry or a root pointing at a device window or at
; nothing) is refused with the cause "table read", sets the sticky table-error bit and raises the interrupt.  No machine check and no bus fault: the vectors halt the test with
; 50 and 51.  Failure: halt with the check number.
#include "iommu-lib.h"
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	mov	#0, r30
	mov	=0x5a5a5a5a5a5a5a5a, r1
	lea	pg1, r2
	mov	r1, (r2)
	; ---- (f) at reset, nothing configured: the write is dropped, the read fails, both counted; nothing in a log that does not exist ----
	lea	pg1, r1				; the device address of the identity page below is its own address; it is not mapped now
	mov	#8, r2
	call	lib_dma_w
	cbeq r1, #ST_DONE, 1f
	mov	#11, r0
	halt
1:	lea	pg1, r2
	mov	(r2), r1
	mov	=0x5a5a5a5a5a5a5a5a, r2
	cbeq r1, r2, 1f
	mov	#12, r0
	halt
1:	mov	IOMMU_REG_DROPPED_WRITES(r11), r1
	cbeq r1, #1, 1f
	mov	#13, r0
	halt
1:	lea	pg1, r1
	mov	#8, r2
	call	lib_dma_r
	cbeq r1, #ST_ERR, 1f
	mov	#14, r0
	halt
1:	cbne r2, #0, 1f
	mov	#15, r0
	halt
1:	mov	IOMMU_REG_REFUSED_READS(r11), r1
	cbeq r1, #1, 1f
	mov	#16, r0
	halt
1:	mov	IOMMU_REG_FAULT_TAIL(r11), r1
	mov	IOMMU_REG_STATUS(r11), r2
	bis	r2, r1
	cbeq r1, #0, 1f
	mov	#17, r0
	halt
1:	; ---- configured but blocked, with a good table in memory: the cause is "blocked" ----
	call	lib_unit_up
	mov	#0, r1
	mov	r1, IOMMU_REG_DEVICE(r11)			; blocked
	mov	#(1<<PTE_V|1<<PTE_R|1<<PTE_W), r1		; the identity page: a 1 GB leaf at index 0 of a three-level root
	lea	idpage, r2
	mov	r1, (r2)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	idpage, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	lea	pg1, r1
	mov	#IOMMU_CAUSE_BLOCKED, r2
	mov	#21, r3
	mov	#IOMMU_STAGE_TABLE, r4
	mov	#1, r5
	call	lib_chk_ref
	lea	pg1, r1
	mov	#IOMMU_CAUSE_BLOCKED, r2
	mov	#22, r3
	mov	#IOMMU_STAGE_TABLE, r4
	mov	#0, r5
	call	lib_chk_ref
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)			; two levels: the same DMA works
	lea	pg1, r1
	lea	pg1, r2
	mov	#23, r3
	call	lib_chk_ok_w
	lea	pg1, r1
	lea	pg1, r2
	mov	#24, r3
	call	lib_chk_ok_r
	mov	#(CTL_ON|(1<<IOMMU_CONTROL_RESET)), r1		; the reset bit: blocked again
	mov	r1, IOMMU_REG_CONTROL(r11)
	lea	pg1, r1
	mov	#IOMMU_CAUSE_BLOCKED, r2
	mov	#25, r3
	mov	#IOMMU_STAGE_TABLE, r4
	mov	#1, r5
	call	lib_chk_ref
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	; ---- (g) bad tables.  try(r1 word 0, r2 root A, r3 word 3, r4 cause, r5 check, r15 stage): write the entry, drop the cached one, a write and a read must be refused ----
	mov	=0x5a5a5a5a5a5a5a5a, r1
	lea	pg1, r2
	mov	r1, (r2)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; word 0 with a reserved bit (12)
	mov	=(1<<12), r2
	bis	r2, r1
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#31, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; a reserved bit (63)
	mov	=0x8000000000000000, r2
	bis	r2, r1
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#32, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	#(1<<IOMMU_DTE_V), r1				; stages 0 (reserved)
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#33, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 2, 0, 0, 0), r1		; two levels of A: not 3, 4 or 5
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#34, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 6, 0, 0, 0), r1		; six levels
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#35, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; a root that is not page aligned
	lea	idpage, r2
	add	#8, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#36, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; a root above 40 bits
	lea	idpage, r2
	mov	=0x20000000000, r3
	bis	r3, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#37, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; the reserved word (3) nonzero
	lea	idpage, r2
	mov	#1, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#38, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	mov	=DTE0(IOMMU_STAGES_B, 0, 3, 0, 0), r1		; stage B used with a root that is not page aligned
	mov	#0, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#39, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try_b4
	; the directory entry with a reserved bit
	lea	dirpage, r1
	mov	(r1), r2
	mov	r2, r10
	bis	#32, r2
	mov	r2, (r1)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_BAD_ENTRY, r4
	mov	#41, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	lea	dirpage, r1
	mov	r10, (r1)
	; ---- tables that cannot be read: the table-read cause, the sticky bit, the interrupt ----
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; a root in a device window (the timer's page)
	mov	=MAP_TIMER, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_TABLE_READ, r4
	mov	#91, r5
	mov	#IOMMU_STAGE_A, r15
	call	try
	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_TABLE_ERROR), r1
	cbne	r1, #0, 1f
	mov	#52, r0
	halt
1:	spl	#0					; the interrupt (the sticky bit and the log) is taken once at priority 0
	nop
	nop
	spl	#7
	cbge r30, #1, 1f
	mov	#53, r0
	halt
1:	mov	#(1<<IOMMU_STATUS_TABLE_ERROR), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	mov	#CTL_ON, r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1		; a root at an address that nothing answers (above the end of RAM)
	mov	=0x20000000, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_TABLE_READ, r4
	mov	#54, r5
	mov	#IOMMU_STAGE_A, r15
	call	try
	mov	#(1<<IOMMU_STATUS_TABLE_ERROR), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	lea	dirpage, r1					; a directory entry that points the leaf page into a device window
	mov	=(MAP_TIMER|(1<<IOMMU_DIR_V)), r2
	mov	r2, (r1)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_TABLE_READ, r4
	mov	#61, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try
	lea	dirpage, r1
	lea	leafpage, r2
	bis	#(1<<IOMMU_DIR_V), r2
	mov	r2, (r1)
	mov	#(1<<IOMMU_STATUS_TABLE_ERROR), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	mov	=MAP_TIMER, r1					; the device-table pointer itself at a device window
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	idpage, r2
	mov	#0, r3
	mov	#IOMMU_CAUSE_TABLE_READ, r4
	mov	#62, r5
	mov	#IOMMU_STAGE_TABLE, r15
	call	try_nodte
	mov	#(1<<IOMMU_STATUS_TABLE_ERROR), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	; ---- control: with everything repaired the same DMA works, so the refusals above were the bad tables and not something else ----
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 0, 0), r1
	lea	idpage, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	lea	pg1, r1
	lea	pg1, r2
	mov	#71, r3
	call	lib_chk_ok_w
	mov	#0, r0
	halt
; try: the entry (r1 word 0, r2 root A, r3 word 3) is written, the cached entry dropped; a write and a read at the identity address of pg1 must be refused with the cause r4,
; the stage r15 (check r5, r5 + 100 for the read); pg1 must still hold the sentinel
try:
	mov	r4, r24
	mov	r5, r25
	mov	r3, r28
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	lea	leafpage, r4
	add	#(RID1*32), r4
	mov	r28, 24(r4)
try_inv:
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	lea	pg1, r1
	mov	r24, r2
	mov	r25, r3
	mov	r15, r4
	mov	#1, r5
	call	lib_chk_ref
	lea	pg1, r1
	mov	r24, r2
	mov	r25, r3
	add	#100, r3
	mov	r15, r4
	mov	#0, r5
	call	lib_chk_ref
	lea	pg1, r2
	mov	(r2), r1
	mov	=0x5a5a5a5a5a5a5a5a, r2
	cbeq r1, r2, 1f
	mov	r25, r0
	halt
1:	ret
; try_b4: stage B with a root that is not page aligned
try_b4:
	mov	r4, r24
	mov	r5, r25
	mov	=DTE0(IOMMU_STAGES_B, 0, 3, 0, 0), r1
	mov	#0, r2
	lea	idpage, r3
	add	#16, r3
	mov	#RID1, r4
	call	lib_dte
	br	try_inv
; try_nodte: the entry is already good; only the refusal is checked (the device-table pointer is the thing that is bad)
try_nodte:
	mov	r4, r24
	mov	r5, r25
	br	try_inv
#include "iommu-lib.inc"
