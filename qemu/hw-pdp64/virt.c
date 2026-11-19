/*
 * pdp64-virt: a minimal pdp64 machine.
 *
 *   0x00000000 .. ram_size    RAM (default 128 MiB, -m; at most 256 MiB)
 *   0x8000000000              timer   (kernel-mode machine only; MAP_TIMER)
 *   0x8000001000              console (kernel-mode machine only; MAP_CONSOLE)
 *   0x8100000000              PCI Express configuration space (ECAM), kernel-mode machine only; MAP_PCIE_ECAM
 *   0x8200000000              PCI Express memory window; MAP_PCIE_MMIO
 *   0x8300000000              PCI Express I/O window; MAP_PCIE_PIO
 *   (bit 39 of the physical address is the space bit: set is device space, clear is memory; errata 60.  The addresses of the PCI Express windows are
 *   provisional, errata 194, J.2.1; every address is taken from the grammar, spec/grammars.d/50-system-v1.hbnf, rule map.)
 *
 * Without kernel-mode there is no MMU: addresses are physical.  -kernel loads an ELF executable (as made
 * by ld64) and starts at its entry point; r14 (sp) is the top of RAM minus
 * a page.
 * SPDX-License-Identifier: BSD-2-Clause
 */
#include "qemu/osdep.h"
#include "qemu/units.h"
#include "qemu/error-report.h"
#include "qapi/error.h"
#include "hw/core/boards.h"
#include "hw/core/loader.h"
#include "hw/core/qdev-properties.h"
#include "system/system.h"
#include "elf.h"
#include "hw/core/sysbus.h"
#include "hw/core/qdev-properties-system.h"
#include "hw/pci-host/gpex.h"
#include "hw/pci/pci.h"
#include "hw/pci/pci_bus.h"
#include "target/pdp64/cpu.h"

#define TYPE_PDP64_VIRT_MACHINE MACHINE_TYPE_NAME("pdp64-virt")

typedef struct PDP64VirtState {
    MachineState parent;

    bool kernel_mode;
} PDP64VirtState;

DECLARE_INSTANCE_CHECKER(PDP64VirtState, PDP64_VIRT_MACHINE,
                         TYPE_PDP64_VIRT_MACHINE)

#define PDP64_RAM_MAX MAP_RAM_MAX

/* The generic PCI Express host bridge of QEMU (hw/pci-host/gpex.c), placed as the RISC-V virt machine places it: the configuration window, the memory
   window (the PCI memory address space is the system address space, so a base address register holds the physical address) and the I/O window.  The four
   interrupt pins go to four lines of the processor.  Returns the root bus. */
static PCIBus *pdp64_virt_pcie_init(MemoryRegion *sysmem, DeviceState *cpu)
{
    DeviceState *dev = qdev_new(TYPE_GPEX_HOST);
    MemoryRegion *ecam_alias = g_new0(MemoryRegion, 1);
    MemoryRegion *mmio_alias = g_new0(MemoryRegion, 1);
    MemoryRegion *reg;
    int i;

    object_property_set_uint(OBJECT(dev), PCI_HOST_ECAM_BASE, MAP_PCIE_ECAM, &error_fatal);
    object_property_set_int(OBJECT(dev), PCI_HOST_ECAM_SIZE, MAP_PCIE_ECAM_SIZE, &error_fatal);
    object_property_set_uint(OBJECT(dev), PCI_HOST_BELOW_4G_MMIO_BASE, MAP_PCIE_MMIO, &error_fatal);
    object_property_set_int(OBJECT(dev), PCI_HOST_BELOW_4G_MMIO_SIZE, MAP_PCIE_MMIO_SIZE, &error_fatal);
    object_property_set_uint(OBJECT(dev), PCI_HOST_PIO_BASE, MAP_PCIE_PIO, &error_fatal);
    object_property_set_int(OBJECT(dev), PCI_HOST_PIO_SIZE, MAP_PCIE_PIO_SIZE, &error_fatal);
    sysbus_realize_and_unref(SYS_BUS_DEVICE(dev), &error_fatal);

    reg = sysbus_mmio_get_region(SYS_BUS_DEVICE(dev), 0);
    memory_region_init_alias(ecam_alias, OBJECT(dev), "pcie-ecam", reg, 0, MAP_PCIE_ECAM_SIZE);
    memory_region_add_subregion(sysmem, MAP_PCIE_ECAM, ecam_alias);
    reg = sysbus_mmio_get_region(SYS_BUS_DEVICE(dev), 1);
    memory_region_init_alias(mmio_alias, OBJECT(dev), "pcie-mmio", reg, MAP_PCIE_MMIO, MAP_PCIE_MMIO_SIZE);
    memory_region_add_subregion(sysmem, MAP_PCIE_MMIO, mmio_alias);
    sysbus_mmio_map(SYS_BUS_DEVICE(dev), 2, MAP_PCIE_PIO);

    for (i = 0; i < PCI_NUM_PINS; i++) {
        sysbus_connect_irq(SYS_BUS_DEVICE(dev), i,
            qdev_get_gpio_in(cpu, VECTOR_PCIE_INTA + i - VECTOR_IRQ_BASE));
        gpex_set_irq_num(GPEX_HOST(dev), i, i);
    }
    return PCI_HOST_BRIDGE(dev)->bus;
}

static void pdp64_virt_init(MachineState *machine)
{
    MemoryRegion *sysmem = get_system_memory();
    PDP64CPU *cpu;
    PDP64VirtState *vs = PDP64_VIRT_MACHINE(machine);
    uint64_t entry = 0;

    if (machine->ram_size > PDP64_RAM_MAX) {
        error_report("pdp64-virt: RAM size must be at most 256 MiB");
        exit(1);
    }
    memory_region_add_subregion(sysmem, 0, machine->ram);

    cpu = PDP64_CPU(cpu_create(machine->cpu_type));
    cpu->env.ram_size = machine->ram_size;
    cpu->env.kernel_mode = vs->kernel_mode;

    if (vs->kernel_mode) {
        DeviceState *dev;

        /* the timer: level IRQ_LEVEL_TIMER, vector VECTOR_TIMER */
        dev = qdev_new("pdp64-timer");
        sysbus_realize_and_unref(SYS_BUS_DEVICE(dev), &error_fatal);
        sysbus_mmio_map(SYS_BUS_DEVICE(dev), 0, MAP_TIMER);
        sysbus_connect_irq(SYS_BUS_DEVICE(dev), 0,
            qdev_get_gpio_in(DEVICE(cpu), VECTOR_TIMER - VECTOR_IRQ_BASE));
        /* the console on the first serial character device */
        dev = qdev_new("pdp64-console");
        qdev_prop_set_chr(dev, "chardev", serial_hd(0));
        sysbus_realize_and_unref(SYS_BUS_DEVICE(dev), &error_fatal);
        sysbus_mmio_map(SYS_BUS_DEVICE(dev), 0, MAP_CONSOLE);
        sysbus_connect_irq(SYS_BUS_DEVICE(dev), 0,
            qdev_get_gpio_in(DEVICE(cpu), VECTOR_CONSOLE_IN - VECTOR_IRQ_BASE));
        sysbus_connect_irq(SYS_BUS_DEVICE(dev), 1,
            qdev_get_gpio_in(DEVICE(cpu), VECTOR_CONSOLE_OUT - VECTOR_IRQ_BASE));
        /* the PCI Express host bridge (errata 194) */
        pdp64_virt_pcie_init(sysmem, DEVICE(cpu));
    }

    if (machine->kernel_filename) {
        uint64_t low, high;
        ssize_t n = load_elf(machine->kernel_filename, NULL, NULL, NULL,
                             &entry, &low, &high, NULL, ELFDATA2LSB,
                             EM_PDP64, 0, 0);
        if (n < 0) {
            error_report("pdp64-virt: could not load '%s' (not a pdp64 ELF "
                         "executable that fits in RAM?)",
                         machine->kernel_filename);
            exit(1);
        }
    }
    cpu->env.entry = entry;
    /* kernel-mode: the kernel bank's stack pointer is the top of RAM; otherwise a user program's, a page below */
    cpu->env.initial_sp = vs->kernel_mode ? machine->ram_size : machine->ram_size - 4096;
    cpu_reset(CPU(cpu));
}

static bool pdp64_virt_get_kernel_mode(Object *obj, Error **errp)
{
    return PDP64_VIRT_MACHINE(obj)->kernel_mode;
}

static void pdp64_virt_set_kernel_mode(Object *obj, bool value, Error **errp)
{
    PDP64_VIRT_MACHINE(obj)->kernel_mode = value;
}

static void pdp64_virt_class_init(ObjectClass *oc, const void *data)
{
    MachineClass *mc = MACHINE_CLASS(oc);

    /* (the property "kernel" is the machine's -kernel file name) */
    object_class_property_add_bool(oc, "kernel-mode",
                                   pdp64_virt_get_kernel_mode,
                                   pdp64_virt_set_kernel_mode);
    object_class_property_set_description(oc, "kernel-mode",
        "System v1: start in kernel mode at priority 7 with exceptions "
        "delivered through the vector table and no system-call stand-in");

    mc->desc = "pdp64 virtual machine (RAM at 0, no MMU)";
    mc->init = pdp64_virt_init;
    mc->default_cpu_type = TYPE_PDP64_BASE_CPU;
    mc->default_ram_size = 128 * MiB;
    mc->default_ram_id = "pdp64.ram";
    mc->max_cpus = 1;
    mc->is_default = true;
}

static const TypeInfo pdp64_virt_type = {
    .name = TYPE_PDP64_VIRT_MACHINE,
    .parent = TYPE_MACHINE,
    .instance_size = sizeof(PDP64VirtState),
    .class_init = pdp64_virt_class_init,
};

static void pdp64_virt_register_types(void)
{
    type_register_static(&pdp64_virt_type);
}

type_init(pdp64_virt_register_types)
