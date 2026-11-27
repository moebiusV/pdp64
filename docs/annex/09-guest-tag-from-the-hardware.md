## {{#annex-guest-tag}} The guest tag is handed out by the hardware, and a number handed out again is a new generation

**The decision.** The hypervisor does not choose a guest's tag: it writes the register that holds the second-stage root with a request bit set, and the hardware puts the next number of a 16-bit counter into the tag field, after discarding every translation and every IOMMU cache entry that carries that number.

**The problem.** The translation buffer holds finished translations, and a machine that runs several guests needs to tell one guest's entries from another's, or it must empty the buffer at every switch. So each entry carries the **guest tag**, a small number naming the guest it was made for (Arm calls it the VMID, x86 the VPID, RISC-V puts it in `hgatp`). A switch between guests then costs nothing; the entries of the guest that left stay in the buffer for when it returns.

The number has to be unique among the guests that exist, and when a guest is destroyed and its number is given to a new one, the old entries under that number must be gone first. If they are not, the new guest reads through the old guest's translations; this is the stale-translation bug of the arena entry, in another place. Arm's model flushes when the number changes and leaves a reuse of the number to software, as the repository's reading of it records. So the hypervisor ends up running an allocator, and the allocator has to be right under all orders of creation and destruction.

### Before and after

**Before** (OpenBSD `sys/arch/amd64/amd64/vmm_machdep.c`, `vmm_alloc_vpid_vcpu()`; quoted in part):

```
        rw_enter_write(&vmm_softc->vpid_lock);
        ...
        for (i = minasid; i <= sc->max_vpid; i++) {
                idx = i / 8;
                bit = i - (idx * 8);

                if (!(sc->vpids[idx] & (1 << bit))) {
                        sc->vpids[idx] |= (1 << bit);
                        *vpid = i;
                        ...
                        rw_exit_write(&vmm_softc->vpid_lock);
                        return 0;
                }
        }
        printf("%s: no available %ss\n", ...);
```

*(A lock, a bitmap, a search and a matching free routine, `vmm_free_vpid()`, with the invalidation that guest entry does every time because the allocator cannot promise that nothing stale is left: see the arena entry.)*

**After** (pdp64, `snippets/guest-tag.S`, assembled):

```
        lea     hroot, r1                       ; the stage-2 root (one page)
        mov    =(1<<GTBR_S2EN | 1<<GTBR_NEW), r2
        bis     r2, r1
        mtsr    gtbr, r1                        ; entries under the next number are thrown away, then it is handed out
        mfsr    r3, gtbr
        shr     $48, r3                         ; r3 is the guest's tag; the hypervisor never chose it
```

*(Six instructions in all, and no allocator, lock or free routine in the hypervisor.)*

### What it enables

* **A guest created in one write.** The root and the tag change together, so there is no moment when one is new and the other old.
* **A hypervisor with no allocator.** There is nothing to free: a guest that goes away simply stops being given its tag, and the number comes round again when the counter does.
* **A refusal of an invented number.** A write without the request bit whose tag field is neither the host's 0 nor a number the hardware has handed out is refused, so a hypervisor bug that conjures a tag is caught at once.
* **One width everywhere.** The tag is 16 bits in the processor and in the IOMMU, so a device assigned to a guest carries the same tag as the guest's cores.

### What it saves us from

* **The reuse bug**: a number handed out again with entries left under it. By construction a number that comes round is a new generation, because its entries were discarded at the moment it was handed out, in the translation buffer and in the IOMMU.
* **An allocator that exhausts or races**: the OpenBSD allocator above returns an error when no number is free, and takes a lock to avoid two virtual processors choosing the same number; neither case exists here.

### What it costs

A 16-bit counter and a discard by tag at each request: I did not count it separately; the study counted all the hypervisor's parts (the tag allocator among them) at a fraction of a percent to about one percent of the scalar core each.


### What it puts off limits

The hypervisor cannot give two guests one tag to share translations, and cannot choose a number for its own reasons (to match a device's configuration, say).

### Where the manual states it

{{r:gtbr-holds-the-whole}} and {{r:each-translation-buffer-entry}}.
