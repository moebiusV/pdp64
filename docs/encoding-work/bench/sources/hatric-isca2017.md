# HATRIC: "Hardware Translation Coherence for Virtualized Systems" (ISCA 2017)

**Citation.** Zi Yan, Ján Veselý, Guilherme Cox, Abhishek Bhattacharjee (Rutgers University, Department of Computer Science), "Hardware Translation Coherence for Virtualized Systems", 44th International Symposium on Computer Architecture (ISCA '17), Toronto, June 2017. (The owner's note named Rice University and a different author order; the paper's own page and the authors' publication page give Rutgers, and the arXiv preprint orders the authors Yan, Cox, Veselý, Bhattacharjee; the ISCA listing orders them Yan, Veselý, Cox, Bhattacharjee.)
**What was read.** The whole of the arXiv preprint, version 2 of 15 February 2017 (13 pages, text of all sections, captions of the figures; the figures' data points were not read). URL: https://arxiv.org/pdf/1701.07517 . The published ISCA version may differ in numbers or wording: **could not verify** (the ACM copy, DOI 10.1145/3079856.3080211, was not fetched). The venue line was read on the authors' publication page, https://normal.zone/publications/2017-06-24-ISCA-2017 (formerly x-y-z.github.io), which prints "International Symposium on Computer Architecture (ISCA ‘17)" and the author order above.
**Date read.** 2026-11-25. Section numbers are the paper's.

## What the paper proposes (short note)

Today the hardware does not keep the TLB and its helper caches in step with page tables; software (the hypervisor) does it by sending interrupts to every processor that might run the guest, which forces a guest exit on each, and then flushes every translation structure, because the invalidation instructions need the guest-virtual address and the hypervisor only knows guest-physical and real addresses. HATRIC adds a "co-tag" to each entry of the TLB, of the walk caches ("MMU caches") and of the nested TLB: part of the real address of the table entry from which the translation came. The existing cache-coherence directory gets two bits per cache line saying "this line holds a guest page table" or "a nested page table", set by the hardware walker when it first fills a translation from that line. When any processor stores to such a line, the ordinary coherence traffic is also sent to the translation structures, and entries whose co-tag matches are dropped. The hypervisor uses plain stores; no interrupts, no exits, no invalidate instructions.

## Quotations

### What it proposes

> "we propose hardware translation invalidation and coherence or HATRIC, a readily implementable hardware mechanism to piggyback translation coherence atop existing cache coherence protocols."

(abstract)

> "HATRIC extends translation structure entries with coherence tags (or co-tags) storing the system physical address where the translation entry resides"

(section 1. The sentence ends "(not to be confused with the physical address stored in the page table)".)

> "Since TLBs, MMU caches, and nested TLBs are fundamentally read-only structures"

(section 4.2; the sentence goes on "HATRIC integrates them into the existing cache coherence protocol in a manner similar to read-only instruction caches". So an entry has only two states, valid and invalid.)

> "adding two bits to record whether cache lines belong to a guest page table (gPT) or nested page table (nPT)."

(section 4.2, "Directory entry changes".)

> "The nPT and gPT bits are set by the hardware page table walkers on fills to the TLBs, MMU caches, and nTLBs."

> "OS and hypervisor: These can traverse, map, and unmap page table entries using standard load/store instructions."

(section 4.2. The sentence after it: "HATRIC picks up these changes, and keeps all private cache and translation structures coherent.")

### The problem it measures (the state of the art in 2017)

> "there are no such guarantees for TLBs, MMU caches, and nTLBs."

(section 2.1, about the standard cache-coherence protocols, which do keep page-table lines coherent in the data caches.)

> "KVM, Xen, etc., flush all TLB contents when they modify a nested page table entry, rather than selectively invalidating TLB entries."

(section 3.2.)

> "no architectures today maintain selective invalidation instructions for MMU caches and nTLBs"

(section 3.3. This is true of x86, where Intel's INVEPT and AMD's INVLPGA cannot name one guest-physical page; it is not true of Arm, whose TLBI IPAS2E1IS invalidates by guest-physical address: see arm-arm-bbm.md.)

> "found that they require 640 cycles on average"

(section 3.3: the cost of a lighter-weight interrupt, measured with microbenchmarks "on Intel’s Haswell machines".)

> "the average of 1300 cycles required for a VM exit."

(same sentence: the lighter interrupt is "just half" of the cost of a VM exit, 1300 cycles, again on Haswell. This is the paper's only measured exit cost; it is a whole exit with the hypervisor's work, not the hardware alone.)

> "as much as 40% of their runtime can be wasted on translation coherence."

(section 1, of virtualized systems under page remapping.)

### Results

> "HATRIC achieves up to 30% performance and 10% energy benefits, for per-CPU area overheads of 2%."

(abstract. The introduction says the same, "adding less than 2% of CPU area".)

> "HATRIC is always within 2-4% of the ideal performance."

(section 6; "ideal" is zero-cost translation coherence in the simulator.)

> "Xen’s performance is improved by 21% and 33% for canneal and data caching respectively"

(section 6; only two programs were run on Xen.)

### What it costs and how it is sized

> "2-byte co-tags (a per-core area overhead of 2%) strike a good balance"

(section 4, "How are co-tags implemented?"; the full address would be 8 bytes, which "doubles" the size of a TLB entry and triples that of a walk-cache or nested-TLB entry, "unacceptable".)

> "Our 2 byte co-tags use bits 19-3 of the system physical address storing the page table."

(section 4.2: a co-tag is only 17 bits of the address, so different table entries can share a co-tag; the cost of that sharing is extra, harmless invalidations.)

> "HATRIC conservatively invalidates all translation structure entries caching these 8 page table entries, even if only a single page table entry is modified."

(section 4.2: the granularity is a cache line, eight entries.)

### What it assumes

> "Our discussion focuses on x86-64 systems."

(section 2.)

> "We use a trace-based approach to drive our simulation framework."

(section 5.1; a "detailed cycle-accurate" model of a 32-CPU Haswell-like processor, with CACTI for energy; traces of 50 billion memory references taken from KVM on a real two-socket Xeon E5-2450 machine in which die-stacked memory was imitated by memory contention. Memory remapping between two memory speeds is the workload, not guest reset or hypercalls.)

* The mechanism needs a directory-based cache-coherence protocol (MESI, "we have also implemented HATRIC atop MOESI protocols too, as well as snooping protocols like MESIF"), and hardware that records, in the directory, which lines were walked.
* A directory entry that is evicted sends back-invalidations to the translation structures too; sharer lists are "updated lazily", so there are spurious invalidations.
* The area figure ("2%") is stated in the abstract and the introduction and attributed to "detailed RTL modeling" in the paragraph on co-tag size; the text of the preprint does not show the synthesis or the units, so it cannot be turned into gates.

### Shipping?

The paper does not claim that any processor ships it. I searched for a product that does this (the search terms were the name, "co-tag", "translation coherence" and "hardware TLB coherence", on the web and in the Intel, AMD, Arm, IBM and RISC-V manuals) and found none; a negative of that kind is **could not verify**, and is reported as "none found".
