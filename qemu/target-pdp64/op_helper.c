/*
 * pdp64: the one helper.  Every instruction is executed by pdp64_step() of
 * the shared core (gen/pdp64exec.c); this file is the host's side of it:
 * memory through QEMU's access functions, faults, and the system call
 * stand-in (trap #n, halt) of sim64.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "cpu.h"
#include "exec/helper-proto.h"
#include "accel/tcg/cpu-ldst.h"
#include "accel/tcg/cpu-loop.h"

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

static void check(struct hostctx *h, uint64_t a, int size)
{
    if (size > 1 && (a & (size - 1))) {
        do_fault(h, "misaligned data access", a);
    }
    if (!pdp64_mapped(h->env, a, size)) {
        do_fault(h, "access to unmapped memory", a);
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

static int h_probe(void *u, uint64_t a, int write, int mode)
{
    struct hostctx *h = u;

    return pdp64_mapped(h->env, a, 1);
}

static uint64_t h_fetch(void *u, uint64_t a)
{
    return h_ld(u, a, 2);
}

static int h_vecread(void *u, uint64_t pa, uint64_t *v)
{
    return 1;                   /* no vector table without kernel mode */
}

static void h_tlb(void *u, int op, uint64_t a)
{
}

static G_NORETURN void h_raise(void *u, int vector, uint64_t eva)
{
    do_fault(u, "exception", eva);
}

void helper_exec(CPUPDP64State *env)
{
    static bool inited;
    struct hostctx h = { env, GETPC() };
    struct pdp64_env e = { h_ld, h_st, h_fault, h_trap, h_halt, h_probe, h_fetch,
                           h_vecread, h_tlb, h_raise, &h };

    if (!inited) {
        pdp64_init();
        inited = true;
    }
    pdp64_step(&env->c, &e);
}
