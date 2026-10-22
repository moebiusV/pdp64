/*
 * pdp64: the one helper.  Every instruction is executed by pdp64_step() of
 * the shared core (gen/pdp64exec.c); this file is the host's side of it:
 * memory through QEMU's access functions, faults, the system call stand-in
 * (trap #n, halt) of sim64 for the legacy machine, and for the kernel-mode
 * machine the exception and interrupt entry points.
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "cpu.h"
#include "exec/helper-proto.h"
#include "exec/cputlb.h"
#include "accel/tcg/cpu-ldst.h"
#include "accel/tcg/cpu-loop.h"
#include "accel/tcg/probe.h"
#include "system/address-spaces.h"
#include "exec/memop.h"
#include "exec/tlb-flags.h"
#include "system/memory.h"

struct hostctx {
    CPUPDP64State *env;
    uintptr_t ra;
};

static G_NORETURN void do_fault(struct hostctx *h, const char *what,
                                uint64_t addr)
{
    pdp64_report_fault(h->env, what, addr);
    cpu_loop_exit_restore(env_cpu(h->env), h->ra);
}

G_NORETURN void pdp64_raise(CPUPDP64State *env, int vector, uint64_t eva,
                            const char *what, uintptr_t ra)
{
    CPUState *cs = env_cpu(env);

    if (env->c.deliver) {
        env->ex_vector = vector;
        env->ex_eva = eva;
        cs->exception_index = EXCP_PDP64_ABORT;
    } else {
        env->fault_what = what;
        env->fault_addr = eva;
        cs->exception_index = EXCP_PDP64_FAULT;
    }
    cpu_loop_exit_restore(cs, ra);
}

static void check(struct hostctx *h, uint64_t a, int size)
{
    if (size > 1 && (a & (size - 1))) {
        pdp64_raise(h->env, VECTOR_MISALIGNED, a, "misaligned data access",
                    h->ra);
    }
    /* the legacy machine has RAM and nothing else; the kernel-mode machine
       has a bus (an unassigned address is a bus fault: tlb_fill, do_transaction_failed) */
    if (!h->env->c.deliver && !pdp64_mapped(h->env, a, size)) {
        pdp64_raise(h->env, VECTOR_BUSFAULT, a, "access to unmapped memory",
                    h->ra);
    }
}

static uint64_t h_ld(void *u, uint64_t a, int size)
{
    struct hostctx *h = u;

    check(h, a, size);
    switch (size) {
    case 1: return cpu_ldub_data_ra(h->env, a, h->ra);
    case 2: return cpu_lduw_le_data_ra(h->env, a, h->ra);
    case 4: return cpu_ldl_le_data_ra(h->env, a, h->ra);
    default: return cpu_ldq_le_data_ra(h->env, a, h->ra);
    }
}

static void h_st(void *u, uint64_t a, int size, uint64_t v)
{
    struct hostctx *h = u;

    check(h, a, size);
    switch (size) {
    case 1: cpu_stb_data_ra(h->env, a, v, h->ra); break;
    case 2: cpu_stw_le_data_ra(h->env, a, v, h->ra); break;
    case 4: cpu_stl_le_data_ra(h->env, a, v, h->ra); break;
    default: cpu_stq_le_data_ra(h->env, a, v, h->ra); break;
    }
}

static G_NORETURN void h_fault(void *u, const char *what, uint64_t addr)
{
    do_fault(u, what, addr);
}

static void h_trap(void *u, int n)
{
    struct hostctx *h = u;
    uint64_t *r = h->env->c.r;

    switch (n) {
    case 0:
        pdp64_stop(h->env, r[0] & 255);
        break;
    case 1: {
        uint64_t a = r[1], len = r[2];
        for (uint64_t i = 0; i < len; i++) {
            uint8_t c = h_ld(u, a + i, 1);
            if (write((int)r[0], &c, 1) != 1) {
                break;
            }
        }
        r[0] = len;
        break;
    }
    case 2: {
        uint64_t a = r[1], len = r[2];
        uint8_t *tmp = g_malloc(len + 1);
        ssize_t got = read((int)r[0], tmp, len);
        for (ssize_t i = 0; i < got; i++) {
            h_st(u, a + i, 1, tmp[i]);
        }
        g_free(tmp);
        r[0] = (uint64_t)got;
        break;
    }
    default:
        do_fault(h, "unknown system call", n);
    }
}

static void h_halt(void *u)
{
    struct hostctx *h = u;

    pdp64_stop(h->env, h->env->c.r[0] & 255);
}

/* prober / probew: may the code in this mode read (write) the address? */
static int h_probe(void *u, uint64_t a, int write, int mode)
{
    struct hostctx *h = u;
    void *host;
    int idx;

    if (!h->env->c.deliver) {
        return pdp64_mapped(h->env, a, 1);
    }
    idx = pdp64_mmu_idx_mode(h->env, mode);
    return !(probe_access_flags(h->env, a, 1,
                                write ? MMU_DATA_STORE : MMU_DATA_LOAD, idx,
                                true, &host, 0) & TLB_INVALID_MASK);
}

/* one parcel of an instruction: through the instruction-fetch path of the MMU */
static uint64_t h_fetch(void *u, uint64_t a)
{
    struct hostctx *h = u;

    if (!h->env->c.deliver) {
        return h_ld(u, a, 2);
    }
    if (a & 1) {
        pdp64_raise(h->env, VECTOR_MISALIGNED, a, "misaligned fetch", h->ra);
    }
    return cpu_ldw_code_mmu(h->env, a,
        make_memop_idx(MO_LEUW,
                       pdp64_mmu_idx_mode(h->env, pdp64_mode(&h->env->c))),
        h->ra);
}

/* the vector table is read at a physical address */
static int h_vecread(void *u, uint64_t pa, uint64_t *v)
{
    MemTxResult res;

    *v = address_space_ldq_le(&address_space_memory, pa,
                              MEMTXATTRS_UNSPECIFIED, &res);
    return res != MEMTX_OK;
}

static void h_check(void *u, uint64_t a, int size, int write)
{
    struct hostctx *h = u;

    check(h, a, size);
    probe_access(h->env, a, size, write ? MMU_DATA_STORE : MMU_DATA_LOAD,
                 pdp64_mmu_idx_mode(h->env, pdp64_mode(&h->env->c)), h->ra);
}

static void h_tlb(void *u, int op, uint64_t a)
{
    struct hostctx *h = u;

    if (op == PDP64_TLB_PAGE) {
        tlb_flush_page(env_cpu(h->env), a);
    } else {
        tlb_flush(env_cpu(h->env));
    }
}

static G_NORETURN void h_raise(void *u, int vector, uint64_t eva)
{
    struct hostctx *h = u;

    pdp64_raise(h->env, vector, eva, "exception", h->ra);
}

static void make_env(struct pdp64_env *e, struct hostctx *h)
{
    *e = (struct pdp64_env){ h_ld, h_st, h_fault, h_trap, h_halt, h_probe,
                             h_fetch, h_vecread, h_check, h_tlb, h_raise, h };
}

static void init_core(void)
{
    static bool inited;

    if (!inited) {
        pdp64_init();
        inited = true;
    }
}

void helper_exec(CPUPDP64State *env)
{
    struct hostctx h = { env, GETPC() };
    struct pdp64_env e;
    CPUState *cs = env_cpu(env);
    unsigned pri = pdp64_priority(&env->c);

    init_core();
    make_env(&e, &h);
    pdp64_step(&env->c, &e);
    if (pdp64_priority(&env->c) < pri && env->irq_lines) {
        /* the priority fell (spl, mtps, rti, popx...) with a request asserted: leave the chain of translation blocks so that cpu_exec_interrupt looks at it */
        cpu_exit(cs);
    }
    if (env->c.wait) {          /* wfe: sleep until an interrupt is taken */
        cs->halted = 1;
        cs->exception_index = EXCP_HLT;
        cpu_loop_exit(cs);
    }
}

/* the host unwound with an abort: the core undoes the instruction and enters */
void pdp64_enter_abort(CPUPDP64State *env)
{
    struct hostctx h = { env, 0 };
    struct pdp64_env e;

    init_core();
    make_env(&e, &h);
    pdp64_exception(&env->c, &e, env->ex_vector, env->ex_eva);
}

bool pdp64_take_interrupt(CPUPDP64State *env, int level, int vector)
{
    struct hostctx h = { env, 0 };
    struct pdp64_env e;

    init_core();
    make_env(&e, &h);
    return pdp64_interrupt(&env->c, &e, level, vector);
}
