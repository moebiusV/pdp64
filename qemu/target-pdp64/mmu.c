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
 * generated constants of pdp64-consts.h (spec/grammars.d/50-system-v1.hbnf).
 *
 * The hypervisor mode adds stage 2 (errata 195, 196; design 1.7, 2.5, decisions 11 to 13, 23): a guest with GTBR.S2EN set has every address that stage 1 produces, and every
 * address of a page-table entry it reads, translated by a second walk of the same entry format (U and G zero, three levels, a root of two pages), software-managed accessed and
 * dirty bits: a clear A, or a clear D on a store, refuses.  A stage-2 failure is not an exception of the guest but an exit: it is recorded in env->c.s2_* and the caller raises it.
 * The translations of a guest are also kept in an architectural cache keyed by the guest tag (see cpu.h) that is discarded only as the rules G-a to G-d say.
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
#define XFLAG_WALK_BIT  (1u << XFLAG_WALK)

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

/* ---- stage 2 ---- */

static int s2_vector(MMUAccessType type)
{
    return type == MMU_INST_FETCH ? VECTOR_GIFAULT
           : type == MMU_DATA_STORE ? VECTOR_GSFAULT : VECTOR_GLFAULT;
}

static bool s2_fail(CPUPDP64State *env, int code, unsigned flags, uint64_t gpa)
{
    env->c.s2_code = code;
    env->c.s2_flags = flags;
    env->c.s2_gpa = gpa;
    return false;
}

/* the walk of stage 2: the root is two consecutive pages (1024 entries, so that the whole 40-bit guest-physical space is covered, the upper half being device space) and
   two more levels of 512.  An entry that is not valid is XCODE_S2_INVALID; one that is malformed, refuses the access or has a clear A (or a clear D on a store) is
   XCODE_S2_REFUSED.  On success *pa is the physical address, *rights the rights of stage 2 for a later access, *shift the size of the leaf. */
static bool s2_walk(CPUPDP64State *env, uint64_t gpa, MMUAccessType type,
                    unsigned flags, hwaddr *pa, int *rights, int *shift)
{
    uint64_t table = ((env->c.gtbr >> GTBR_ROOT)
                      & ((1ULL << GTBR_WIDTH_ROOT) - 1)) << MMU_PAGE_BITS;
    uint64_t pte = 0;
    int level, sh = 0, r;

    if (gpa >> MMU_PA_BITS) {
        return s2_fail(env, XCODE_S2_INVALID, flags, gpa);
    }
    for (level = MMU_LEVELS - 1; level >= 0; level--) {
        MemTxResult res;
        uint64_t idx;

        sh = MMU_PAGE_BITS + MMU_LEVEL_BITS * level;
        idx = (gpa >> sh) & ((level == MMU_LEVELS - 1 ? 2 * LEVEL_ENTRIES : LEVEL_ENTRIES) - 1);
        pte = address_space_ldq_le(&address_space_memory, table + idx * 8,
                                   MEMTXATTRS_UNSPECIFIED, &res);
        if (res != MEMTX_OK) {
            return s2_fail(env, XCODE_S2_INVALID, flags, gpa);
        }
        if (!(pte & PTE_BIT(V))) {
            return s2_fail(env, XCODE_S2_INVALID, flags, gpa);
        }
        if ((pte & PTE_RESERVED) || (pte & (PTE_BIT(U) | PTE_BIT(G)))) {
            return s2_fail(env, XCODE_S2_REFUSED, flags, gpa);
        }
        if (pte & (PTE_BIT(R) | PTE_BIT(W) | PTE_BIT(X))) {
            break;
        }
        if (level == 0) {
            return s2_fail(env, XCODE_S2_REFUSED, flags, gpa);
        }
        table = ((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS;
    }
    if (((pte & PTE_BIT(W)) && !(pte & PTE_BIT(R)))
        || (((((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS))
            & ((1ULL << sh) - 1))
        || !pdp64_pte_space_ok(pte)) {
        return s2_fail(env, XCODE_S2_REFUSED, flags, gpa);
    }
    r = ((pte & PTE_BIT(R)) ? PAGE_READ : 0) | ((pte & PTE_BIT(W)) ? PAGE_WRITE : 0)
        | ((pte & PTE_BIT(X)) ? PAGE_EXEC : 0);
    if (!(r & (type == MMU_INST_FETCH ? PAGE_EXEC
               : type == MMU_DATA_STORE ? PAGE_WRITE : PAGE_READ))
        || !(pte & PTE_BIT(A))
        || (type == MMU_DATA_STORE && !(pte & PTE_BIT(D)))) {
        return s2_fail(env, XCODE_S2_REFUSED, flags, gpa);
    }
    if (!(pte & PTE_BIT(D))) {
        r &= ~PAGE_WRITE;                       /* a read of a clean page: a later store walks again (software dirty bit) */
    }
    *rights = r;
    *shift = sh;
    *pa = (((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS)
          | (gpa & ((1ULL << sh) - 1));
    return true;
}

bool pdp64_s2_translate(CPUPDP64State *env, uint64_t gpa, MMUAccessType type,
                        unsigned flags, hwaddr *pa)
{
    int rights, shift;

    return s2_walk(env, gpa, type, flags, pa, &rights, &shift);
}

/* ---- the architectural cache of the translations of a guest ---- */

static uint16_t cur_tag(const CPUPDP64State *env)
{
    return (env->c.gtbr >> GTBR_TAG) & ((1u << GTBR_WIDTH_TAG) - 1);
}

static bool acache_lookup(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                          int mmu_idx, hwaddr *pa, int *prot, vaddr *size)
{
    int need = type == MMU_INST_FETCH ? PAGE_EXEC
               : type == MMU_DATA_STORE ? PAGE_WRITE : PAGE_READ;
    unsigned i;

    for (i = 0; i < PDP64_ACACHE_N; i++) {
        struct PDP64ACache *e = &env->acache[i];

        if (e->valid && e->tag == cur_tag(env) && e->idx == mmu_idx
            && e->vpn == addr >> MMU_PAGE_BITS
            && (e->global || e->asid == (env->c.asid & 0xffff))
            && (e->prot & need)) {
            *pa = e->pa;
            *prot = e->prot;
            *size = e->size;
            return true;
        }
    }
    return false;
}

static void acache_insert(CPUPDP64State *env, vaddr addr, int mmu_idx,
                          hwaddr pa, int prot, vaddr size, bool global)
{
    struct PDP64ACache *slot = NULL;
    unsigned i;

    for (i = 0; i < PDP64_ACACHE_N; i++) {
        struct PDP64ACache *e = &env->acache[i];

        if (e->valid && e->tag == cur_tag(env) && e->idx == mmu_idx
            && e->vpn == addr >> MMU_PAGE_BITS
            && (e->global == global) && (global || e->asid == (env->c.asid & 0xffff))) {
            slot = e;                           /* the same key: replace */
            break;
        }
        if (!slot && !e->valid) {
            slot = e;
        }
    }
    if (!slot) {
        slot = &env->acache[env->acache_next++ % PDP64_ACACHE_N];
    }
    *slot = (struct PDP64ACache){ .valid = true, .global = global,
        .tag = cur_tag(env), .asid = env->c.asid & 0xffff, .idx = mmu_idx,
        .vpn = addr >> MMU_PAGE_BITS, .pa = pa, .prot = prot, .size = size };
}

/* the ops of the executor's tlb hook on the cache: TLBI (a page of the current address space and the global entries of the tag in GTBR), TLBIA and the writes to PTBR,
   ASID, MMUCTL (every entry of the tag in GTBR), a write to GTBR that changes the root or the enable bit (every entry of the tag written, in addr) */
void pdp64_acache_flush(CPUPDP64State *env, int op, uint64_t addr)
{
    uint16_t tag = op == PDP64_TLB_GTBR ? (addr >> GTBR_TAG) & ((1u << GTBR_WIDTH_TAG) - 1)
                                        : cur_tag(env);
    unsigned i;

    for (i = 0; i < PDP64_ACACHE_N; i++) {
        struct PDP64ACache *e = &env->acache[i];

        if (!e->valid || e->tag != tag) {
            continue;
        }
        if (op == PDP64_TLB_PAGE && !(e->vpn == addr >> MMU_PAGE_BITS
            && (e->global || e->asid == (env->c.asid & 0xffff)))) {
            continue;
        }
        e->valid = false;
    }
}

/* ---- the walk ---- */

/* one page-table entry of stage 1: its address is a guest-physical address of a guest with stage 2 on */
static bool read_s1_pte(CPUPDP64State *env, bool s2, uint64_t gaddr,
                        MMUAccessType type, uint64_t *pte, int *fault_vector)
{
    MemTxResult res;
    hwaddr pa = gaddr;

    if (s2 && !pdp64_s2_translate(env, gaddr, MMU_DATA_LOAD, XFLAG_WALK_BIT, &pa)) {
        *fault_vector = s2_vector(type);
        return false;
    }
    *pte = address_space_ldq_le(&address_space_memory, pa,
                                MEMTXATTRS_UNSPECIFIED, &res);
    if (res != MEMTX_OK) {
        *fault_vector = VECTOR_BUSFAULT;
        return false;
    }
    return true;
}

static bool mmu_walk(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                     int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                     int *fault_vector, bool *global)
{
    bool s2 = mmu_idx >= PDP64_MMU_GUEST;
    int s1idx = s2 ? mmu_idx - PDP64_MMU_GUEST : mmu_idx;
    bool kernel = s1idx == PDP64_MMU_KERNEL || s1idx == PDP64_MMU_KERNEL_GUARD;
    bool guard = s1idx == PDP64_MMU_KERNEL_GUARD;
    uint64_t table = env->c.ptbr & PA_MASK & ~((1ULL << MMU_PAGE_BITS) - 1);
    uint64_t pte = 0;
    uint64_t gpa;
    vaddr page = addr & TARGET_PAGE_MASK;
    int level, shift = 0, rights = 0, s2rights = PAGE_READ | PAGE_WRITE | PAGE_EXEC, s2shift;
    hwaddr out;

    *global = false;
    if (s1idx == PDP64_MMU_PHYS) {
        /* a guest with its translation off: guest-physical = guest-virtual; stage 2 only */
        if (!s2_walk(env, addr, type, 0, &out, &s2rights, &s2shift)) {
            *fault_vector = s2_vector(type);
            return false;
        }
        *pa = out & ~(hwaddr)(TARGET_PAGE_SIZE - 1);
        *prot = s2rights;
        *size = 1ULL << s2shift;
        return true;
    }

    /* bits 63 to 39 must equal bit 38 */
    if ((uint64_t)((int64_t)(addr << (64 - MMU_VA_BITS)) >> (64 - MMU_VA_BITS))
        != addr) {
        *fault_vector = VECTOR_NONCANONICAL;
        return false;
    }
    for (level = MMU_LEVELS - 1; level >= 0; level--) {
        uint64_t idx;

        shift = MMU_PAGE_BITS + MMU_LEVEL_BITS * level;
        idx = (addr >> shift) & (LEVEL_ENTRIES - 1);
        if (!read_s1_pte(env, s2, table + idx * 8, type, &pte, fault_vector)) {
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

    /* the memory type must agree with the space bit of the physical address (errata 65, proposed) */
    if (!pdp64_pte_space_ok(pte)) {
        *fault_vector = protection_vector(type);
        return false;
    }

    /* the rights in this mode: user needs U; the kernel may read and write
       U pages but never execute them, and with UA clear (guard) it may not
       touch them with a data access either (errata 43, 190: the protection
       fault of the load or the store; an instruction fetch is the same as
       with UA set) */
    rights = 0;
    if (guard && type != MMU_INST_FETCH && (pte & PTE_BIT(U))) {
        /* no rights */
    } else if (kernel || (pte & PTE_BIT(U))) {
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
    /* beyond the consistency check the memory type MT makes no difference to
       QEMU: whether an address is RAM or a device follows from the address */
    *global = pte & PTE_BIT(G);
    /* the 4 KB page of the access inside the leaf: stage 1's output (a guest-physical address for a guest) */
    gpa = (((pte & PTE_MASK(PPN)) >> PTE_PPN) << MMU_PAGE_BITS)
          + (page & ((1ULL << shift) - 1));
    *size = 1ULL << shift;
    if (s2) {
        /* the output goes through stage 2 once more; the page is the smaller of the two leaves, the rights are the intersection */
        if (!s2_walk(env, gpa | (addr & (TARGET_PAGE_SIZE - 1)), type, 0, &out, &s2rights, &s2shift)) {
            *fault_vector = s2_vector(type);
            return false;
        }
        gpa = out & ~(hwaddr)(TARGET_PAGE_SIZE - 1);
        rights &= s2rights;
        if (s2shift < shift) {
            *size = 1ULL << s2shift;
        }
    }
    *prot = rights;
    *pa = gpa;
    return true;

page_fault:
    *fault_vector = page_fault_vector(type);
    return false;
}

bool pdp64_mmu_translate(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                         int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                         int *fault_vector)
{
    bool global;
    bool cached = env->c.hve && !env->c.h;

    if (cached && acache_lookup(env, addr, type, mmu_idx, pa, prot, size)) {
        return true;
    }
    if (!mmu_walk(env, addr, type, mmu_idx, pa, prot, size, fault_vector, &global)) {
        return false;
    }
    if (cached) {
        acache_insert(env, addr, mmu_idx, *pa, *prot, *size, global);
    }
    return true;
}
