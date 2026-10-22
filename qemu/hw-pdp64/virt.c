/*
 * pdp64-virt: a minimal pdp64 machine.
 *
 *   0x00000000 .. ram_size    RAM (default 128 MiB, -m; at most 256 MiB)
 *   0x10000000 .. 0x1fffffff  reserved for devices (none yet)
 *
 * No MMU: addresses are physical.  -kernel loads an ELF executable (as made
 * by ld64) and starts at its entry point; r14 (sp) is the top of RAM minus
 * a page.
 * SPDX-License-Identifier: GPL-2.0-or-later
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
#include "target/pdp64/cpu.h"

#define PDP64_DEV_BASE 0x10000000ULL

static void pdp64_virt_init(MachineState *machine)
{
    MemoryRegion *sysmem = get_system_memory();
    PDP64CPU *cpu;
    uint64_t entry = 0;

    if (machine->ram_size > PDP64_DEV_BASE) {
        error_report("pdp64-virt: RAM size must be at most 256 MiB");
        exit(1);
    }
    memory_region_add_subregion(sysmem, 0, machine->ram);

    cpu = PDP64_CPU(cpu_create(machine->cpu_type));
    cpu->env.ram_size = machine->ram_size;

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
    cpu->env.initial_sp = machine->ram_size - 4096;
    cpu_reset(CPU(cpu));
}

static void pdp64_virt_class_init(ObjectClass *oc, const void *data)
{
    MachineClass *mc = MACHINE_CLASS(oc);

    mc->desc = "pdp64 virtual machine (RAM at 0, no MMU)";
    mc->init = pdp64_virt_init;
    mc->default_cpu_type = TYPE_PDP64_BASE_CPU;
    mc->default_ram_size = 128 * MiB;
    mc->default_ram_id = "pdp64.ram";
    mc->max_cpus = 1;
    mc->is_default = true;
}

static const TypeInfo pdp64_virt_type = {
    .name = MACHINE_TYPE_NAME("pdp64-virt"),
    .parent = TYPE_MACHINE,
    .class_init = pdp64_virt_class_init,
};

static void pdp64_virt_register_types(void)
{
    type_register_static(&pdp64_virt_type);
}

type_init(pdp64_virt_register_types)
