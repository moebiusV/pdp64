# Part 2. Translation and the TLB

## {{#annex-stricter-type-wins}} When two stages disagree about a page's memory category, the stricter one wins

**The decision.** Each page says how the memory system may treat it (the **memory type**: cached 0, uncached 1, device weakly ordered 2, device strongly ordered 3), and when a guest's table and the hypervisor's table give different types for one access, the stricter of the two is used. The codes are numbered in the order of strictness, so the stricter is simply the larger number: the type of the access is the maximum of the two.

**The problem.** The PDP-11 had no memory types; everything at the top of the address space was a device and everything else was memory, so a program could not touch a device by treating it as memory. Today a **cache** (a small fast memory holding copies of recently used words) may keep any ordinary page, and that is wrong for a page a device is writing behind the cache's back, or a device's own registers, where a read has an effect. So each page table entry carries a type: **cached** for ordinary memory, **uncached** for a buffer a device shares with the processor, and two **device** types for registers (strongly ordered: every access goes out one at a time, in the order written; weakly ordered: accesses may be combined or reordered).

Under virtualization an access goes through two tables, the guest's and the hypervisor's, and each has a type for the page. The guest wrote its own: it can say "cached" for a page that the hypervisor has mapped onto a device. If the guest's word counts, the guest has broken the hypervisor's protection of the device; if the hypervisor's counts regardless, a guest that really did map memory cached loses all its caching. Arm combines them "by selecting the stage that is more restrictive" (the guide, as the repository's reading quotes it) and then allows the hypervisor to override with a control bit (`FWB`), which is a second mode. RISC-V's page-based memory type (`PBMT`) overrides the platform's own attribute, so that a page table can loosen what the platform fixed: the other design point, and not the safer one.

### Before and after

**Before.** A driver on a machine with cached memory has to repair the damage itself. This is OpenBSD's `if_em.c`, the driver of an Intel network card, before it gives a packet to the card (quoted):

```
        bus_dmamap_sync(sc->sc_dmat, map,
            0, map->dm_mapsize,
            BUS_DMASYNC_PREWRITE);
```

*(One call in the transmit path, one on receive; the repository counts 131 files under `arch/` that mention the cache-flush hooks it ends in. The call is correct only if the memory that the CPU wrote is really the memory the card reads. In a guest, a type the guest chose could make this true or false without the hypervisor knowing.)*

**After** (pdp64; `snippets/memtype.S`, assembled): two leaf entries for the same page, one from the guest's table and one from the hypervisor's.

```
#define LEAF(page, mt) (((page)<<PTE_PPN) | (1<<PTE_V)|(1<<PTE_R)|(1<<PTE_W)|((mt)<<PTE_MT))
        mov    =LEAF(0x1234, MT_CACHED), r1    ; stage 1: written by the guest kernel
        mov    =LEAF(0x8f7, MT_UNCACHED), r2   ; stage 2: written by the hypervisor: a DMA buffer
```

*(The access is uncached: of the two types, the larger code counts (uncached is 1, cached is 0). No call to repair anything, and nothing that the guest wrote can make the page more cached than the hypervisor made it.)*

### What it enables

* **A hypervisor that writes its types once** and relies on them: a DMA buffer mapped uncached stays uncached whatever the guest's table says; a device page mapped as a device stays a device.
* **A guest that is free to be stricter.** A guest may map memory uncached for its own reasons; the hypervisor's "cached" does not loosen it.
* **Atomics that follow the same rule.** An atomic faults on a page that is not ordinary cached memory in *any* stage; the type that the stricter stage gives is the one that counts. So a lock word can never live in a buffer a device writes.
* **One function.** The combination is a small four-by-four table; there is no override mode.

### What it saves us from

* **A guest making a device page cached**, so that its reads came from a stale cache line instead of the device, or its writes were held back: a hole that the review of the first design found, because it left the combining "to the hypervisor".
* **A table that loosens the platform** (`PBMT`'s other design point).
* **An undefined memory type.** David Mosberger of HP (3 October 2001) on `ioremap()`: it "does not clearly define what kind of memory attribute will be used to access the mapped memory (cached, write-through cached, write-coalescing, etc)". The type here is a page attribute stated by the mapper, never inferred.

### What it costs

A few gates and no instruction. A guest that wanted cached access to a page the hypervisor maps uncached gets uncached access, which is slower but correct. A DMA buffer is uncached, so the processor's reads of a received packet go to the bus at bus speed; that cost belongs to the decision to map them so, and it is why a cache-clean by address is reserved for the day a non-coherent bus master appears.

### What it puts off limits

No override mode (Arm's `FWB`): the hypervisor cannot make a guest's stricter choice looser, and neither can the guest loosen the hypervisor's.

### Where the manual states it

{{r:memory-type-of-a-page}} and, for the rule's effect on atomics, {{r:atomic-memory-must-be-ordinary}}.
