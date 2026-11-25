## {{#annex-iommu-blocked}} The IOMMU blocked at reset, with no bypass: a device reaches nothing until it is given something

**The decision.** The unit that translates and checks a device's memory accesses (the IOMMU) is blocked at reset, has no bypass or pass-through mode at all, fails closed on any bad table, and refuses a device's write to a system register or to the hypervisor's tables.

**The problem.** On the PDP-11 a disk controller such as the RK11 moved data by itself: the processor gave it a memory address and a word count, and the controller wrote into memory without the processor's help (this is **DMA**, direct memory access). The controller was trusted. On the Unibus there was nothing between it and every word of memory, which was fine because the controllers were the manufacturer's own cards in the owner's own cabinet. Today a card can be a USB-C projector or a power adapter, a card in a virtual machine or a card whose firmware has a flaw. A device that can write anywhere owns the machine.

The cure is a unit between the devices and memory, the **IOMMU**, which does for a device what the KT11 did for a program: it looks up the device in a table, turns the device's addresses into real ones and refuses what the table does not allow. The cure has failed in practice by being optional. The repository's study of DMA attacks records the Thunderclap paper (Markettos and others, NDSS 2019): "We are able to achieve IOMMU bypass within seconds of connecting on vulnerable macOS, FreeBSD, and Linux systems across a range of hardware vendors". The kernel's own documentation for Thunderbolt says the devices "can be DMA masters and thus read contents of the host memory without CPU and OS knowing about it. There are ways to prevent this by setting up an IOMMU but it is not always available for various reasons."

Two features of other designs make "not always available" true. One is a mode that lets a device through untranslated; the repository's reading of the Arm SMMU manual notes that a stream can bypass by configuration and that "a disabled SMMU can pass traffic" (section 3.4), and RISC-V requires its unit to support a "Bare" mode. The other is a driver that turns the unit off when it cannot make it work.

### Before and after

**Before** (OpenBSD, `sys/dev/acpi/acpidmar.c`, its driver for the Intel VT-d unit; quoted):

```
        printf("error.. unable to initialize iommu %d\n", iommu->id);
        iommu->flags |= IOMMU_FLAGS_BAD;

        /* Disable IOMMU */
        iommu->gcmd &= ~GCMD_TE;
        mtx_enter(&iommu->reg_lock);
        iommu_write_4(iommu, DMAR_GCMD_REG, iommu->gcmd);
        mtx_leave(&iommu->reg_lock);
```

*(A unit that cannot be set up is switched off, and then every device sees all memory. The same driver reports `iommu_enabled()` as the translation-enable bit: the protection is a bit that code can clear.)*

**After.** On the pdp64 this code is no longer needed, and cannot be written: a device's entry has a mode field with three values (blocked, one level, two levels), the unit is blocked at reset, and there is no fourth value. A driver that wants a device to see the whole of a 1 GB region gives it a one-leaf table for that region, which the unit still checks.

### What it enables

* **Default deny.** A device with no entry, an entry that is malformed, or an entry with a reserved bit set, reaches nothing. A refused read is answered with an error completion (never all ones and never other memory), and a refused write is dropped, counted and logged in a ring in memory with an interrupt.
* **Safe assignment of a device to a guest.** The unit translates in two levels, one that the guest writes and one that the hypervisor writes, so that a guest can be given a real network card and the card still cannot reach any page the hypervisor did not map.
* **Safe interrupts from devices.** The word a device writes to raise an interrupt carries an index; the unit looks it up in that device's own table of vectors, and a device with no entry raises nothing.
* **A mute bit.** A flooding device can be muted without turning anything off.

### What it saves us from

* **IOMMU bypass** in Thunderclap's sense: there is no mode to bypass into.
* **The unit disabled by the driver** that could not initialise it (above).
* **A device writing the machine's own registers.** My security corpus probe found that a device table mapping a device address onto the timer's compare register let the device write it by DMA; the rule is that the unit checks permissions *and what the target is*: a device never writes a system register or an arena page.
* **Forged interrupts**, for a device with a table of its own vectors.

### What it costs

One table read per translation miss and per interrupt (I could not measure the cost on a real unit's memory system; the tools give gates only). A device that really wants a whole region has to be given a table, not a switch. Devices behind a switch that lets them reach each other directly are invisible to the unit; they form a group that is assigned together.

### What it puts off limits

A driver cannot say "trust this device"; there is no pass-through. A device used from a user program needs a table as well.

### Where the manual states it

{{r:device-is-identified}}, {{r:device-entry-is-32-bytes}}, {{r:unit-refuses-a-device}} and {{r:write-that-raises-a-device}}.
