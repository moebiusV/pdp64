/*
 * QEMU pdp64 CPU
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "qemu/qemu-print.h"
#include "qapi/error.h"
#include "cpu.h"
#include "exec/cputlb.h"
#include "exec/page-protection.h"
#include "exec/translation-block.h"
#include "exec/target_page.h"
#include "hw/core/sysemu-cpu-ops.h"
#include "accel/tcg/cpu-ops.h"
#include "accel/tcg/cpu-loop.h"
#include "tcg/debug-assert.h"
#include "hw/core/qdev.h"
#include "hw/core/irq.h"
#include "system/address-spaces.h"

static void pdp64_cpu_set_pc(CPUState *cs, vaddr value)
{
    cpu_env(cs)->c.pc = value;
}

static vaddr pdp64_cpu_get_pc(CPUState *cs)
{
    return cpu_env(cs)->c.pc;
}

static TCGTBCPUState pdp64_get_tb_cpu_state(CPUState *cs)
{
    /* the translation depends on the mode: a block is found per MMU index */
    CPUPDP64State *env = cpu_env(cs);

    return (TCGTBCPUState){ .pc = env->c.pc,
                            .flags = pdp64_mmu_idx_mode(env, pdp64_mode(&env->c)) };
}

static void pdp64_cpu_synchronize_from_tb(CPUState *cs,
                                          const TranslationBlock *tb)
{
    tcg_debug_assert(!tcg_cflags_has(cs, CF_PCREL));
    cpu_env(cs)->c.pc = tb->pc;
}

static void pdp64_restore_state_to_opc(CPUState *cs,
                                       const TranslationBlock *tb,
                                       const uint64_t *data)
{
    cpu_env(cs)->c.pc = data[0];
}

/* an asserted device line above the priority of the PSW (the core's rule) */
static bool pdp64_irq_deliverable(CPUPDP64State *env, int *level, int *vector)
{
    return env->c.deliver && pdp64_irq_best(env, level, vector)
           && *level > (int)pdp64_priority(&env->c);
}

static bool pdp64_cpu_has_work(CPUState *cs)
{
    CPUPDP64State *env = cpu_env(cs);
    int level, vector;

    return (cs->interrupt_request & CPU_INTERRUPT_HARD)
           && pdp64_irq_deliverable(env, &level, &vector);
}

static bool pdp64_cpu_exec_interrupt(CPUState *cs, int interrupt_request)
{
    CPUPDP64State *env = cpu_env(cs);
    int level, vector;

    if ((interrupt_request & CPU_INTERRUPT_HARD)
        && pdp64_irq_deliverable(env, &level, &vector)) {
        return pdp64_take_interrupt(env, level, vector);
    }
    return false;
}

/* a device line of the vector 32 + n goes up or down */
static void pdp64_cpu_set_irq(void *opaque, int n, int level)
{
    PDP64CPU *cpu = opaque;
    CPUState *cs = CPU(cpu);
    CPUPDP64State *env = &cpu->env;

    if (level) {
        env->irq_lines |= 1u << n;
    } else {
        env->irq_lines &= ~(1u << n);
    }
    if (env->irq_lines) {
        cpu_interrupt(cs, CPU_INTERRUPT_HARD);
    } else {
        cpu_reset_interrupt(cs, CPU_INTERRUPT_HARD);
    }
}

static void pdp64_cpu_instance_init(Object *obj)
{
    qdev_init_gpio_in(DEVICE(obj), pdp64_cpu_set_irq, 32);
}

static int pdp64_cpu_mmu_index(CPUState *cs, bool ifetch)
{
    CPUPDP64State *env = cpu_env(cs);

    return pdp64_mmu_idx_mode(env, pdp64_mode(&env->c));
}

static void pdp64_cpu_reset_hold(Object *obj, ResetType type)
{
    CPUState *cs = CPU(obj);
    PDP64CPUClass *pcc = PDP64_CPU_GET_CLASS(obj);
    CPUPDP64State *env = cpu_env(cs);

    if (pcc->parent_phases.hold) {
        pcc->parent_phases.hold(obj, type);
    }
    memset(env, 0, offsetof(CPUPDP64State, end_reset_fields));
    if (env->kernel_mode) {
        /* System v1: kernel mode, priority 7, translation off, exceptions delivered, no system-call stand-in */
        pdp64_set_psw(&env->c, MODE_KERNEL << PSW_MODE | MODE_KERNEL << PSW_PREV | 7 << PSW_PRI);
        env->c.deliver = 1;
        env->c.standin = 0;
    } else {
        pdp64_set_psw(&env->c, MODE_USER << PSW_MODE | MODE_USER << PSW_PREV);
        env->c.standin = 1;
    }
    env->c.pc = env->entry;
    env->c.r[14] = env->initial_sp;
}

static ObjectClass *pdp64_cpu_class_by_name(const char *cpu_model)
{
    ObjectClass *oc = object_class_by_name(cpu_model);
    char *typename;

    if (oc != NULL && object_class_dynamic_cast(oc, TYPE_PDP64_CPU) != NULL) {
        return oc;
    }
    typename = g_strdup_printf(PDP64_CPU_TYPE_NAME("%s"), cpu_model);
    oc = object_class_by_name(typename);
    g_free(typename);
    return oc;
}

static void pdp64_cpu_realize(DeviceState *dev, Error **errp)
{
    CPUState *cs = CPU(dev);
    PDP64CPUClass *pcc = PDP64_CPU_GET_CLASS(dev);
    Error *local_err = NULL;

    cpu_exec_realizefn(cs, &local_err);
    if (local_err != NULL) {
        error_propagate(errp, local_err);
        return;
    }
    qemu_init_vcpu(cs);
    cpu_reset(cs);
    pcc->parent_realize(dev, errp);
}

static bool pdp64_cpu_tlb_fill(CPUState *cs, vaddr addr, int size,
                               MMUAccessType access_type, int mmu_idx,
                               bool probe, uintptr_t retaddr)
{
    CPUPDP64State *env = cpu_env(cs);
    vaddr page = addr & TARGET_PAGE_MASK;
    hwaddr pa = page;
    int prot = PAGE_READ | PAGE_WRITE | PAGE_EXEC;
    vaddr tsize = TARGET_PAGE_SIZE;
    int vector = 0;

    if (!env->c.deliver) {
        /* the legacy machine: no MMU, physical = virtual, inside RAM only */
        if (!pdp64_mapped(env, page, TARGET_PAGE_SIZE)) {
            if (probe) {
                return false;
            }
            pdp64_raise(env, VECTOR_BUSFAULT, addr,
                        access_type == MMU_INST_FETCH
                        ? "instruction fetch from unmapped memory"
                        : "access to unmapped memory", retaddr);
        }
    } else if (mmu_idx != PDP64_MMU_PHYS) {
        if (!pdp64_mmu_translate(env, page, access_type, mmu_idx, &pa, &prot,
                                 &tsize, &vector)) {
            if (probe) {
                return false;
            }
            pdp64_raise(env, vector, addr, "page fault", retaddr);
        }
        page &= ~(tsize - 1);
    } else if (access_type == MMU_INST_FETCH && !pdp64_mapped(env, page, 1)) {
        /* code is only fetched from RAM */
        if (probe) {
            return false;
        }
        pdp64_raise(env, VECTOR_BUSFAULT, addr, "instruction fetch", retaddr);
    }
    tlb_set_page(cs, page, pa & ~(tsize - 1), prot, mmu_idx, tsize);
    return true;
}

/* an access that reached no device: a bus fault (the vector table says what to do) */
static void pdp64_cpu_do_transaction_failed(CPUState *cs, hwaddr physaddr,
                                            vaddr addr, unsigned size,
                                            MMUAccessType access_type,
                                            int mmu_idx, MemTxAttrs attrs,
                                            MemTxResult response,
                                            uintptr_t retaddr)
{
    pdp64_raise(cpu_env(cs), VECTOR_BUSFAULT, addr,
                "access to unmapped memory", retaddr);
}

static hwaddr pdp64_cpu_get_phys_addr_debug(CPUState *cs, vaddr addr)
{
    return pdp64_mapped(cpu_env(cs), addr, 1) ? addr : -1;
}

static const struct SysemuCPUOps pdp64_sysemu_ops = {
    .has_work = pdp64_cpu_has_work,
    .get_phys_addr_debug = pdp64_cpu_get_phys_addr_debug,
};

static const TCGCPUOps pdp64_tcg_ops = {
    .guest_default_memory_order = TCG_MO_ALL,
    .mttcg_supported = false,

    .initialize = pdp64_translate_init,
    .translate_code = pdp64_translate_code,
    .get_tb_cpu_state = pdp64_get_tb_cpu_state,
    .synchronize_from_tb = pdp64_cpu_synchronize_from_tb,
    .restore_state_to_opc = pdp64_restore_state_to_opc,
    .mmu_index = pdp64_cpu_mmu_index,
    .tlb_fill = pdp64_cpu_tlb_fill,
    .do_transaction_failed = pdp64_cpu_do_transaction_failed,
    .pointer_wrap = cpu_pointer_wrap_notreached,

    .cpu_exec_interrupt = pdp64_cpu_exec_interrupt,
    .cpu_exec_halt = pdp64_cpu_has_work,
    .cpu_exec_reset = cpu_reset,
    .do_interrupt = pdp64_cpu_do_interrupt,
};

static void pdp64_cpu_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);
    CPUClass *cc = CPU_CLASS(klass);
    PDP64CPUClass *pcc = PDP64_CPU_CLASS(klass);
    ResettableClass *rc = RESETTABLE_CLASS(klass);

    device_class_set_parent_realize(dc, pdp64_cpu_realize,
                                    &pcc->parent_realize);
    resettable_class_set_parent_phases(rc, NULL, pdp64_cpu_reset_hold, NULL,
                                       &pcc->parent_phases);

    cc->class_by_name = pdp64_cpu_class_by_name;
    cc->dump_state = pdp64_cpu_dump_state;
    cc->set_pc = pdp64_cpu_set_pc;
    cc->get_pc = pdp64_cpu_get_pc;
    cc->sysemu_ops = &pdp64_sysemu_ops;
    cc->tcg_ops = &pdp64_tcg_ops;
}

static const TypeInfo pdp64_cpu_types[] = {
    {
        .name = TYPE_PDP64_CPU,
        .parent = TYPE_CPU,
        .instance_size = sizeof(PDP64CPU),
        .instance_align = __alignof(PDP64CPU),
        .abstract = true,
        .instance_init = pdp64_cpu_instance_init,
        .class_size = sizeof(PDP64CPUClass),
        .class_init = pdp64_cpu_class_init,
    }, {
        .name = TYPE_PDP64_BASE_CPU,
        .parent = TYPE_PDP64_CPU,
    },
};

DEFINE_TYPES(pdp64_cpu_types)
