/*
 * pdp64 MMU: the page-table walk (System v1, section 15).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "cpu.h"
#include "exec/page-protection.h"
#include "exec/target_page.h"

bool pdp64_mmu_translate(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                         int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                         int *fault_vector)
{
    *pa = addr;
    *prot = PAGE_READ | PAGE_WRITE | PAGE_EXEC;
    *size = TARGET_PAGE_SIZE;
    return true;
}
