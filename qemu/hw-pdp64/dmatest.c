/*
 * pdp64-dmatest: a small PCI function that does DMA and tells the program what the memory system answered (errata 194).
 *
 * QEMU's own test device (edu) ignores the result of its DMA, so a refused read cannot be seen through it.  This function has registers for a source and a
 * destination device address, a length, a control and a status register, a result register, and a buffer of its own that the processor reads and writes.
 * One transfer runs at once, when the control register is written, through the PCI address space of the function: so the IOMMU of the root complex
 * (iommu.c) is in the path.  A read that fails leaves the buffer alone and sets ERROR and RESULT; a posted write has no answer, so the function sees no
 * error (the unit counts the refusal).  The interrupt is PCI pin A.  The register offsets and bits are the generated constants of pdp64-consts.h
 * (spec/grammars.d/51-iommu-v1.hbnf, the rules dmatest-*).
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "hw/pci/pci.h"
#include "hw/pci/pci_device.h"
#include "migration/vmstate.h"
#include "qom/object.h"
#include "target/pdp64/gen/pdp64-consts.h"

#define TYPE_PDP64_DMATEST "pdp64-dmatest"
OBJECT_DECLARE_SIMPLE_TYPE(DmatestState, PDP64_DMATEST)

struct DmatestState {
    PCIDevice parent_obj;

    MemoryRegion mmio;
    uint64_t src, dst, len, status, result, irq;
    uint8_t buffer[DMATEST_MAP_BUFFER_SIZE];
};

static void dmatest_update_irq(DmatestState *s)
{
    bool on = (s->irq & (1u << DMATEST_IRQ_ENABLE))
              && (s->status & ((1u << DMATEST_STATUS_DONE) | (1u << DMATEST_STATUS_ERROR)));

    pci_set_irq(&s->parent_obj, on);
}

static void dmatest_run(DmatestState *s, bool write)
{
    PCIDevice *pdev = &s->parent_obj;
    uint64_t len = s->len;

    if (len > DMATEST_MAP_BUFFER_SIZE) {
        len = DMATEST_MAP_BUFFER_SIZE;
    }
    if (write) {
        /* a posted write: nothing comes back, so the function cannot know whether it arrived */
        (void)pci_dma_write(pdev, s->dst, s->buffer, len);
    } else {
        uint8_t tmp[DMATEST_MAP_BUFFER_SIZE];
        MemTxResult r = pci_dma_read(pdev, s->src, tmp, len);

        s->result = r;
        if (r == MEMTX_OK) {
            memcpy(s->buffer, tmp, len);
        } else {
            s->status |= 1u << DMATEST_STATUS_ERROR;    /* the buffer stays as it was: the data of an error completion is not used */
        }
    }
    s->status |= 1u << DMATEST_STATUS_DONE;
    dmatest_update_irq(s);
}

static uint64_t dmatest_read(void *opaque, hwaddr addr, unsigned size)
{
    DmatestState *s = opaque;
    uint64_t v = 0;

    if (addr >= DMATEST_MAP_BUFFER) {
        uint64_t off = addr - DMATEST_MAP_BUFFER;

        if (off + size <= DMATEST_MAP_BUFFER_SIZE) {
            memcpy(&v, s->buffer + off, size);          /* the buffer is little endian, as are the registers (a little endian host) */
        }
        return v;
    }
    switch (addr) {
    case DMATEST_REG_ID:      return DMATEST_ID_MAGIC;
    case DMATEST_REG_SRC:     return s->src;
    case DMATEST_REG_DST:     return s->dst;
    case DMATEST_REG_LEN:     return s->len;
    case DMATEST_REG_CONTROL: return 0;
    case DMATEST_REG_STATUS:  return s->status;
    case DMATEST_REG_RESULT:  return s->result;
    case DMATEST_REG_IRQ:     return s->irq;
    default:                  return 0;
    }
}

static void dmatest_write(void *opaque, hwaddr addr, uint64_t val, unsigned size)
{
    DmatestState *s = opaque;

    if (addr >= DMATEST_MAP_BUFFER) {
        uint64_t off = addr - DMATEST_MAP_BUFFER;

        if (off + size <= DMATEST_MAP_BUFFER_SIZE) {
            memcpy(s->buffer + off, &val, size);
        }
        return;
    }
    switch (addr) {
    case DMATEST_REG_SRC:     s->src = val; break;
    case DMATEST_REG_DST:     s->dst = val; break;
    case DMATEST_REG_LEN:     s->len = val; break;
    case DMATEST_REG_CONTROL:
        if (val & (1u << DMATEST_CTL_START)) {
            dmatest_run(s, val & (1u << DMATEST_CTL_WRITE));
        }
        break;
    case DMATEST_REG_STATUS:                            /* write one to clear */
        s->status &= ~val;
        dmatest_update_irq(s);
        break;
    case DMATEST_REG_IRQ:
        s->irq = val & (1u << DMATEST_IRQ_ENABLE);
        dmatest_update_irq(s);
        break;
    default:
        break;
    }
}

static const MemoryRegionOps dmatest_ops = {
    .read = dmatest_read,
    .write = dmatest_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = { .min_access_size = 1, .max_access_size = 8 },
    .impl = { .min_access_size = 1, .max_access_size = 8 },
};

static void dmatest_realize(PCIDevice *pdev, Error **errp)
{
    DmatestState *s = PDP64_DMATEST(pdev);

    pci_config_set_interrupt_pin(pdev->config, 1);
    memory_region_init_io(&s->mmio, OBJECT(s), &dmatest_ops, s, "pdp64-dmatest-mmio", DMATEST_MAP_BAR_SIZE);
    pci_register_bar(pdev, 0, PCI_BASE_ADDRESS_SPACE_MEMORY | PCI_BASE_ADDRESS_MEM_TYPE_64, &s->mmio);
}

static void dmatest_reset(DeviceState *dev)
{
    DmatestState *s = PDP64_DMATEST(dev);

    s->src = s->dst = s->len = s->status = s->result = s->irq = 0;
    memset(s->buffer, 0, sizeof(s->buffer));
    dmatest_update_irq(s);
}

static void dmatest_class_init(ObjectClass *klass, const void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);
    PCIDeviceClass *k = PCI_DEVICE_CLASS(klass);

    k->realize = dmatest_realize;
    k->vendor_id = DMATEST_ID_VENDOR;
    k->device_id = DMATEST_ID_DEVICE;
    k->revision = 1;
    k->class_id = PCI_CLASS_OTHERS;
    device_class_set_legacy_reset(dc, dmatest_reset);
    set_bit(DEVICE_CATEGORY_MISC, dc->categories);
    dc->desc = "pdp64 DMA test function (errata 194)";
}

static const TypeInfo dmatest_info = {
    .name = TYPE_PDP64_DMATEST,
    .parent = TYPE_PCI_DEVICE,
    .instance_size = sizeof(DmatestState),
    .class_init = dmatest_class_init,
    .interfaces = (const InterfaceInfo[]) {
        { INTERFACE_CONVENTIONAL_PCI_DEVICE },
        { },
    },
};

static void dmatest_register_types(void)
{
    type_register_static(&dmatest_info);
}

type_init(dmatest_register_types)
