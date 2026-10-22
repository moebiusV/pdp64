#!/usr/bin/env python3
"""kernelpain.py: mine kernel commit histories for the vocabulary of pain.

Reproducible companion of docs/kernel-pain-points.md (Appendix B).

Sub-commands
  clones   print (or with --run, execute) the blobless clone commands
  mine R   walk the whole history of repository R once, classify each
           non-merge commit by regular expression over subject+body, and
           write CSVs under docs/codegen-data/kernelpain/
  report   print summary tables (markdown) from the CSVs

Repositories (directories under ~/claude/kernel-history/):
  linux   torvalds/linux (2005 onward)
  linuxold  kernel.org history/history.git (1991 to 2005)
  freebsd, netbsd, openbsd

Method: one `git log --no-merges --name-only` pass per repository; a commit
is counted once per category it matches, and once per area (top-level
directory or architecture directory) it touches. A commit that touches two
architectures is counted in both. Nothing here reads file contents, so the
blobless clones suffice. The categories are keyword regexes: they measure
vocabulary, not truth (see the document's 'what this does not show').
"""
import csv, os, re, subprocess, sys, collections, heapq

HOME = os.path.expanduser("~")
HIST = os.path.join(HOME, "claude", "kernel-history")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "docs", "codegen-data", "kernelpain")

CLONES = {
    "linux": "https://github.com/torvalds/linux",
    "linuxold": "https://git.kernel.org/pub/scm/linux/kernel/git/history/history.git",
    "freebsd": "https://github.com/freebsd/freebsd-src",
    "netbsd": "https://github.com/NetBSD/src",
    "openbsd": "https://github.com/openbsd/src",
}

# (name, regex). Case-insensitive, applied to subject + body.
W = r"\b"
CATS = [
    # the hardware-defect vocabulary
    ("errata", r"\berrat(?:um|a)\b"),
    ("workaround", r"\bwork-?arounds?\b"),
    ("quirk", r"\bquirks?\b"),
    ("mitigation", r"\bmitigat(?:e|es|ed|ion|ions|ing)\b"),
    # speculation security
    ("spectre-family", r"\b(?:spectre|meltdown|retpolines?|ibrs|ibpb|stibp|ssbd|retbleed|zenbleed|srso|spec_ctrl|speculative store bypass|branch history injection|gather data sampling|rfds|inception)\b"),
    ("mds-l1tf-taa", r"\b(?:mds|microarchitectural data sampling|l1tf|l1 terminal fault|foreshadow|zombieload|taa|tsx async abort|srbds|mmio stale data)\b"),
    ("speculation-any", r"\bspeculat(?:ion|ive|ively|e)\b"),
    ("kpti-entry", r"\b(?:kpti|pti|page[- ]table isolation|kaiser|syscall entry|sysenter|sysret|swapgs|vsyscall|entry trampoline|entry code|int 0x80|ia32 syscall)\b"),
    ("hardening", r"\b(?:kaslr|aslr|cfi|bti|cet|shadow stack|stack protector|stackprotector|stack canary|pointer authentication|stack clash|vmap stack|init_on_alloc|usercopy|kasan|kfence|memory tagging|rodata|w\^x|set_memory_ro|fortify_source)\b"),
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
    ("asid-pcid", r"\b(?:asids?|pcids?|invpcid|vmids?)\b"),
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
CATRE = [(n, re.compile(r, re.I)) for n, r in CATS]

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
    if repo in ("linux", "linuxold"):
        if p[0] == "arch" and len(p) > 2:
            return "arch/" + ARCH_FAMILY.get(p[1], p[1])
        if p[0] in ("mm", "kernel", "fs", "net", "drivers", "Documentation", "include",
                    "lib", "security", "block", "ipc", "init", "crypto", "sound", "tools"):
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


def mine(repo):
    d = os.path.join(HIST, repo)
    if not os.path.isdir(d):
        sys.exit("no clone at " + d)
    head = subprocess.check_output(["git", "-C", d, "rev-parse", "HEAD"], text=True).strip()
    hdate = subprocess.check_output(["git", "-C", d, "log", "-1", "--format=%cI", "HEAD"], text=True).strip()
    cmd = ["nice", "-n", "10", "git", "-C", d, "-c", "core.quotepath=off", "log", "--no-merges",
           "--no-renames", "--name-only", "--date=format:%Y-%m-%d",
           "--format=%x01%H%x1f%ad%x1f%s%x1f%b%x02"]
    print("running:", " ".join(cmd), file=sys.stderr)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, errors="replace", bufsize=1 << 20)
    cat_area_year = collections.Counter()   # (cat, area, year, kind) -> n ; kind any|subj
    tot_area_year = collections.Counter()   # (area, year) -> n
    cat_year = collections.Counter()        # (cat, year, kind) -> n, once per commit
    tot_year = collections.Counter()
    first = collections.defaultdict(list)   # cat -> [(date, hash, subj)] earliest 3
    longest = collections.defaultdict(list) # cat -> heap [(bodylen, hash, date, subj, areas)]
    buf = ""
    ncommits = 0

    def handle(rec):
        nonlocal ncommits
        if "\x02" not in rec:
            return
        head_, names = rec.split("\x02", 1)
        parts = head_.split("\x1f", 3)
        if len(parts) < 4:
            return
        h, date, subj, body = parts
        year = date[:4]
        if not year.isdigit() or not (1970 <= int(year) <= 2027):
            return
        ncommits += 1
        areas = set()
        for ln in names.split("\n"):
            ln = ln.strip()
            if ln:
                areas.add(areas_for(repo, ln))
        if not areas:
            areas = {"none"}
        tot_year[year] += 1
        for a in areas:
            tot_area_year[(a, year)] += 1
        text = subj + "\n" + body
        for name, rx in CATRE:
            if rx.search(text):
                insubj = bool(rx.search(subj))
                cat_year[(name, year, "any")] += 1
                if insubj:
                    cat_year[(name, year, "subj")] += 1
                for a in areas:
                    cat_area_year[(name, a, year, "any")] += 1
                    if insubj:
                        cat_area_year[(name, a, year, "subj")] += 1
                if insubj:
                    f = first[name]
                    f.append((date, h, subj, ",".join(sorted(areas))))
                    f.sort()
                    del f[3:]
                    lg = longest[name]
                    item = (len(body), h, date, subj, ",".join(sorted(areas)))
                    if len(lg) < 6:
                        heapq.heappush(lg, item)
                    else:
                        heapq.heappushpop(lg, item)

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
    with open(os.path.join(OUT, f"{repo}-cat-area-year.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["category", "area", "year", "kind", "commits"])
        for k in sorted(cat_area_year):
            w.writerow(list(k) + [cat_area_year[k]])
    with open(os.path.join(OUT, f"{repo}-cat-year.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["category", "year", "kind", "commits"])
        for k in sorted(cat_year):
            w.writerow(list(k) + [cat_year[k]])
    with open(os.path.join(OUT, f"{repo}-totals.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["area", "year", "commits"])
        for k in sorted(tot_area_year):
            w.writerow(list(k) + [tot_area_year[k]])
    with open(os.path.join(OUT, f"{repo}-year-totals.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["year", "commits"])
        for k in sorted(tot_year):
            w.writerow([k, tot_year[k]])
    with open(os.path.join(OUT, f"{repo}-telling.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["category", "why", "hash", "date", "subject", "areas", "bodylen"])
        for c in first:
            for (date, h, s, a) in first[c]:
                w.writerow([c, "earliest", h, date, s, a, ""])
            for (bl, h, date, s, a) in sorted(longest[c], reverse=True):
                w.writerow([c, "longest-body", h, date, s, a, bl])
    with open(os.path.join(OUT, f"{repo}-meta.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["repo", "url", "head", "head_date", "non_merge_commits"])
        w.writerow([repo, CLONES[repo], head, hdate, ncommits])
    print(f"{repo}: {ncommits} non-merge commits, head {head}", file=sys.stderr)


def clones(run):
    os.makedirs(HIST, exist_ok=True)
    for name, url in CLONES.items():
        c = ["nice", "-n", "10", "git", "clone", "--filter=blob:none", "--no-checkout", url,
             os.path.join(HIST, name)]
        print(" ".join(c))
        if run and not os.path.isdir(os.path.join(HIST, name)):
            subprocess.call(c)


def load(repo):
    rows = []
    fn = os.path.join(OUT, f"{repo}-cat-area-year.csv")
    with open(fn) as f:
        for r in csv.DictReader(f):
            rows.append((r["category"], r["area"], int(r["year"]), r["kind"], int(r["commits"])))
    return rows


def report(repo, kind="any"):
    rows = load(repo)
    cats = [c for c, _ in CATS]
    by_year = collections.defaultdict(collections.Counter)
    for c, a, y, k, n in rows:
        if k == kind:
            by_year[c][y] += n  # counted once per area: approximate; see tot_year below
    print(repo, kind)


if __name__ == "__main__":
    ap = sys.argv[1:]
    if not ap:
        print(__doc__)
    elif ap[0] == "clones":
        clones("--run" in ap)
    elif ap[0] == "mine":
        mine(ap[1])
    elif ap[0] == "report":
        report(ap[1])
