# Part 5. Virtualization and the IOMMU

## {{#annex-arena}} The arena: a guest never sees a stale translation

**The decision.** The hypervisor tells the hardware where its second-stage tables are (the **arena**, one run of real pages), and the hardware throws away a guest's cached translations whenever those tables may have changed; there is no flush bit for the hypervisor to forget.

**The problem.** A **translation** is the work of turning an address a program uses into an address in memory, by reading tables; the KT11 on the PDP-11 did it with eight pairs of registers. A modern machine caches finished translations in a small fast **translation buffer** (the TLB), so that it need not read the tables on every access. A **hypervisor** is a program that runs whole operating systems (the **guests**) as if each had the machine to itself, and for that it keeps a second set of tables, the **second stage**, mapping what a guest thinks is memory onto real memory. Now suppose the hypervisor resets a guest and gives it new memory, but the buffer still holds the translations made for the old one. The new guest then reads the old guest's pages through a translation that no longer matches any table.

This is a real class of bug. The Linux kernel's hypervisor code (KVM, x86) had one in 2026: the record of CVE-2026-99312 (fetched 2026-11-25 from `cveawg.mitre.org/api/cve/CVE-2026-99312`, published 2026-11-18, assigned by Linux) is titled "Force an MMU reset when emulating an INIT even if paging was already disabled"; the repository's earlier reading of the same record says that without it KVM ran the outer guest "with a stale MMU context". The cause is general: the architecture left it to software to remember to flush.

What software has to do is what OpenBSD's hypervisor (`vmm`) does on x86. Before it enters a guest it asks the processor to forget every translation of that guest, every time.

### Before and after

**Before** (OpenBSD `sys/arch/amd64/amd64/vmm_machdep.c`, `vcpu_run_vmx()`, quoted):

```
        if (vcpu->vc_vmx_vpid_enabled) {
                /* Invalidate old TLB mappings */
                vid.vid_vpid = vcpu->vc_vpid;
                vid.vid_addr = 0;
                invvpid(IA32_VMX_INVVPID_SINGLE_CTX_GLB, &vid);
        }
```

*(Four statements, one privileged instruction, at every guest entry: safe, and slow. A hypervisor that wants speed has to track which tables changed and flush only then, and a mistake in the tracking is the bug above. Arm's hardware flushes on a change of its guest number and leaves a reuse of the number to software, as the repository's reading of the Arm model records.)*

**After** (pdp64, `snippets/arena.S`; the new register names are not yet known to the assembler, see the pilot notes):

```
        lea     arena, r1
        shr     $12, r1
        shl     $28, r1                 ; first page of the arena in bits 55 to 28
        bis     $16, r1                 ; 16 pages in bits 27 to 0
        mtsr    harena, r1
        ...
        mov    r3, (r2)                ; edit a stage-2 entry: an ordinary store into the arena
        genter  $0                      ; the entry discards the guest's translations if it must
```

*(Setup once; then no flush instruction anywhere.)*

### What it enables

* **A fast path that is asked for, not assumed.** With no arena set, every guest entry discards the guest's translations: slow, and right. Setting an arena turns the discard off except when something changed, which the hardware sees. The safe behaviour is what happens when nobody did anything.
* **Edits by ordinary stores.** The hypervisor changes a table entry with a store; the store is the notification. It can write a demand fill (a page given to the guest the first time it touches it) in one instruction.
* **Many cores without a broadcast.** A core that stored into the arena adds one to a word in memory (the **epoch word**) at its next guest entry; a core entering a guest compares the word with the value it last saw, and discards if it differs. No wires run between cores; memory coherence carries the word.
* **A table walker that refuses tables outside the arena**, so no table can be slipped past the watch.

### What it saves us from

* **The stale-MMU-context bug** above, and any like it: the hypervisor cannot forget, because it is never asked.
* **A flush flag that is forgotten.** Hardware that offers a bit on guest entry ("flush now") closes nothing by itself; it adds one more thing for software to remember. This one has no such bit.
* **The race of a table edited on one core and used on another**: the epoch word covers it.
* **A device writing the tables.** The IOMMU refuses any device write to an arena page, and counts it.

### What it costs

The price of the safe default was measured on the repository's first hypervisor test: 48 cycles at each guest entry, which is 3.7% to 12.8% of published null-hypercall round trips on other machines (376 to 1,300 cycles). The hardware is one range comparator and a flag: about 1,300 gates for the core (the comparator alone 1,072), and 747 and 404 gates for the epoch check and increment, independent of the number of cores. On the first hypervisor test the flag was set at 3 of 79 entries.

### What it puts off limits

A hypervisor cannot keep its second-stage tables scattered; they live in one run of pages. A guest already running on another core keeps its translations until it exits; the hypervisor stops it with an interrupt, which always exits.

### Where the manual states it

{{r:guest-never-sees-a-stale}}, with {{r:unit-refuses-a-device}} and {{r:there-is-no-hardware-event}}.
