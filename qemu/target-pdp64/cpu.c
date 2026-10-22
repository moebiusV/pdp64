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
    return (TCGTBCPUState){ .pc = cpu_env(cs)->c.pc, .flags = 0 };
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

static bool pdp64_cpu_has_work(CPUState *cs)
{
    return false;
}

static bool pdp64_cpu_exec_interrupt(CPUState *cs, int interrupt_request)
{
    return false;       /* no interrupts */
}

static int pdp64_cpu_mmu_index(CPUState *cs, bool ifetch)
{
    return 0;
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
    pdp64_set_psw(&env->c, MODE_USER << PSW_MODE | MODE_USER << PSW_PREV);
    env->c.standin = 1;
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

    /* No MMU: physical = virtual, inside RAM only. */
    if (!pdp64_mapped(env, page, TARGET_PAGE_SIZE)) {
        if (probe) {
            return false;
        }
        env->fault_what = access_type == MMU_INST_FETCH
            ? "instruction fetch from unmapped memory"
            : "access to unmapped memory";
        env->fault_addr = addr;
        cs->exception_index = EXCP_PDP64_FAULT;
        cpu_loop_exit_restore(cs, retaddr);
    }
    tlb_set_page(cs, page, page, PAGE_READ | PAGE_WRITE | PAGE_EXEC,
                 mmu_idx, TARGET_PAGE_SIZE);
    return true;
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
        .class_size = sizeof(PDP64CPUClass),
        .class_init = pdp64_cpu_class_init,
    }, {
        .name = TYPE_PDP64_BASE_CPU,
        .parent = TYPE_PDP64_CPU,
    },
};

DEFINE_TYPES(pdp64_cpu_types)
