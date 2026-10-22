/*
 * pdp64 timer (System v1, section 15): a 64-bit free-running counter that
 * counts at TIMER_CLOCK_HZ ticks a second of QEMU's virtual clock, a 64-bit
 * compare, and a control/status register.  The interrupt line (level
 * IRQ_LEVEL_TIMER, vector VECTOR_TIMER) is asserted while counter >= compare
 * and the enable bit is set.  The register offsets and bits are the
 * generated constants of pdp64-consts.h.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "qemu/osdep.h"
#include "qemu/timer.h"
#include "qemu/host-utils.h"
#include "hw/core/irq.h"
#include "hw/core/sysbus.h"
#include "migration/vmstate.h"
#include "target/pdp64/gen/pdp64-consts.h"

#define TYPE_PDP64_TIMER "pdp64-timer"
OBJECT_DECLARE_SIMPLE_TYPE(PDP64TimerState, PDP64_TIMER)

struct PDP64TimerState {
    SysBusDevice parent_obj;

    MemoryRegion iomem;
    qemu_irq irq;
    QEMUTimer *timer;
    uint64_t compare;
    uint64_t control;
};

static uint64_t pdp64_timer_counter(void)
{
    return muldiv64(qemu_clock_get_ns(QEMU_CLOCK_VIRTUAL), TIMER_CLOCK_HZ,
                    NANOSECONDS_PER_SECOND);
}

static void pdp64_timer_update(PDP64TimerState *s)
{
    uint64_t now = pdp64_timer_counter();
    bool pending = now >= s->compare;

    qemu_set_irq(s->irq, pending && (s->control & (1u << TIMER_CTL_ENABLE)));
    if (pending || s->compare > (uint64_t)INT64_MAX / (NANOSECONDS_PER_SECOND / TIMER_CLOCK_HZ) - 1) {
        timer_del(s->timer);            /* nothing to wait for, or too far away to be reached */
    } else {
        /* the time at which the counter reaches compare, rounded up */
        uint64_t ns = muldiv64(s->compare, NANOSECONDS_PER_SECOND,
                               TIMER_CLOCK_HZ) + 1;
        timer_mod(s->timer, ns);
    }
}

static void pdp64_timer_fired(void *opaque)
{
    pdp64_timer_update(opaque);
}

static uint64_t timer_read(void *opaque, hwaddr addr, unsigned size)
{
    PDP64TimerState *s = opaque;

    switch (addr) {
    case TIMER_REG_COUNTER:
        return pdp64_timer_counter();
    case TIMER_REG_COMPARE:
        return s->compare;
    case TIMER_REG_CONTROL:
        return (s->control & (1u << TIMER_CTL_ENABLE))
               | ((pdp64_timer_counter() >= s->compare) << TIMER_CTL_PENDING);
    default:
        return 0;
    }
}

static void timer_write(void *opaque, hwaddr addr, uint64_t val, unsigned size)
{
    PDP64TimerState *s = opaque;

    switch (addr) {
    case TIMER_REG_COMPARE:
        s->compare = val;
        break;
    case TIMER_REG_CONTROL:
        s->control = val & (1u << TIMER_CTL_ENABLE);
        break;
    default:                    /* the counter is read only */
        return;
    }
    pdp64_timer_update(s);
}

static const MemoryRegionOps timer_ops = {
    .read = timer_read,
    .write = timer_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
    .impl = { .min_access_size = 8, .max_access_size = 8 },
};

static void timer_reset(DeviceState *dev)
{
    PDP64TimerState *s = PDP64_TIMER(dev);

    s->compare = UINT64_MAX;
    s->control = 0;
    pdp64_timer_update(s);
}

static void timer_realize(DeviceState *dev, Error **errp)
{
    PDP64TimerState *s = PDP64_TIMER(dev);
    SysBusDevice *sbd = SYS_BUS_DEVICE(dev);

    QEMU_BUILD_BUG_ON(NANOSECONDS_PER_SECOND % TIMER_CLOCK_HZ != 0);
    memory_region_init_io(&s->iomem, OBJECT(s), &timer_ops, s, "pdp64.timer",
                          0x1000);
    sysbus_init_mmio(sbd, &s->iomem);
    sysbus_init_irq(sbd, &s->irq);
    s->timer = timer_new_ns(QEMU_CLOCK_VIRTUAL, pdp64_timer_fired, s);
}

static void timer_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);

    dc->realize = timer_realize;
    device_class_set_legacy_reset(dc, timer_reset);
}

static const TypeInfo timer_info = {
    .name = TYPE_PDP64_TIMER,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(PDP64TimerState),
    .class_init = timer_class_init,
};

static void timer_register_types(void)
{
    type_register_static(&timer_info);
}

type_init(timer_register_types)
