#!/usr/bin/env python3
"""kernelpain.py: how much of the CURRENT kernels is vocabulary of pain.

Reproducible companion of docs/kernel-pain-points.md (Appendix B).

History of scope (2026-10-22): the first version mined blobless full-history
clones with path limits; that was dropped (slow, large) and the clones were
deleted. Two measurements remain: (1) `grep`/`structural` over the CURRENT
source trees, and (2) `msgs` (Linux from 2005, FreeBSD from 1993, NetBSD from 1993, OpenBSD from 1995; the
kernel.org history.git URL turned out to hold the same 2005-2010 commits as
torvalds/linux and only 31 earlier ones, so it was dropped): commit-message mining on TREELESS BARE clones,
which fetch commits only (no trees, no blobs), read with `git log --format`
and no path arguments, so nothing but messages and metadata is touched.

Sub-commands
  trees        print the commit hash and date of each tree used
  grep         run every category over every tree, write the CSVs under
               docs/codegen-data/kernelpain/ (counts.csv, totals.csv)
  structural   run the named structural measurements (structural.csv)
  clonemsgs R  clone repo R treeless and bare into ~/claude/kernel-msgs/R.git
  msgs R       mine the commit messages of that clone (counts per year, per
               subject prefix, telling commits); the clone is deleted by the
               caller afterwards (tools/kernelpain-msgs.sh)
  report       print markdown tables from the CSVs

Trees (sparse checkouts under ~/claude/kernel-src; shallow, blobless):
  linux, freebsd, netbsd, openbsd. Which directories are present is recorded
  in trees.csv by `trees`. Sparse additions used for this study, one at a time:
    linux:   git sparse-checkout add Documentation mm kernel include/linux
             include/asm-generic block net/core drivers/irqchip drivers/iommu
             virt lib
    BSDs:    git sparse-checkout add sys/kern sys/vm|sys/uvm share/man/man9 sys/sys

Method: GNU grep -P (-r -I -i -c) per category per tree; a count is lines
that match (not occurrences), per file, then summed per area (an architecture
directory, or a subsystem directory) and per file kind (code, doc, kconfig).
A category's regex measures vocabulary, not truth.
"""
import csv, os, re, subprocess, sys, collections

HOME = os.path.expanduser("~")
SRC = os.path.join(HOME, "claude", "kernel-src")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "docs", "codegen-data", "kernelpain")
TREES = ["linux", "freebsd", "netbsd", "openbsd"]

# (name, pcre, case_sensitive)
CATS = [
    # the hardware-defect vocabulary
    ("errata", r"\berrat(?:um|a)\b"),
    ("workaround", r"\bwork-?arounds?\b"),
    ("quirk", r"\bquirks?\b"),
    ("mitigation", r"\bmitigat(?:e|es|ed|ion|ions|ing)\b"),
    # speculation security
    ("spectre-family", r"\b(?:spectre(?!\s+(?:x360|x2|xt|13|15|envy|laptop|speaker))|meltdown|retpolines?|ibrs|ibpb|stibp|ssbd|retbleed|zenbleed|srso|spec_ctrl|speculative store bypass|branch history injection|gather data sampling|rfds)\b"),
    ("mds-l1tf-taa", r"(?:microarchitectural data sampling|\bmds_[a-z_]+|\bmds (?:mitigation|vulnerab\w*|clear\w*|buffer\w*)|\bl1tf\b|l1 terminal fault|foreshadow|zombieload|\btaa\b|tsx async abort|\bsrbds\b|mmio stale data)"),
    ("speculation-any", r"\bspeculat(?:ion|ive|ively|e)\b"),
    ("kpti-entry", r"\b(?:kpti|pti|page[- ]table isolation|kaiser|syscall entry|sysenter|sysret|swapgs|vsyscall|entry trampoline|entry code|int 0x80|ia32 syscall)\b"),
    ("hardening", r"(?:kaslr|aslr|clang cfi|kcfi|fineibt|control.flow integrity|bti|cet|shadow stack|stack protector|stackprotector|stack canary|pointer authentication|stack clash|vmap stack|init_on_alloc|usercopy|kasan|kfence|memory tagging|rodata|w\^x|set_memory_ro|fortify_source)\b"),
    # memory ordering / locking
    ("barrier-ordering", r"\b(?:memory barriers?|smp_mb|smp_rmb|smp_wmb|smp_read_barrier_depends|read_barrier_depends|dma_wmb|dma_rmb|memory ordering|memory-ordering|acquire/release|load-acquire|store-release|READ_ONCE|WRITE_ONCE|mmiowb)\b"),
    ("race", r"\bra(?:ce|ces|cy)\b(?! condition in the tracing)"),
    ("deadlock", r"\b(?:deadlocks?|livelocks?|lockup|lock-up|hung task)\b"),
    ("lockdep", r"\blockdep\b"),
    ("spinlock-family", r"\b(?:spinlocks?|ticket lock|qspinlock|queued spinlock|mcs lock|rwlocks?|seqlocks?|big kernel lock|bkl|lock_kernel|lock contention|lock scalability)\b"),
    ("rcu", r"\b(?:rcu|srcu|call_rcu|synchronize_rcu|read-copy)\b"),
    ("atomics-llsc", r"\b(?:cmpxchg|ll/sc|load-linked|store-conditional|ldrex|strex|lr/sc|test_and_set|atomic_cmpxchg|compare-and-swap|compare and swap)\b"),
    ("percpu", r"\b(?:per-cpu|percpu|this_cpu|cpu-local)\b"),
    # memory management
    ("tlb", r"\b(?:tlbs?|translation lookaside|invlpg|tlb flush)\b"),
    ("shootdown", r"\b(?:shootdowns?|shoot-downs?|flush_tlb_others|tlb flush ipi)\b"),
    ("asid-pcid", r"\b(?:asids?|invpcid|vmids?)\b|\bpcid\b(?!\s*header)"),
    ("pagetable", r"\b(?:page tables?|pgd|pmd|pud|p4d|five-level|5-level paging|4-level paging|page walk|page-walk|pgtable)\b"),
    ("accessed-dirty", r"\b(?:accessed bit|dirty bit|young bit|referenced bit|pte_young|pte_dirty|pte_mkyoung|access flag|soft-dirty|software dirty|dirty bit management|hardware dirty|hw dirty|reference bit)\b"),
    ("huge-pages", r"\b(?:transparent huge|thp|hugepages?|huge pages?|hugetlb)\b"),
    ("numa", r"\b(?:numa|mempolicy|numa balancing)\b"),
    ("cow-fork-mmaplock", r"\b(?:copy-on-write|dup_mmap|mmap_sem|mmap_lock|mmap lock|per-vma lock|vma lock)\b"),
    # caches / DMA / devices
    ("cache-coherence", r"\b(?:cache coheren\w*|cache alias\w*|cache flush\w*|cache invalidat\w*|cache maintenance|dcache|icache|d-cache|i-cache|non-?coherent|vipt|vivt|writeback cache|write-back cache|cache line bounc\w*|false sharing)\b"),
    ("dma", r"\b(?:dma|swiotlb|dma-mapping|iommu|bounce buffers?)\b"),
    ("mmio-ordering", r"\b(?:write[- ]combin\w*|posted writes?|mmiowb|readl_relaxed|writel_relaxed|doorbell|wmb\(\))"),
    ("write-buffer-delay-slot", r"\b(?:write buffer|store buffer|delay slots?|branch delay)\b"),
    ("tlb-refill", r"\b(?:tlb refill|tlb miss|tlb exception|tlb handler|tlb load)\b"),
    # CPU state
    ("fpu-vector-state", r"\b(?:fpu|xsave\w*|xrstor\w*|lazy fpu|eager fpu|fxsave|avx\d*|simd|neon|sve|altivec|vfp|vector state|floating[- ]point state)\b"),
    ("alignment", r"\b(?:unaligned|misaligned|alignment fault|alignment exception|get_unaligned|put_unaligned|packed struct|__packed)\b"),
    ("endian", r"\b(?:endian\w*|byte-?order|byteswap\w*|cpu_to_le\w*|le32_to_cpu|be32_to_cpu)\b"),
    ("compat-32bit", r"\b(?:compat|ia32 emulation|compat_ioctl|ilp32|x32|31-bit|32-bit compat\w*)\b"),
    ("y2038-time", r"\b(?:y2038|year 2038|time_t|timespec64|64-bit time|2038)\b"),
    ("timekeeping", r"\b(?:vdso|tsc|clocksource|timekeeping|clock_gettime|hpet|time stamp counter|monotonic clock)\b"),
    # interrupts / power / virt
    ("interrupts", r"\b(?:interrupt latency|irq latency|irq storm|interrupt storm|spurious (?:irq|interrupt)\w*|eoi|msi-x|msi|irq affinity|apic|gic|plic|ipi|ipis)\b"),
    ("timers-tick", r"\b(?:nohz|tickless|dynticks|hrtimer|timer wheel|timer interrupt|tick broadcast|jiffies)\b"),
    ("idle-power", r"\b(?:cpuidle|mwait|hlt|wfi|c-state|c-states|cpufreq|runtime pm|power domain|suspend to ram|hibernat\w*)\b"),
    ("virtualization", r"\b(?:kvm|nested virtualization|nested paging|vmexit|vm exit|hypercalls?|paravirt\w*|stage-2|virtio|xen)\b"),
    # user memory / tracing
    ("uaccess", r"\b(?:copy_from_user|copy_to_user|uaccess|smap|smep|get_user|put_user|strncpy_from_user|exception tables?|__ex_table|stac|clac)\b"),
    ("tracing-patching", r"\b(?:ftrace|kprobes?|uprobes?|text_poke|int3|jump labels?|static keys?|static calls?|self-modifying|kgdb|hw_breakpoint|hardware breakpoint|single-step\w*)\b"),
    # machine checks
    ("machine-check-poison", r"\b(?:machine checks?|mce|hwpoison|memory failure|poisoned|poison|uncorrectable|edac|ecc error\w*)\b"),
    # fast paths
    ("net-storage-fastpath", r"\b(?:napi|xdp|zero-copy|zerocopy|busy[- ]poll\w*|io_uring|af_xdp|gro|tso|batching|lockless|lock-free)\b"),
]
CATS += [
    ("marker-xxx-fixme-hack", r"\b(?:XXX|FIXME|HACK|KLUDGE)\b"),
    ("hardware-is-broken", r"\b(?:(?:hardware|cpu|chip|silicon|firmware|bios|hw) (?:bug|bugs|quirk|erratum|errata|brokenness)|broken (?:hardware|hw|firmware|bios|cpus?)|buggy (?:hardware|hw|cpus?|firmware|bios|devices?))\b"),
]
CASE_SENSITIVE = {"marker-xxx-fixme-hack"}

# area normalisation -------------------------------------------------------
ARCH_FAMILY = {
    "i386": "x86", "x86_64": "x86", "x86": "x86", "amd64": "x86", "i386": "x86", "x64": "x86",
    "ppc": "powerpc", "ppc64": "powerpc", "powerpc": "powerpc", "macppc": "powerpc", "prep": "powerpc",
    "powerpc64": "powerpc", "mpc85xx": "powerpc", "ofppc": "powerpc", "bebox": "powerpc", "evbppc": "powerpc",
    "sparc64": "sparc", "sparc": "sparc",
    "arm": "arm", "arm26": "arm", "arm32": "arm", "armv7": "arm", "evbarm": "arm", "zaurus": "arm",
    "armv6": "arm", "armv8": "arm64", "arm64": "arm64", "aarch64": "arm64",
    "mips": "mips", "mips64": "mips", "evbmips": "mips", "sgi": "mips", "octeon": "mips",
    "loongson": "mips", "cobalt": "mips", "emips": "mips", "pmax": "mips", "algor": "mips",
    "riscv": "riscv", "riscv64": "riscv", "evbriscv": "riscv",
    "vax": "vax", "alpha": "alpha", "ia64": "ia64", "m68k": "m68k", "mac68k": "m68k", "amiga": "m68k",
    "hp300": "m68k", "atari": "m68k", "mvme68k": "m68k", "sun3": "m68k",
    "s390": "s390", "sh": "sh", "sh3": "sh", "hppa": "parisc", "parisc": "parisc", "hppa64": "parisc",
    "luna88k": "m88k", "m88k": "m88k", "mvme88k": "m88k", "m32r": "m32r", "um": "um", "xtensa": "xtensa",
    "loongarch": "loongarch", "arc": "arc", "csky": "csky", "hexagon": "hexagon", "nios2": "nios2",
    "openrisc": "openrisc", "microblaze": "microblaze", "nds32": "nds32", "c6x": "c6x",
    "h8300": "h8300", "frv": "frv", "cris": "cris", "mn10300": "mn10300", "blackfin": "blackfin",
    "avr32": "avr32", "arm32": "arm", "dreamcast": "sh", "landisk": "sh", "hpcsh": "sh",
    "i386": "x86", "vax": "vax", "pc532": "ns32k", "ns32k": "ns32k", "sun2": "m68k",
    "x68k": "m68k", "news68k": "m68k", "next68k": "m68k", "mvme68k": "m68k",
}
DROPPED = {"Documentation"}  # kept as its own area


def areas_for(repo, path):
    p = path.split("/")
    if repo == "linux":
        if p[0] == "arch" and len(p) > 2:
            return "arch/" + ARCH_FAMILY.get(p[1], p[1])
        if p[0] in ("mm", "kernel", "fs", "net", "drivers", "Documentation", "include",
                    "lib", "security", "block", "ipc", "init", "crypto", "sound", "tools", "virt"):
            return p[0]
        return "other"
    if repo == "freebsd":
        if p[0] == "sys" and len(p) > 2:
            return "arch/" + ARCH_FAMILY[p[1]] if p[1] in ARCH_FAMILY else "sys/" + p[1]
        return "other" if p[0] != "sys" else "sys/other"
    if repo in ("netbsd", "openbsd"):
        if p[0] == "sys" and len(p) > 3 and p[1] == "arch":
            return "arch/" + ARCH_FAMILY.get(p[2], p[2])
        if p[0] == "sys" and len(p) > 2:
            return "sys/" + p[1]
        return "other" if p[0] != "sys" else "sys/other"
    return "other"






def kind_of(repo, path):
    b = os.path.basename(path)
    if path.startswith("Documentation/") or "/man/" in path or b.endswith((".rst", ".txt", ".md", ".9")):
        return "doc"
    if b.startswith("Kconfig") or b.endswith(".in") and "Kconfig" in b:
        return "kconfig"
    if b.endswith((".c", ".h", ".S", ".s", ".rs", ".asm", ".inc")):
        return "code"
    return "other"


def git_head(t):
    d = os.path.join(SRC, t)
    h = subprocess.check_output(["git", "-C", d, "rev-parse", "HEAD"], text=True).strip()
    dt = subprocess.check_output(["git", "-C", d, "log", "-1", "--format=%cs"], text=True).strip()
    return h, dt


def trees():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "trees.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["tree", "head", "date", "sparse_dirs"])
        for t in TREES:
            h, dt = git_head(t)
            sp = subprocess.check_output(["git", "-C", os.path.join(SRC, t), "sparse-checkout", "list"], text=True).split()
            w.writerow([t, h, dt, " ".join(sp)])
            print(t, h, dt, len(sp), "sparse dirs")


def tree_files(t):
    """All regular files of the working tree (sparse), relative paths."""
    root = os.path.join(SRC, t)
    out = []
    for dp, dn, fn in os.walk(root):
        if ".git" in dn:
            dn.remove(".git")
        for x in fn:
            out.append(os.path.relpath(os.path.join(dp, x), root))
    return out


def count_lines_of(root, rel):
    try:
        with open(os.path.join(root, rel), "rb") as f:
            return f.read().count(b"\n")
    except OSError:
        return 0


def totals():
    rows = collections.Counter()
    for t in TREES:
        root = os.path.join(SRC, t)
        for rel in tree_files(t):
            k = kind_of(t, rel)
            if k == "other":
                continue
            a = areas_for(t, rel)
            rows[(t, a, k, "files")] += 1
            rows[(t, a, k, "lines")] += count_lines_of(root, rel)
    with open(os.path.join(OUT, "totals.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["tree", "area", "kind", "files", "lines"])
        keys = sorted({(t, a, k) for (t, a, k, _) in rows})
        for t, a, k in keys:
            w.writerow([t, a, k, rows[(t, a, k, "files")], rows[(t, a, k, "lines")]])


def grep_all():
    os.makedirs(OUT, exist_ok=True)
    totals()
    res = collections.Counter()
    for t in TREES:
        root = os.path.join(SRC, t)
        for name, rx in CATS:
            cmd = ["nice", "-n", "10", "grep", "-rPIc", "--exclude-dir=.git"]
            if name not in CASE_SENSITIVE:
                cmd.append("-i")
            cmd += ["-e", rx, "."]
            p = subprocess.run(cmd, cwd=root, capture_output=True, text=True, errors="replace")
            for ln in p.stdout.splitlines():
                path, _, n = ln.rpartition(":")
                if not n.isdigit() or n == "0":
                    continue
                path = path[2:] if path.startswith("./") else path
                k = kind_of(t, path)
                if k == "other":
                    continue
                a = areas_for(t, path)
                res[(t, name, a, k, "files")] += 1
                res[(t, name, a, k, "lines")] += int(n)
            print(t, name, file=sys.stderr)
    with open(os.path.join(OUT, "counts.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["tree", "category", "area", "kind", "files", "lines"])
        keys = sorted({k[:4] for k in res})
        for k in keys:
            w.writerow(list(k) + [res[k + ("files",)], res[k + ("lines",)]])


# Named structural measurements: (id, tree, description, shell command run in the tree root,
# unit). The command prints a single integer.
STRUCT = [
    ("kconfig-erratum-arm64", "linux", "Kconfig options named *ERRATUM/ERRATA in arch/arm64/Kconfig", "grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/arm64/Kconfig", "options"),
    ("kconfig-erratum-arm", "linux", "Kconfig options named *ERRATUM/ERRATA in arch/arm (Kconfig and mm/Kconfig)", "grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/arm/Kconfig arch/arm/mm/Kconfig | awk -F: '{s+=$NF} END{print s}'", "options"),
    ("kconfig-erratum-riscv", "linux", "Kconfig options named *ERRATUM/ERRATA in arch/riscv/Kconfig.errata", "grep -c '^config .*ERRATUM\\|^config .*ERRATA' arch/riscv/Kconfig.errata", "options"),
    ("kconfig-erratum-all-arch", "linux", "Kconfig options named *ERRATUM/ERRATA anywhere under arch", "grep -rh '^config .*ERRATUM\\|^config .*ERRATA' arch --include='Kconfig*' | wc -l", "options"),
    ("x86-bug-flags", "linux", "X86_BUG_* bug flags defined", "grep -c 'define X86_BUG_' arch/x86/include/asm/cpufeatures.h", "flags"),
    ("x86-vuln-blacklist", "linux", "CPU model rows in the vulnerability blacklist (VULNBL_*)", "grep -cE '^\\s*VULNBL_' arch/x86/kernel/cpu/common.c", "rows"),
    ("x86-bugs-c-lines", "linux", "lines of arch/x86/kernel/cpu/bugs.c (mitigation selection)", "wc -l < arch/x86/kernel/cpu/bugs.c", "lines"),
    ("x86-mitigation-kconfig", "linux", "MITIGATION_* Kconfig options in arch/x86/Kconfig", "grep -c 'config MITIGATION_' arch/x86/Kconfig", "options"),
    ("hw-vuln-docs", "linux", "files in Documentation/admin-guide/hw-vuln", "ls Documentation/admin-guide/hw-vuln | wc -l", "files"),
    ("hw-vuln-doc-lines", "linux", "lines in Documentation/admin-guide/hw-vuln", "cat Documentation/admin-guide/hw-vuln/*.rst | wc -l", "lines"),
    ("arm64-errata-kconfig", "linux", "ARM64_ERRATUM_* Kconfig options", "grep -c 'config ARM64_ERRATUM_' arch/arm64/Kconfig", "options"),
    ("arm64-workaround-caps", "linux", "ARM64_WORKAROUND_* capabilities in the capability table", "grep -cE '^WORKAROUND_' arch/arm64/tools/cpucaps", "capabilities"),
    ("arm64-silicon-errata-rows", "linux", "rows of Documentation/arch/arm64/silicon-errata.rst naming an erratum", "grep -cE '^\\| [A-Za-z].*(#|ID|errata|Erratum|[0-9]{5,})' Documentation/arch/arm64/silicon-errata.rst", "rows"),
    ("memory-barriers-lines", "linux", "lines of Documentation/memory-barriers.txt", "wc -l < Documentation/memory-barriers.txt", "lines"),
    ("rcu-doc-lines", "linux", "lines under Documentation/RCU", "find Documentation/RCU -type f | xargs cat | wc -l", "lines"),
    ("locking-doc-lines", "linux", "lines under Documentation/locking", "find Documentation/locking -type f | xargs cat | wc -l", "lines"),
    ("kernel-parameters-mitigation-lines", "linux", "lines of kernel-parameters.txt mentioning mitigat/spectre/retbleed/l1tf/mds", "grep -ciE 'mitigat|spectre|retbleed|l1tf|mds|srbds|ssb' Documentation/admin-guide/kernel-parameters.txt", "lines"),
    ("extable-uses-x86", "linux", "exception-table annotations in arch/x86 (_ASM_EXTABLE*, EX_TYPE_*)", "grep -rhE '_ASM_EXTABLE|EX_TYPE_' arch/x86 | wc -l", "lines"),
    ("arch-flush-tlb-defs", "linux", "files under arch/*/include and arch/*/mm mentioning flush_tlb_", "grep -rlE 'flush_tlb_' arch | wc -l", "files"),
    ("arch-cache-flush-defs", "linux", "files under arch mentioning flush_dcache_page, flush_cache_, flush_icache_", "grep -rlE 'flush_dcache_page|flush_cache_(mm|range|page)|flush_icache_' arch | wc -l", "files"),
    ("arm-lines-vivt-alias", "linux", "lines in arch/arm mentioning aliasing/VIVT/VIPT", "grep -rciE 'aliasing|vivt|vipt' arch/arm | awk -F: '{s+=$NF} END{print s}'", "lines"),
    ("this-cpu-uses", "linux", "this_cpu_/__this_cpu_/per_cpu( uses in kernel, mm, arch", "grep -rhE 'this_cpu_|per_cpu\\(|raw_cpu_' kernel mm arch | wc -l", "lines"),
    ("rcu-api-uses", "linux", "rcu_read_lock/rcu_dereference/call_rcu uses in kernel and mm", "grep -rhE 'rcu_read_lock|rcu_dereference|call_rcu|synchronize_rcu' kernel mm | wc -l", "lines"),
    ("readonce-uses", "linux", "READ_ONCE/WRITE_ONCE uses in kernel and mm", "grep -rhE 'READ_ONCE|WRITE_ONCE' kernel mm | wc -l", "lines"),
    ("smp-barrier-uses", "linux", "smp_mb/rmb/wmb/load_acquire/store_release uses in kernel, mm and arch", "grep -rhE 'smp_(mb|rmb|wmb|load_acquire|store_release)' kernel mm arch | wc -l", "lines"),
    ("spinlock-uses", "linux", "spin_lock* calls in kernel and mm", "grep -rhE 'spin_lock' kernel mm | wc -l", "lines"),
    ("alt-instr-x86", "linux", "ALTERNATIVE/alternative_ uses in arch/x86 (boot-time patching)", "grep -rhE 'ALTERNATIVE|alternative_' arch/x86 | wc -l", "lines"),
    ("static-key-uses", "linux", "static_branch_/DEFINE_STATIC_KEY uses in kernel, mm, arch", "grep -rhE 'static_branch_|DEFINE_STATIC_KEY' kernel mm arch | wc -l", "lines"),
    ("compat-lines", "linux", "lines mentioning compat_ in kernel and mm", "grep -rhE 'compat_|COMPAT' kernel mm | wc -l", "lines"),
    ("lines-kernel-rcu", "linux", "lines of C in kernel/rcu", "cat kernel/rcu/*.c kernel/rcu/*.h | wc -l", "lines"),
    ("lines-kernel-locking", "linux", "lines of C in kernel/locking", "cat kernel/locking/*.c kernel/locking/*.h | wc -l", "lines"),
    ("lines-kernel-sched", "linux", "lines of C in kernel/sched", "cat kernel/sched/*.c kernel/sched/*.h | wc -l", "lines"),
    ("lines-x86-fpu", "linux", "lines of C in arch/x86/kernel/fpu", "cat arch/x86/kernel/fpu/*.c | wc -l", "lines"),
    ("lines-x86-entry", "linux", "lines in arch/x86/entry (assembly and C)", "cat arch/x86/entry/*.S arch/x86/entry/*.c | wc -l", "lines"),
    ("lines-x86-microcode", "linux", "lines of C in arch/x86/kernel/cpu/microcode", "cat arch/x86/kernel/cpu/microcode/*.c | wc -l", "lines"),
    ("lines-x86-mce", "linux", "lines of C in arch/x86/kernel/cpu/mce (machine checks)", "cat arch/x86/kernel/cpu/mce/*.c | wc -l", "lines"),
    ("lines-x86-retpoline", "linux", "lines of arch/x86/lib/retpoline.S", "wc -l < arch/x86/lib/retpoline.S", "lines"),
    ("lines-mm-total", "linux", "lines of C in mm", "cat mm/*.c | wc -l", "lines"),
    ("lines-mm-huge-memory", "linux", "lines of mm/huge_memory.c (transparent huge pages)", "wc -l < mm/huge_memory.c", "lines"),
    ("lines-mm-tlb-ops", "linux", "lines of mm/mmu_gather.c and mm/mmu_notifier.c", "cat mm/mmu_gather.c mm/mmu_notifier.c | wc -l", "lines"),
    ("files-arch-cache-tlb", "linux", "files named *cache* or *tlb* under arch/*/mm and arch/*/kernel", "find arch -path '*/mm/*' -o -path '*/kernel/*' | grep -iE '(cache|tlb)[^/]*\\.(c|S)$' | wc -l", "files"),
    ("lines-arch-cache-tlb", "linux", "lines in those files", "find arch -path '*/mm/*' -o -path '*/kernel/*' | grep -iE '(cache|tlb)[^/]*\\.(c|S)$' | xargs cat | wc -l", "lines"),
    ("lines-arm64-cpu-errata", "linux", "lines of arch/arm64/kernel/cpu_errata.c", "wc -l < arch/arm64/kernel/cpu_errata.c", "lines"),
    ("lines-arm64-proton-spectre", "linux", "lines of arch/arm64/kernel/proton-pack.c (Spectre/BHB mitigations)", "wc -l < arch/arm64/kernel/proton-pack.c", "lines"),
    ("lines-bsd-openbsd-pmap-amd64", "openbsd", "lines of sys/arch/amd64/amd64/pmap.c", "wc -l < sys/arch/amd64/amd64/pmap.c", "lines"),
    ("lines-freebsd-pmap-amd64", "freebsd", "lines of sys/amd64/amd64/pmap.c", "wc -l < sys/amd64/amd64/pmap.c", "lines"),
    ("lines-netbsd-pmap-x86", "netbsd", "lines of sys/arch/x86/x86/pmap.c", "wc -l < sys/arch/x86/x86/pmap.c", "lines"),
    ("fb-cpu-features-bugs", "freebsd", "lines in x86 cpu setup mentioning errata/workaround", "grep -rhiE 'errat|workaround' sys/x86 sys/amd64 | wc -l", "lines"),
    ("fb-arm64-errata", "freebsd", "lines in sys/arm64 mentioning errat/workaround", "grep -rhiE 'errat|workaround' sys/arm64 | wc -l", "lines"),
    ("nb-errata", "netbsd", "lines under sys/arch mentioning errat/workaround", "grep -rhiE 'errat|workaround' sys/arch | wc -l", "lines"),
    ("ob-errata", "openbsd", "lines under sys/arch mentioning errat/workaround", "grep -rhiE 'errat|workaround' sys/arch | wc -l", "lines"),
    ("ob-mitigation", "openbsd", "lines under sys/arch mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf", "grep -rhiE 'mitigat|spectre|meltdown|retpoline|\\bmds\\b|l1tf|retbleed' sys/arch | wc -l", "lines"),
    ("fb-mitigation", "freebsd", "lines in sys/x86 sys/amd64 sys/arm64 mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf", "grep -rhiE 'mitigat|spectre|meltdown|retpoline|\\bmds\\b|l1tf|retbleed' sys/x86 sys/amd64 sys/arm64 | wc -l", "lines"),
    ("nb-mitigation", "netbsd", "lines under sys/arch mentioning mitigat/spectre/meltdown/retpoline/mds/l1tf", "grep -rhiE 'mitigat|spectre|meltdown|retpoline|\\bmds\\b|l1tf|retbleed' sys/arch | wc -l", "lines"),
]


def structural():
    with open(os.path.join(OUT, "structural.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "tree", "description", "unit", "value", "command"])
        for i, t, d, cmd, u in STRUCT:
            p = subprocess.run(["bash", "-c", "nice -n 10 " + cmd if False else cmd], cwd=os.path.join(SRC, t),
                               capture_output=True, text=True)
            v = p.stdout.strip().split("\n")[-1].strip() if p.stdout.strip() else "n/a"
            w.writerow([i, t, d, u, v, cmd])
            print(i, v)


def _rd(name):
    fn = os.path.join(OUT, name)
    if not os.path.exists(fn):
        return []
    with open(fn) as f:
        return list(csv.DictReader(f))


def report():
    tot = collections.defaultdict(lambda: [0, 0])
    for r in _rd("totals.csv"):
        if r["kind"] == "code":
            x = tot[(r["tree"], r["area"])]
            x[0] += int(r["files"]); x[1] += int(r["lines"])
    cnt = collections.defaultdict(int)
    for r in _rd("counts.csv"):
        cnt[(r["tree"], r["category"], r["area"], r["kind"], "lines")] += int(r["lines"])
        cnt[(r["tree"], r["category"], r["area"], r["kind"], "files")] += int(r["files"])
    for t in TREES:
        cats = [c for c, _ in CATS]
        print(f"\n### {t}: matching lines per category, by kind (all areas)\n")
        print("| category | code lines | code files | doc lines | kconfig lines |")
        print("|---|---:|---:|---:|---:|")
        for c in cats:
            cl = sum(v for k, v in cnt.items() if k[:2] == (t, c) and k[3] == "code" and k[4] == "lines")
            cf = sum(v for k, v in cnt.items() if k[:2] == (t, c) and k[3] == "code" and k[4] == "files")
            dl = sum(v for k, v in cnt.items() if k[:2] == (t, c) and k[3] == "doc" and k[4] == "lines")
            kl = sum(v for k, v in cnt.items() if k[:2] == (t, c) and k[3] == "kconfig" and k[4] == "lines")
            if cl + dl + kl:
                print(f"| {c} | {cl} | {cf} | {dl} | {kl} |")
        areas = sorted({a for (tt, a) in tot if tt == t and a.startswith("arch/")}, key=lambda a: -tot[(t, a)][1])
        print(f"\n### {t}: errata+workaround+quirk+hardware-is-broken code lines per architecture\n")
        print("| area | code lines | errata | workaround | quirk | hw-broken | per 1000 code lines |")
        print("|---|---:|---:|---:|---:|---:|---:|")
        for a in areas:
            n = tot[(t, a)][1]
            if n < 5000:
                continue
            g = lambda c: cnt[(t, c, a, "code", "lines")]
            s = g("errata") + g("workaround") + g("quirk") + g("hardware-is-broken")
            print(f"| {a} | {n} | {g('errata')} | {g('workaround')} | {g('quirk')} | {g('hardware-is-broken')} | {1000.0*s/n:.1f} |")


MSGDIR = os.path.join(HOME, "claude", "kernel-msgs")
MSG_URLS = {
    "linux": "https://github.com/torvalds/linux",
    "freebsd": "https://github.com/freebsd/freebsd-src",
    "netbsd": "https://github.com/NetBSD/src",
    "openbsd": "https://github.com/openbsd/src",
}
PREFIX_RE = re.compile(r"^([A-Za-z0-9_./+\- ,]{1,32}):\s")


def clonemsgs(repo):
    os.makedirs(MSGDIR, exist_ok=True)
    dst = os.path.join(MSGDIR, repo + ".git")
    cmd = ["nice", "-n", "10", "git", "clone", "--bare", "--filter=tree:0", "--single-branch",
           MSG_URLS[repo], dst]
    print(" ".join(cmd))
    subprocess.check_call(cmd)


def prefix_of(subj):
    m = PREFIX_RE.match(subj)
    if not m:
        return "(none)"
    return m.group(1).strip().lower().split("/")[0].split(",")[0].strip() or "(none)"


def msgs(repo):
    import heapq
    d = os.path.join(MSGDIR, repo + ".git")
    head = subprocess.check_output(["git", "-C", d, "rev-parse", "HEAD"], text=True).strip()
    hdate = subprocess.check_output(["git", "-C", d, "log", "-1", "--format=%cI"], text=True).strip()
    cmd = ["nice", "-n", "10", "git", "-C", d, "log", "--no-merges", "--date=format:%Y-%m-%d",
           "--format=%x01%H%x1f%ad%x1f%s%x1f%b%x02"]
    print("running:", " ".join(cmd), file=sys.stderr)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, errors="replace", bufsize=1 << 20)
    rx = [(n, re.compile(r, 0 if n in CASE_SENSITIVE else re.I)) for n, r in CATS]
    cy = collections.Counter(); cp = collections.Counter(); ty = collections.Counter(); tp = collections.Counter()
    first = collections.defaultdict(list); longest = collections.defaultdict(list)
    n = 0

    def handle(rec):
        nonlocal n
        if "\x02" not in rec:
            return
        h = rec.split("\x02", 1)[0].split("\x1f", 3)
        if len(h) < 4:
            return
        hh, date, subj, body = h
        y = date[:4]
        if not y.isdigit():
            return
        n += 1
        pre = prefix_of(subj)
        ty[y] += 1; tp[pre] += 1
        text = subj + "\n" + body
        for name, r in rx:
            if r.search(text):
                ins = bool(r.search(subj))
                cy[(name, y, "any")] += 1
                cp[(name, pre, "any")] += 1
                if ins:
                    cy[(name, y, "subj")] += 1
                    cp[(name, pre, "subj")] += 1
                    f = first[name]; f.append((date, hh, subj)); f.sort(); del f[3:]
                    lg = longest[name]
                    item = (len(body), hh, date, subj, " ".join(body.split())[:160])
                    if len(lg) < 5:
                        heapq.heappush(lg, item)
                    else:
                        heapq.heappushpop(lg, item)

    buf = ""
    while True:
        chunk = p.stdout.read(1 << 22)
        if not chunk:
            break
        buf += chunk
        recs = buf.split("\x01")
        buf = recs.pop()
        for r in recs:
            if r:
                handle(r)
    if buf:
        handle(buf)
    p.wait()
    os.makedirs(OUT, exist_ok=True)
    def w(name, header, rows):
        with open(os.path.join(OUT, f"msgs-{repo}-{name}.csv"), "w", newline="") as f:
            cw = csv.writer(f); cw.writerow(header); cw.writerows(rows)
    w("cat-year", ["category", "year", "kind", "commits"], [list(k) + [v] for k, v in sorted(cy.items())])
    w("cat-prefix", ["category", "prefix", "kind", "commits"], [list(k) + [v] for k, v in sorted(cp.items()) if v >= 3])
    w("year-totals", ["year", "commits"], sorted(ty.items()))
    w("prefix-totals", ["prefix", "commits"], [(k, v) for k, v in tp.most_common(400)])
    tell = []
    for c in first:
        for (date, hh, s) in first[c]:
            tell.append([c, "earliest", hh, date, s, ""])
        for (bl, hh, date, s, ex) in sorted(longest[c], reverse=True):
            tell.append([c, "longest-body", hh, date, s, ex])
    w("telling", ["category", "why", "hash", "date", "subject", "excerpt"], tell)
    w("meta", ["repo", "url", "head", "head_date", "non_merge_commits", "git_log_command"],
      [[repo, MSG_URLS[repo], head, hdate, n, " ".join(cmd[3:])]])
    print(repo, n, head, file=sys.stderr)



def msgreport(repos):
    """Markdown for Appendix B.7 from the msgs-* CSVs."""
    PER = [("-1999", 0, 1999), ("2000-04", 2000, 2004), ("2005-09", 2005, 2009), ("2010-14", 2010, 2014),
           ("2015-19", 2015, 2019), ("2020-26", 2020, 2026)]
    def per(y):
        for n, a, b in PER:
            if a <= y <= b:
                return n
    def rd(repo, name):
        fn = os.path.join(OUT, f"msgs-{repo}-{name}.csv")
        if not os.path.exists(fn):
            return []
        with open(fn) as f:
            return list(csv.DictReader(f))
    for repo in repos:
        meta = rd(repo, "meta")
        if not meta:
            continue
        m = meta[0]
        tot = collections.Counter()
        for r in rd(repo, "year-totals"):
            tot[per(int(r["year"]))] += int(r["commits"])
        names = [n for n, _, _ in PER if tot[n]]
        cy = collections.defaultdict(collections.Counter)
        for r in rd(repo, "cat-year"):
            if r["kind"] == "any":
                cy[r["category"]][per(int(r["year"]))] += int(r["commits"])
        print(f"\n#### {repo}: {m['non_merge_commits']} non-merge commits, head `{m['head']}` ({m['head_date'][:10]}), {m['url']}\n")
        print("Commits whose subject or message matches the category, per 1000 non-merge commits of the period (message mining, any match).\n")
        print("| category | " + " | ".join(names) + " | total |")
        print("|---|" + "---:|" * (len(names) + 1))
        print("| (all commits) | " + " | ".join(str(tot[n]) for n in names) + f" | {sum(tot.values())} |")
        for c, _ in CATS:
            row = cy[c]
            if sum(row.values()) < 20:
                continue
            print(f"| {c} | " + " | ".join(f"{1000.0*row[n]/tot[n]:.1f}" for n in names) + f" | {sum(row.values())} |")
        # prefixes
        pt = {r["prefix"]: int(r["commits"]) for r in rd(repo, "prefix-totals")}
        cp = collections.defaultdict(collections.Counter)
        for r in rd(repo, "cat-prefix"):
            if r["kind"] == "subj":
                cp[r["category"]][r["prefix"]] += int(r["commits"])
        print(f"\n##### {repo}: subject prefixes with the most commits whose SUBJECT matches errata, workaround or quirk\n")
        agg = collections.Counter()
        for c in ("errata", "workaround", "quirk"):
            agg.update(cp[c])
        print("| prefix | subject matches | all commits with this prefix | per 1000 |")
        print("|---|---:|---:|---:|")
        for pre, n in agg.most_common(14):
            if pre == "(none)":
                continue
            print(f"| {pre} | {n} | {pt.get(pre, 0)} | {1000.0*n/pt[pre]:.1f} |" if pt.get(pre) else f"| {pre} | {n} | n/a | n/a |")


if __name__ == "__main__":
    ap = sys.argv[1:]
    if not ap:
        print(__doc__)
    elif ap[0] == "trees":
        trees()
    elif ap[0] == "grep":
        grep_all()
    elif ap[0] == "clonemsgs":
        clonemsgs(ap[1])
    elif ap[0] == "msgs":
        msgs(ap[1])
    elif ap[0] == "msgreport":
        msgreport(ap[1:])
    elif ap[0] == "structural":
        structural()
    elif ap[0] == "report":
        report()
