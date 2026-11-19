/*
 * pdp64 CPU state.  The register file, flags, PSW and system registers are
 * struct pdp64_cpu of the shared execution core (gen/pdp64exec.h), embedded
 * as is: the core operates on it directly.
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef PDP64_CPU_H
#define PDP64_CPU_H

#include "cpu-qom.h"
#include "exec/cpu-common.h"
#include "exec/cpu-interrupt.h"
#include "gen/pdp64exec.h"

#define PDP64_ACACHE_N 256

#ifdef CONFIG_USER_ONLY
#error "pdp64 does not support user mode emulation"
#endif

#define EXCP_PDP64_FAULT 0x100  /* legacy machine: report and exit with 139 */
#define EXCP_PDP64_ABORT 0x101  /* kernel mode: an abort, vector ex_vector */

typedef struct CPUArchState {
    struct pdp64_cpu c;         /* r0..r15, pc, PSW, system registers */

    /* Fields up to this point are cleared by a CPU reset */
    struct {} end_reset_fields;

    uint64_t entry;             /* initial pc and sp, set by the board */
    uint64_t initial_sp;
    uint64_t ram_size;          /* physical RAM is [0, ram_size) */
    bool kernel_mode;           /* machine option kernel-mode: System v1 */
    void (*hv_vtimer_update)(void *opaque);  /* the virtual timer's deadline moves: a write to VTOFF (set by the device pdp64-vtimer) */
    void *hv_vtimer;
    bool hve;                   /* machine option hypervisor: the strap HVE (errata 195, 196); needs kernel-mode.  The core starts as the hypervisor (H = 1) */
    const char *fault_what;     /* the fault being reported (legacy machine) */
    uint64_t fault_addr;
    int ex_vector;              /* the abort being delivered */
    uint64_t ex_eva;
    uint32_t irq_lines;         /* bit n: the device line of vector 32 + n is asserted */
    /* the architectural cache of translations of a guest (errata 195, 196; design 1.7, decision 23), keyed by (guest tag, address-space number, mode index, page) and flushed only
       as the architecture says (rules G-a to G-d), beside QEMU's own TLB (which has no tags and is flushed more): a missing invalidate is observable.  Cleared at reset. */
    struct PDP64ACache {
        bool valid, global;
        uint16_t tag, asid;
        uint8_t idx;
        uint64_t vpn, pa;
        int prot;
        uint64_t size;
    } acache[PDP64_ACACHE_N];
    unsigned acache_next;
} CPUPDP64State;

struct ArchCPU {
    CPUState parent_obj;

    CPUPDP64State env;
};

struct PDP64CPUClass {
    CPUClass parent_class;

    DeviceRealize parent_realize;
    ResettablePhases parent_phases;
};

#define CPU_RESOLVING_TYPE TYPE_PDP64_CPU

/* the legacy machine's idea of a mapped address: RAM */
static inline bool pdp64_mapped(const CPUPDP64State *env, uint64_t a, int size)
{
    return a < env->ram_size && size <= env->ram_size - a;
}

/*
 * The QEMU MMU indexes: 0 physical (translation off), 1 kernel with UA set
 * (a data access reaches user pages), 2 the other modes (user, and
 * supervisor, which is treated as user), 3 kernel with UA clear (a data
 * access to a user page is a protection fault: errata 43, 190).  UA is in
 * the index so that STUA and CLUA flush nothing.
 */
enum { PDP64_MMU_PHYS = 0, PDP64_MMU_KERNEL = 1, PDP64_MMU_USER = 2,
       PDP64_MMU_KERNEL_GUARD = 3,
       /* a guest with stage 2 on (GTBR.S2EN, at H = 0): the same four, 4 plus
          the index: translation off (guest-physical = guest-virtual, stage 2
          only) and the three of stage 1 with stage 2 under them */
       PDP64_MMU_GUEST_PHYS = 4, PDP64_MMU_GUEST = 4 };

static inline bool pdp64_s2_on(const CPUPDP64State *env)
{
    return env->c.hve && !env->c.h && (env->c.gtbr & 1);
}

static inline int pdp64_mmu_idx_mode(const CPUPDP64State *env, unsigned mode)
{
    int s2 = pdp64_s2_on(env) ? PDP64_MMU_GUEST : 0;

    if (!env->c.deliver || env->c.h) {
        /* the hypervisor runs untranslated in version 1 (design 1.2 rule 1) */
        return PDP64_MMU_PHYS;
    }
    if (!(env->c.mmuctl & (1u << MMUCTL_ENABLE))) {
        return s2 ? PDP64_MMU_GUEST_PHYS : PDP64_MMU_PHYS;
    }
    if (mode != MODE_KERNEL) {
        return PDP64_MMU_USER + s2;
    }
    return ((env->c.psw >> PSW_UA & 1) ? PDP64_MMU_KERNEL
                                       : PDP64_MMU_KERNEL_GUARD) + s2;
}

/* the index of a data access: a `.U` move (movq.u and the others) is made
   with the privilege of user mode (6.10.4) */
static inline int pdp64_mmu_idx_data(const CPUPDP64State *env)
{
    int k = pdp64_mmu_idx_mode(env, MODE_KERNEL);

    if (env->c.uacc && pdp64_mode(&env->c) == MODE_KERNEL
        && k != PDP64_MMU_PHYS && k != PDP64_MMU_GUEST_PHYS) {
        return pdp64_mmu_idx_mode(env, MODE_USER);
    }
    return pdp64_mmu_idx_mode(env, pdp64_mode(&env->c));
}

void pdp64_translate_init(void);
void pdp64_translate_code(CPUState *cs, TranslationBlock *tb,
                          int *max_insns, vaddr pc, void *host_pc);
void pdp64_cpu_do_interrupt(CPUState *cs);
void pdp64_cpu_dump_state(CPUState *cs, FILE *f, int flags);
void pdp64_report_fault(CPUPDP64State *env, const char *what, uint64_t addr);
void pdp64_stop(CPUPDP64State *env, int code);

/* an abort: with exceptions delivered, vector and EVA; otherwise the report */
G_NORETURN void pdp64_raise(CPUPDP64State *env, int vector, uint64_t eva,
                            const char *what, uintptr_t ra);
/* op_helper.c: the core's entry points with the host's hooks */
void pdp64_enter_abort(CPUPDP64State *env);
bool pdp64_take_interrupt(CPUPDP64State *env, int level, int vector);
/* a virtual interrupt line of the guest above its priority (errata 195, 196; design 1.8) */
bool pdp64_take_virtual(CPUPDP64State *env);
/* interrupt lines: the best asserted line, by level then lowest vector */
bool pdp64_irq_best(const CPUPDP64State *env, int *level, int *vector);
int pdp64_irq_level(int vector);
/* mmu.c: the page-table walk (kernel mode machine, translation on) */
bool pdp64_mmu_translate(CPUPDP64State *env, vaddr addr, MMUAccessType type,
                         int mmu_idx, hwaddr *pa, int *prot, vaddr *size,
                         int *fault_vector);
/* stage 2 alone: a guest-physical address of a guest to the physical address; false with env->c.s2_* set (the exit of design 2.5) */
bool pdp64_s2_translate(CPUPDP64State *env, uint64_t gpa, MMUAccessType type,
                        unsigned flags, hwaddr *pa);
/* the host's side of the invalidates (the ops of the executor's tlb hook), on the architectural cache of the tag in GTBR */
void pdp64_acache_flush(CPUPDP64State *env, int op, uint64_t addr);

#endif
