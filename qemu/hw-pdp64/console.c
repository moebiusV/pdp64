/*
 * pdp64 console (System v1, section 15), in the spirit of the PDP-11 KL11:
 * four 64-bit registers (receive status and data, transmit status and data)
 * on a character device.  Output is instantaneous: TXCS READY is always 1.
 * The input interrupt (VECTOR_CONSOLE_IN) is asserted while RXCS READY and IE,
 * the output interrupt (VECTOR_CONSOLE_OUT) while TXCS IE (and READY); both
 * are at level IRQ_LEVEL_CONSOLE.  The numbers are the generated constants of
 * pdp64-consts.h.
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "hw/core/irq.h"
#include "hw/core/qdev-properties.h"
#include "hw/core/qdev-properties-system.h"
#include "hw/core/sysbus.h"
#include "chardev/char-fe.h"
#include "target/pdp64/gen/pdp64-consts.h"

#define TYPE_PDP64_CONSOLE "pdp64-console"
OBJECT_DECLARE_SIMPLE_TYPE(PDP64ConsoleState, PDP64_CONSOLE)

struct PDP64ConsoleState {
    SysBusDevice parent_obj;

    MemoryRegion iomem;
    qemu_irq irq_in, irq_out;
    CharFrontend chr;
    uint8_t rxdb;
    bool rx_ready, rx_ie, tx_ie;
};

#define CSR_IE    (1u << CONSOLE_CSR_IE)
#define CSR_READY (1u << CONSOLE_CSR_READY)

static void console_update(PDP64ConsoleState *s)
{
    qemu_set_irq(s->irq_in, s->rx_ready && s->rx_ie);
    qemu_set_irq(s->irq_out, s->tx_ie);
}

static int console_can_receive(void *opaque)
{
    PDP64ConsoleState *s = opaque;

    return s->rx_ready ? 0 : 1;
}

static void console_receive(void *opaque, const uint8_t *buf, int size)
{
    PDP64ConsoleState *s = opaque;

    if (size > 0 && !s->rx_ready) {
        s->rxdb = buf[0];
        s->rx_ready = true;
        console_update(s);
    }
}

static uint64_t console_read(void *opaque, hwaddr addr, unsigned size)
{
    PDP64ConsoleState *s = opaque;
    uint64_t v = 0;

    switch (addr) {
    case CONSOLE_REG_RXCS:
        return (s->rx_ready ? CSR_READY : 0) | (s->rx_ie ? CSR_IE : 0);
    case CONSOLE_REG_RXDB:
        v = s->rxdb;
        if (s->rx_ready) {
            s->rx_ready = false;
            console_update(s);
            qemu_chr_fe_accept_input(&s->chr);
        }
        return v;
    case CONSOLE_REG_TXCS:
        return CSR_READY | (s->tx_ie ? CSR_IE : 0);
    default:
        return 0;
    }
}

static void console_write(void *opaque, hwaddr addr, uint64_t val,
                          unsigned size)
{
    PDP64ConsoleState *s = opaque;
    uint8_t c = val;

    switch (addr) {
    case CONSOLE_REG_RXCS:
        s->rx_ie = val & CSR_IE;
        break;
    case CONSOLE_REG_TXCS:
        s->tx_ie = val & CSR_IE;
        break;
    case CONSOLE_REG_TXDB:
        if (qemu_chr_fe_backend_connected(&s->chr)) {
            qemu_chr_fe_write_all(&s->chr, &c, 1);
        }
        return;
    default:
        return;
    }
    console_update(s);
}

static const MemoryRegionOps console_ops = {
    .read = console_read,
    .write = console_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
    .impl = { .min_access_size = 8, .max_access_size = 8 },
};

static void console_reset(DeviceState *dev)
{
    PDP64ConsoleState *s = PDP64_CONSOLE(dev);

    s->rx_ready = s->rx_ie = s->tx_ie = false;
    console_update(s);
}

static void console_realize(DeviceState *dev, Error **errp)
{
    PDP64ConsoleState *s = PDP64_CONSOLE(dev);
    SysBusDevice *sbd = SYS_BUS_DEVICE(dev);

    memory_region_init_io(&s->iomem, OBJECT(s), &console_ops, s,
                          "pdp64.console", 0x1000);
    sysbus_init_mmio(sbd, &s->iomem);
    sysbus_init_irq(sbd, &s->irq_in);
    sysbus_init_irq(sbd, &s->irq_out);
    qemu_chr_fe_set_handlers(&s->chr, console_can_receive, console_receive,
                             NULL, NULL, s, NULL, true);
}

static const Property console_properties[] = {
    DEFINE_PROP_CHR("chardev", PDP64ConsoleState, chr),
};

static void console_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);

    dc->realize = console_realize;
    device_class_set_props(dc, console_properties);
    device_class_set_legacy_reset(dc, console_reset);
}

static const TypeInfo console_info = {
    .name = TYPE_PDP64_CONSOLE,
    .parent = TYPE_SYS_BUS_DEVICE,
    .instance_size = sizeof(PDP64ConsoleState),
    .class_init = console_class_init,
};

static void console_register_types(void)
{
    type_register_static(&console_info);
}

type_init(console_register_types)
