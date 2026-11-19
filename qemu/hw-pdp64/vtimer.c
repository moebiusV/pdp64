/*
 * pdp64 virtual timer (the hypervisor mode, errata 195, 196; design 1.9, decision 17): the core's own timer page.  It has the three registers of the physical timer (the
 * offsets and the enable and pending bits are the generated constants TIMER_REG_* and TIMER_CTL_* of pdp64-consts.h): a counter that reads the real counter minus VTOFF
 * (the register the hypervisor writes), a compare and the control register that are the guest's.  Its expiry is not an interrupt line: it sets bit 6 of VIRQ (virtual line 6,
 * the line of the timer's level) once, when the counter reaches the compare with the enable bit set; a write to the compare or to the control register arms it again.
 * The hypervisor maps the page into the guest's stage 2 at the guest-physical address where the guest expects its timer; a guest read of the counter then costs no exit.
 *
 * The page belongs to the core.  This machine has one core, so the page is a device of the system bus at MAP_VTIMER; a machine with several cores would give each its own
 * (QEMU lets a CPU have its own memory region, the "memory" link property of the CPU, and a container with the system memory and this page over it).
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "qapi/error.h"
#include "qemu/timer.h"
#include "qemu/main-loop.h"
#include "qemu/host-utils.h"
#include "hw/core/qdev-properties.h"
#include "hw/core/sysbus.h"
#include "migration/vmstate.h"
#include "target/pdp64/cpu.h"

#define TYPE_PDP64_VTIMER "pdp64-vtimer"
OBJECT_DECLARE_SIMPLE_TYPE(PDP64VTimerState, PDP64_VTIMER)

struct PDP64VTimerState {
    SysBusDevice parent_obj;

    MemoryRegion iomem;
    QEMUTimer *timer;
    PDP64CPU *cpu;
    uint64_t compare;
    uint64_t control;
    bool fired;                 /* VIRQ bit 6 was set for this arming */
};

static uint64_t pdp64_vtimer_real(void)
{
    return muldiv64(qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL), TIMER_CLOCK_HZ,
                    NANOSECONDS_PER_SECOND);
}

/* the counter the guest reads: the real counter minus VTOFF, modulo 2^64 */
static uint64_t pdp64_vtimer_counter(PDP64VTimerState *s)
{
    return pdp64_vtimer_real() - s->cpu->env.c.vtoff;
}

/* the expiry: raise the line once, and tell the processor.  Returns whether counter >= compare. */
static bool pdp64_vtimer_update(PDP64VTimerState *s)
{
    CPUPDP64State *env = &s->cpu->env;
    uint64_t now = pdp64_vtimer_counter(s);
    bool pending = now >= s->compare;
    bool enabled = s->control & (1u << TIMER_CTL_ENABLE);

    if (pending && enabled && !s->fired) {
        s->fired = true;
        env->c.virq |= (uint64_t)1 << 6;
        cpu_interrupt(CPU(s->cpu), CPU_INTERRUPT_HARD);
    }
    if (pending || !enabled
        || s->compare - now > (uint64_t)INT64_MAX / (NANOSECONDS_PER_SECOND / TIMER_CLOCK_HZ) - 1) {
        timer_del(s->timer);            /* nothing to wait for, or too far away */
    } else {
        timer_mod(s->timer, qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL)
                  + (s->compare - now) * (NANOSECONDS_PER_SECOND / TIMER_CLOCK_HZ) + 1);
    }
    return pending;
}

static void pdp64_vtimer_fired(void *opaque)
{
    pdp64_vtimer_update(opaque);
}

/* the hypervisor wrote VTOFF: the deadline moves (called from the vCPU thread, outside the big lock) */
static void pdp64_vtimer_vtoff(void *opaque)
{
    PDP64VTimerState *s = opaque;
    bool locked = bql_locked();

    if (!locked) {
        bql_lock();
    }
    pdp64_vtimer_update(s);
    if (!locked) {
        bql_unlock();
    }
}

static uint64_t vtimer_read(void *opaque, hwaddr addr, unsigned size)
{
    PDP64VTimerState *s = opaque;

    switch (addr) {
    case TIMER_REG_COUNTER:
        return pdp64_vtimer_counter(s);
    case TIMER_REG_COMPARE:
        return s->compare;
    case TIMER_REG_CONTROL:
        return (s->control & (1u << TIMER_CTL_ENABLE))
               | ((uint64_t)pdp64_vtimer_update(s) << TIMER_CTL_PENDING);
    default:
        return 0;
    }
}

static void vtimer_write(void *opaque, hwaddr addr, uint64_t val, unsigned size)
{
    PDP64VTimerState *s = opaque;

    switch (addr) {
    case TIMER_REG_COMPARE:
        s->compare = val;
        s->fired = false;
        break;
    case TIMER_REG_CONTROL:
        s->control = val & (1u << TIMER_CTL_ENABLE);
        s->fired = false;
        break;
    default:                    /* the counter is read only */
        return;
    }
    pdp64_vtimer_update(s);
}

static const MemoryRegionOps vtimer_ops = {
    .read = vtimer_read,
    .write = vtimer_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
    .impl = { .min_access_size = 8, .max_access_size = 8 },
};

static void vtimer_reset(DeviceState *dev)
{
    PDP64VTimerState *s = PDP64_VTIMER(dev);

    s->compare = UINT64_MAX;
    s->control = 0;
    s->fired = false;
    timer_del(s->timer);
}

static void vtimer_realize(DeviceState *dev, Error **errp)
{
    PDP64VTimerState *s = PDP64_VTIMER(dev);
    SysBusDevice *sbd = SYS_BUS_DEVICE(dev);

    if (!s->cpu) {
        error_setg(errp, "pdp64-vtimer: the cpu link is not set");
        return;
    }
    memory_region_init_io(&s->iomem, OBJECT(s), &vtimer_ops, s, "pdp64.vtimer",
                          0x1000);
    sysbus_init_mmio(sbd, &s->iomem);
    s->timer = timer_new_ns(QEMU_CLOCK_VIRTUAL, pdp64_vtimer_fired, s);
    s->cpu->env.hv_vtimer_update = pdp64_vtimer_vtoff;
    s->cpu->env.hv_vtimer = s;
}

static const Property vtimer_properties[] = {
    DEFINE_PROP_LINK("cpu", PDP64VTimerState, cpu, TYPE_PDP64_CPU, PDP64CPU *),
};

static void vtimer_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);

    dc->realize = vtimer_realize;
    device_class_set_legacy_reset(dc, vtimer_reset);
    device_class_set_props(dc, vtimer_properties);
}

static const TypeInfo vtimer_info = {
    .name = TYPE_PDP64_VTIMER,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(PDP64VTimerState),
    .class_init = vtimer_class_init,
};

static void vtimer_register_types(void)
{
    type_register_static(&vtimer_info);
}

type_init(vtimer_register_types)
