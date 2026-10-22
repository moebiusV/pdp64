/*
 * pdp64 MMU: the three-level page-table walk of System v1 (section 15 of
 * docs/pdp64-system-architecture.md).  Called by tlb_fill for every access
 * of the kernel-mode machine while MMUCTL.enable is 1, in every mode.
 *
 * The walker never writes a page table (accessed and dirty bits are managed
 * by software: an access to a page with A = 0, or a write to a page with
 * D = 0, is a page fault), so a TLB entry is installed with exactly the
 * rights the PTE gives in the mode of the access, and a write to a clean
 * page misses again in the TLB and walks again.  All the numbers are the
 * generated constants of pdp64-consts.h (spec/pdp64-system.hbnf).
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "cpu.h"
#include "exec/page-protection.h"
#include "exec/target_page.h"
#include "system/memory.h"
#include "system/address-spaces.h"

#define PTE_BIT(n)      (1ULL << PTE_##n)
#define PTE_MASK(n)     (((1ULL << PTE_WIDTH_##n) - 1) << PTE_##n)
#define PTE_DEFINED     ((PTE_BIT(D) << 1) - 1) /* bits V..D, in order */
#define PTE_RESERVED    (~(PTE_DEFINED | PTE_MASK(MT) | PTE_MASK(PPN)))
#define PA_MASK         ((1ULL << MMU_PA_BITS) - 1)
#define LEVEL_ENTRIES   (1u << MMU_LEVEL_BITS)

/* the page-fault vector (the translation is not valid) and the protection
   vector (it is valid and does not allow this) of a kind of access */
static int page_fault_vector(MMUAccessType type)
{
    return type == MMU_INST_FETCH ? VECTOR_IFAULT
           : type == MMU_DATA_STORE ? VECTOR_SFAULT : VECTOR_LFAULT;
}

static int protection_vector(MMUAccessType type)
{
    return type == MMU_INST_FETCH ? VECTOR_IPROT
           : type == MMU_DATA_STORE ? VECTOR_SPROT : VECTOR_LPROT;
}

bool pdp64_mmu_translate(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                         int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                         int *fault_vector)
{
    bool kernel = mmu_idx == PDP64_MMU_KERNEL;
    uint64_t table = env->c.ptbr & PA_MASK & ~((1ULL << MMU_PAGE_BITS) - 1);
    uint64_t pte = 0;
    int level, shift = 0, rights;

    /* bits 63 to 39 must equal bit 38 */
    if ((uint64_t)((int64_t)(addr << (64 - MMU_VA_BITS)) >> (64 - MMU_VA_BITS))
        != addr) {
        *fault_vector = VECTOR_NONCANONICAL;
        return false;
    }
    for (level = MMU_LEVELS - 1; level >= 0; level--) {
        MemTxResult res;
        uint64_t idx;

        shift = MMU_PAGE_BITS + MMU_LEVEL_BITS * level;
        idx = (addr >> shift) & (LEVEL_ENTRIES - 1);
        pte = address_space_ldq_le(&address_space_memory, table + idx * 8,
                                   MEMTXATTRS_UNSPECIFIED, &res);
        if (res != MEMTX_OK) {
            *fault_vector = VECTOR_BUSFAULT;
            return false;
        }
        if (!(pte & PTE_BIT(V)) || (pte & PTE_RESERVED)) {
            goto page_fault;
        }
        if (pte & (PTE_BIT(R) | PTE_BIT(W) | PTE_BIT(X))) {
            break;                              /* a leaf */
        }
        if (level == 0) {
            goto page_fault;                    /* a pointer where there is nothing left to point to */
        }
        table = ((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS;
    }
    /* W without R is reserved; a superpage must be aligned to its size */
    if ((pte & PTE_BIT(W)) && !(pte & PTE_BIT(R))) {
        goto page_fault;
    }
    if ((((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS)
        & ((1ULL << shift) - 1)) {
        goto page_fault;
    }

    /* the rights in this mode: user needs U; the kernel may read and write
       U pages but never execute them */
    rights = 0;
    if (kernel || (pte & PTE_BIT(U))) {
        if (pte & PTE_BIT(R)) {
            rights |= PAGE_READ;
        }
        if (pte & PTE_BIT(W)) {
            rights |= PAGE_WRITE;
        }
        if ((pte & PTE_BIT(X)) && !(kernel && (pte & PTE_BIT(U)))) {
            rights |= PAGE_EXEC;
        }
    }
    if (!(rights & (type == MMU_INST_FETCH ? PAGE_EXEC
                    : type == MMU_DATA_STORE ? PAGE_WRITE : PAGE_READ))) {
        *fault_vector = protection_vector(type);
        return false;
    }
    /* accessed and dirty: software sets them, after a page fault */
    if (!(pte & PTE_BIT(A)) || (type == MMU_DATA_STORE && !(pte & PTE_BIT(D)))) {
        goto page_fault;
    }
    if (!(pte & PTE_BIT(D))) {
        rights &= ~PAGE_WRITE;                  /* a read of a clean page: a later store walks again */
    }
    /* the memory type MT (cached, uncached, device) makes no difference to
       QEMU: whether an address is RAM or a device follows from the address */
    *prot = rights;
    *size = 1ULL << shift;
    *pa = (((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS);
    return true;

page_fault:
    *fault_vector = page_fault_vector(type);
    return false;
}
