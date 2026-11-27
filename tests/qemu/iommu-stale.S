; (d) The unit's cache makes a stale translation OBSERVABLE, and the commands and the register rules end it (errata 194; manual 2.11.7, 6.8.5 and errata 178 for the processor).
; The unit keeps a translation until it is told to drop it (the architecture allows an implementation to drop more and at any time: a program may not depend on a stale
; entry surviving; the model never drops what it is not told to, so a missing invalidate shows, and each "stale" check below says so).  Per step: the table entry is changed
; with no invalidate (the DMA still reaches the old page: a property of the model), then the command is given, then sync, and the DMA must reach the new page and never the old.
;   a page-table entry changed:  invalidate device (by the register, then by the command ring, each with sync), invalidate domain, invalidate guest, invalidate all; a command
;   for another device, domain or guest leaves the translation (exactness of the model: the key has the identity, the guest tag and the domain tag);
;   the device entry changed (a new root and domain tag): stale until invalidate device;
;   the hardware rules, no command: a change of the device-table pointer (two-level to another table and back, and the one-level mode), the reset bit (the unit is blocked, and a
;   cached translation is not used while blocked);
;   a command it cannot decode sets the sticky command-error bit;
;   two guests with the same device addresses (two functions, guest tags 1 and 2): neither hits the other's translation; invalidate guest 1 leaves guest 2 stale.
; Which page a DMA write reached is read with lib_which: bit 0 pg1, bit 1 pg2, bit 2 pg3.  Failure: halt with the check number.
#include "iommu-lib.h"
	.text
	.globl	_start
_start:
	lea	stk_top, sp
	lea	vtab, r1
	mtsr	vbr, r1
	call	lib_pci_up
	call	lib_pci_up2
	call	lib_unit_up
	mov	#0, r30
	; the trees: ts_a maps 0x1000 to pg1, ts_b to pg2, ts_c to pg3
	lea	ts_a, r1
	call	lib_tbl_clear
	lea	ts_b, r1
	call	lib_tbl_clear
	lea	ts_c, r1
	call	lib_tbl_clear
	lea	ts_a, r1
	lea	ts_a, r5
	call	lib_tbl_init
	lea	ts_b, r1
	lea	ts_b, r5
	call	lib_tbl_init
	lea	ts_c, r1
	lea	ts_c, r5
	call	lib_tbl_init
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg1, r3
	call	lib_mappage
	lea	ts_b, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	lea	ts_c, r1
	mov	#0x1000, r2
	lea	pg3, r3
	call	lib_mappage
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 5, 0), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	#0x1000, r1
	mov	#1, r2
	mov	#11, r3
	call	lib_expect			; filled the cache: pg1
	; ---- invalidate device, by the register: the entry now says pg2; stale until the command ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	mov	#0x1000, r1
	mov	#1, r2
	mov	#12, r3
	call	lib_expect			; stale: the old page
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0, r1
	mov	#13, r3
	call	lib_sync
	mov	#0x1000, r1
	mov	#2, r2
	mov	#14, r3
	call	lib_expect			; the new page, never the old
	; ---- by the command ring ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg3, r3
	call	lib_mappage
	mov	#0x1000, r1
	mov	#2, r2
	mov	#15, r3
	call	lib_expect
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_ring
	mov	#1, r1
	mov	#16, r3
	call	lib_sync
	mov	#0x1000, r1
	mov	#4, r2
	mov	#17, r3
	call	lib_expect
	; the head of the ring has consumed what the doorbell said (two commands: the invalidate and the sync)
	mov	IOMMU_REG_CMD_HEAD(r11), r1
	mov	IOMMU_REG_DOORBELL(r11), r2
	cbeq r1, r2, 1f
	mov	#18, r0
	halt
1:	; ---- invalidate domain: another domain leaves it, the domain (5) ends it ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg1, r3
	call	lib_mappage
	mov	=CMD(IOMMU_OP_INV_DOMAIN, 0, 6, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#4, r2
	mov	#21, r3
	call	lib_expect			; domain 6 is not ours: still stale
	mov	=CMD(IOMMU_OP_INV_DOMAIN, 0, 5, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0, r1
	mov	#22, r3
	call	lib_sync
	mov	#0x1000, r1
	mov	#1, r2
	mov	#23, r3
	call	lib_expect
	; ---- invalidate guest (the host is guest 0): guest 1 leaves it, guest 0 ends it ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	mov	=CMD(IOMMU_OP_INV_GUEST, 0, 0, 1), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#1, r2
	mov	#31, r3
	call	lib_expect
	mov	=CMD(IOMMU_OP_INV_GUEST, 0, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#2, r2
	mov	#32, r3
	call	lib_expect
	; another device (its identity differs): leaves it; invalidate all ends it
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg3, r3
	call	lib_mappage
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID2, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#2, r2
	mov	#33, r3
	call	lib_expect
	mov	=CMD(IOMMU_OP_INV_ALL, 0, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#4, r2
	mov	#34, r3
	call	lib_expect
	; ---- the device entry changed (a new root, ts_b, and a new domain tag): stale until invalidate device ----
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 6, 0), r1
	lea	ts_b, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	#0x1000, r1
	mov	#4, r2
	mov	#41, r3
	call	lib_expect			; the cached entry and translation: still ts_a (pg3)
	mov	=CMD(IOMMU_OP_INV_DEVICE, RID1, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#2, r2
	mov	#42, r3
	call	lib_expect			; the new entry: ts_b, pg2
	; ---- a change of the device-table pointer discards the cache with no command: a second table (dirpage2, leafpage2) whose entry for this device has the root ts_c (pg3) ----
	lea	ts_b, r1
	mov	#0x1000, r2
	lea	pg1, r3
	call	lib_mappage			; (ts_b now says pg1: stale, 2, until something drops it)
	mov	=(DTE0(IOMMU_STAGES_A, 3, 0, 7, 0)), r1
	lea	leafpage2, r4
	add	#512, r4
	mov	r1, (r4)
	lea	ts_c, r1
	mov	r1, 8(r4)
	lea	leafpage2, r1
	bis	#(1<<IOMMU_DIR_V), r1
	lea	dirpage2, r2
	mov	r1, (r2)
	mov	#0x1000, r1
	mov	#2, r2
	mov	#51, r3
	call	lib_expect			; still stale
	lea	dirpage2, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	#0x1000, r1
	mov	#4, r2
	mov	#52, r3
	call	lib_expect			; the new table, no command
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	#0x1000, r1
	mov	#1, r2
	mov	#53, r3
	call	lib_expect			; the first table again: ts_b, which now says pg1
	; the one-level mode: the device entries are in the page the register names
	lea	ts_b, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	lea	leafpage, r1
	bis	#IOMMU_MODE_ONE_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	#0x1000, r1
	mov	#2, r2
	mov	#54, r3
	call	lib_expect
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	; ---- the reset bit: the cache is discarded and the unit is blocked: a cached translation is not used while blocked ----
	mov	#0x1000, r1
	mov	#2, r2
	mov	#61, r3
	call	lib_expect			; cached (pg2)
	mov	#(CTL_ON|(1<<IOMMU_CONTROL_RESET)), r1
	mov	r1, IOMMU_REG_CONTROL(r11)
	mov	IOMMU_REG_CONTROL(r11), r1
	cbeq r1, #CTL_ON, 1f
	mov	#62, r0
	halt
1:	mov	IOMMU_REG_DEVICE(r11), r1
	and	#((1<<IOMMU_DEVICE_WIDTH_MODE)-1), r1
	cbeq	r1, #0, 1f
	mov	#63, r0
	halt
1:	mov	#0x1000, r1
	mov	#0, r2
	mov	#64, r3
	call	lib_expect			; blocked: refused, although it was cached
	lea	dirpage, r1
	bis	#IOMMU_MODE_TWO_LEVEL, r1
	mov	r1, IOMMU_REG_DEVICE(r11)
	mov	#0x1000, r1
	mov	#2, r2
	mov	#65, r3
	call	lib_expect
	; ---- a command the unit cannot decode: the sticky command-error bit, cleared by writing one; a no-op does nothing ----
	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_CMD_ERROR), r1
	cbeq	r1, #0, 1f
	mov	#71, r0
	halt
1:	mov	#IOMMU_OP_NOP, r1
	mov	#0, r2
	call	lib_cmd
	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_CMD_ERROR), r1
	cbeq	r1, #0, 1f
	mov	#72, r0
	halt
1:	mov	#0x7f, r1
	mov	#0, r2
	call	lib_cmd
	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_CMD_ERROR), r1
	cbne	r1, #0, 1f
	mov	#73, r0
	halt
1:	mov	#(1<<IOMMU_STATUS_CMD_ERROR), r1
	mov	r1, IOMMU_REG_STATUS(r11)
	mov	IOMMU_REG_STATUS(r11), r1
	and	#(1<<IOMMU_STATUS_CMD_ERROR), r1
	cbeq	r1, #0, 1f
	mov	#74, r0
	halt
1:	; ---- two guests, the same device addresses: function 1 (RID1) is guest 1 with ts_a (0x1000 -> pg3 now), function 2 (RID2) is guest 2 with ts_c (0x1000 -> pg1 after the change below) ----
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg1, r3
	call	lib_mappage
	lea	ts_c, r1
	mov	#0x1000, r2
	lea	pg3, r3
	call	lib_mappage
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 5, 1), r1
	lea	ts_a, r2
	mov	#0, r3
	mov	#RID1, r4
	call	lib_dte
	mov	=DTE0(IOMMU_STAGES_A, 3, 0, 5, 2), r1
	lea	ts_c, r2
	mov	#0, r3
	mov	#RID2, r4
	call	lib_dte
	mov	=CMD(IOMMU_OP_INV_ALL, 0, 0, 0), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#1, r2
	mov	#81, r3
	call	lib_expect			; guest 1: pg1
	call	lib_swap12
	mov	#0x1000, r1
	mov	#4, r2
	mov	#82, r3
	call	lib_expect			; guest 2: pg3, not guest 1's page
	call	lib_swap12
	; change both entries with no invalidate: both stale
	lea	ts_a, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	lea	ts_c, r1
	mov	#0x1000, r2
	lea	pg2, r3
	call	lib_mappage
	mov	#0x1000, r1
	mov	#1, r2
	mov	#83, r3
	call	lib_expect
	call	lib_swap12
	mov	#0x1000, r1
	mov	#4, r2
	mov	#84, r3
	call	lib_expect
	call	lib_swap12
	; invalidate guest 1: guest 1 sees the new page, guest 2 is still stale
	mov	=CMD(IOMMU_OP_INV_GUEST, 0, 0, 1), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0, r1
	mov	#85, r3
	call	lib_sync
	mov	#0x1000, r1
	mov	#2, r2
	mov	#86, r3
	call	lib_expect
	call	lib_swap12
	mov	#0x1000, r1
	mov	#4, r2
	mov	#87, r3
	call	lib_expect
	mov	=CMD(IOMMU_OP_INV_GUEST, 0, 0, 2), r1
	mov	#0, r2
	call	lib_cmd
	mov	#0x1000, r1
	mov	#2, r2
	mov	#88, r3
	call	lib_expect
	call	lib_swap12
	mov	#0, r0
	halt
#include "iommu-lib.inc"
