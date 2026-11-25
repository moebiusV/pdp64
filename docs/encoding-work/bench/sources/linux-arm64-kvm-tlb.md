# Linux: how the kernel and KVM on Arm actually flush translations

**Citation.** The Linux kernel source tree, mainline ("master") as of 2026-11-25, read from the GitHub mirror of the tree (https://raw.githubusercontent.com/torvalds/linux/master/ followed by the path given below). kernel.org's own git viewer answered with a "making sure you're not a bot" challenge page; I stopped using that host and did not try to get around it.
**Date read.** 2026-11-25. Line numbers are not given because they drift; file names and function names are.

## What the files say (short note)

Linux treats the TLB as a cache that the kernel must flush after every page-table change. The Arm KVM code, when it changes a stage-2 entry, follows Arm's break-before-make rule by hand: clear the entry, invalidate by guest-physical address on all processors, wait, then also invalidate all of the guest's stage-1 entries, because the hardware cannot find the combined entries from the guest-physical address alone. The code even says it would do better if it knew the guest-virtual address. The identifier that names a guest to the hardware (the VMID) is handed out with a generation counter: when the identifiers run out, the generation advances and every guest must take a new one, with a flush.

## Quotations

### Documentation/core-api/cachetlb.rst

> "Therefore when software page table changes occur, the kernel will invoke one of the following flush methods _after_ the page table changes occur:"

### arch/arm64/kvm/hyp/nvhe/tlb.c, function `__kvm_tlb_flush_vmid_ipa` (flush one stage-2 translation of a guest)

> "We could do so much better if we had the VA as well."

> "Instead, we invalidate Stage-2 for this IPA, and the whole of Stage-1."

> "a table walk on another CPU could refill a TLB with a complete (S1 + S2) walk based on the old Stage-2 mapping"

(the comment explains why the stage-2 invalidation must be completed (a DSB) before the stage-1 one; the code is `__tlbi_level(ipas2e1is, ...)`, `dsb(ish)`, `__tlbi(vmalle1is)`, `isb()`: the same recipe as Arm's manual.)

### arch/arm64/kvm/hyp/pgtable.c, stage-2 table code

> "Clear the existing PTE, and perform break-before-make if it was valid."

(in `stage2_unmap_put_pte`; the function `stage2_try_break_pte` has the comment "Invalidates a pte according to the 'break-before-make' requirements of the architecture".)

### arch/arm64/kvm/vmid.c, the VMID allocator

> "We're out of VMIDs, so increment the global generation count"

(the allocator is "Based on Arm64 ASID allocator algorithm"; an identifier from an old generation is no longer valid.)
