#!/usr/bin/env python3
"""mkfeedback.py: build docs/feedback/decisions-feedback.txt.

A plain-text, fixed-width questionnaire made from the open items of Appendix J,
the proposals of Appendix H, the confirmation list, and the status ledger, for
reading and editing in a pager-with-editor.  Standard library only.
The output is deterministic: the same sources give the same bytes.

Usage: mkfeedback.py [--root DIR] [--output FILE] [--check] [--summary]
"""
import argparse
import glob
import os
import re
import sys
import textwrap

WIDTH = 96          # body width; the file never exceeds 100 columns
RULE = "=" * WIDTH

CHAPTERS = {
    "1": "1 Introduction", "2": "2 Bus", "3": "3 Graphics and the C64 devices",
    "4": "4 Boot", "5": "5 Drivers and devices",
    "6": "6 Kernel, modes and memory management", "7": "7 Multiple processors",
    "8": "8 Vector work and the accelerator", "9": "9 The instruction set",
    "10": "10 Conclusion: FPGA to silicon", "A": "Appendix A", "B": "Appendix B",
    "D": "Appendix D, the ABI",
}
CHAPTER_ORDER = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "A", "B", "D"]

# ---------------------------------------------------------------- text helpers

FORBIDDEN_SUBS = [
    (re.compile(r"\bj\d{5}\b"), "a message"),
    (re.compile(r"CONTEXTS\.md:\d+"), "a context note"),
    (re.compile(r"\bmessages? \d+"), "message"),
    (re.compile(r"\b\d{4}:\d+\b"), ""),
    (re.compile(r"Q64", re.I), "the bus name held back"),
    (re.compile(r"VIC-64X|SID-64X|BLT64", re.I), "a held native device name"),
    (re.compile(r"/home/\S*"), "a local path"),
    (re.compile(r"silentpc|opusplan", re.I), ""),
    (re.compile(r"\bclaude\b", re.I), "the assistant"),
    (re.compile(r"\bsonnet\b", re.I), "the assistant"),
    (re.compile(r"\bdavid\b", re.I), "the author"),
    (re.compile(r"\bmatthew\b", re.I), "the author"),
]


def sanitize(s):
    for rx, rep in FORBIDDEN_SUBS:
        s = rx.sub(rep, s)
    return s


def plain(s):
    """Markdown to plain text on one logical line."""
    s = re.sub(r"<a id=[^>]*></a>", "", s)
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)", "(figure omitted)", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = s.replace("\\*", "\x01").replace("\\_", "_").replace('\\"', '"')
    s = s.replace("\\'", "'").replace("\\[", "[").replace("\\]", "]")
    s = s.replace("`", "")
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![\w*])", r"\1", s)
    s = s.replace("\x01", "*")
    s = re.sub(r"\((?:P|D|E)\)", "", s)
    s = re.sub(r"\((?:the [^()]*?, )?moved from [^()]*\)", "", s)
    s = re.sub(r"\(moved(?: [^()]*)?\)", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return sanitize(s)


def clip(s, limit, tail=" [...]"):
    """Cut s at a sentence end at or before limit characters."""
    if len(s) <= limit:
        return s
    cut = s[:limit]
    m = max(cut.rfind(". "), cut.rfind("; "), cut.rfind(": "))
    if m < limit // 3:
        m = cut.rfind(" ")
    return cut[:m + 1].rstrip() + tail


def wrap(text, indent="", first=None, width=WIDTH):
    if first is None:
        first = indent
    if not text:
        return [first.rstrip()]
    return textwrap.wrap(text, width=width, initial_indent=first,
                         subsequent_indent=indent, break_long_words=True,
                         break_on_hyphens=False) or [first.rstrip()]


def split_paras(text):
    """Split markdown into paragraphs; drop fenced code (noted) and HTML anchors."""
    out, cur, fence = [], [], False
    for ln in text.split("\n"):
        if ln.strip().startswith("```"):
            if not fence:
                if cur:
                    out.append("\n".join(cur)); cur = []
                out.append("(a code example is omitted here; see the manual)")
            fence = not fence
            continue
        if fence:
            continue
        if not ln.strip():
            if cur:
                out.append("\n".join(cur)); cur = []
        else:
            cur.append(ln)
    if cur:
        out.append("\n".join(cur))
    return [p for p in out if p.strip() and not p.strip().startswith("<a id=")]


# ---------------------------------------------------------------- opcode judgement

STRONG = [
    (r"\bopcodes?\b|sub-opcodes?", "opcodes"),
    (r"\bmnemonics?\b", "mnemonics"),
    (r"\bencoding\b|\bleaf\b|\bparcels?\b", "encoding"),
    (r"\b(?:ADDV|SUBV|MULV|TRAPCC|CHECK|OVF)\b", "checked arithmetic"),
    (r"\b(?:CAS|CASL|CASQ|SWAP|XADD|XAND|XXOR|XMAX|XMIN|LL|SC)\b|atomic", "atomics"),
    (r"\b(?:WFE|FENCE|SEV)\b|memory model|memory order|barrier|sequential consistency|"
     r"total store order", "memory ordering"),
    (r"\b(?:BSEL|CSEL|CMOV|SELECT|MASKEQZ|MASKNEZ|ABS|MINU?|MAXU?)\b|conditional select",
     "select and min/max words"),
    (r"status word|\bPSW\b|condition codes?|\bDIT\b|\bflags?\b|\bFCMP\b", "status word or flags"),
    (r"privileged|supervisor mode|system registers?|\bSYSX\b|\bKTBR\b|\bVBR\b", "privileged or system registers"),
    (r"\bTLBI\w*\b|\bRDTIME\b|\bPUSHM\b|\bPOPM\b|\bMCPY\b|\bMSCN\b|\bPREFETCH\b|\bTRAP\b|"
     r"block operations?", "named instructions"),
    (r"poison bit|user-qualified|\.U qualifier|cryptographic words|MOVUSERD|MSHA|MAESCTR",
     "new or changed words"),
    (r"register (?:number|form|convention|file)|\bR(?:14|16|24)\b|callee-saved|caller-saved",
     "registers"),
    (r"addressing modes?|scaled-index|\bd\(DP\)|directed rounding|half-precision", "instruction forms"),
    (r"translation registers|enabling translation|page-bit|canonical", "virtual memory control"),
]
WEAK = [
    (r"page[- ]table|virtual memory|\bTLB\b|translation|IOMMU", "virtual memory structure"),
    (r"interrupt|vector number|\bvector\b", "interrupt vectors"),
    (r"start register|core 0 starts|state core 0|boot-information|boot ROM|first stage", "start-up state"),
    (r"\bABI\b|calling convention|stack alignment|pointer bits|\bDP\b", "ABI"),
    (r"descriptor|doorbell|queue", "device interface"),
    (r"\bcores?\b|coherence", "multiprocessor behaviour"),
]

# Reasoned overrides: id -> (answer, reason).
OVERRIDE = {
    "J.2.1": ("no", "addresses and boot data only"),
    "J.2.2": ("no", "bus side; no instruction"),
    "J.2.3": ("no", "device translation, not the processor's"),
    "J.2.4": ("no", "virtio features"),
    "J.2.5": ("no", "root complex registers"),
    "J.4.6": ("maybe", "start register or an instruction to start cores"),
    "J.4.9": ("maybe", "initial processor state at reset"),
    "J.5.5": ("yes", "FENCE spelling in C: memory ordering instruction"),
    "J.6.1": ("maybe", "feature or width register: system registers"),
    "J.6.2": ("maybe", "page-table entry format: virtual memory"),
    "J.6.3": ("maybe", "vector numbers, system registers"),
    "J.6.4": ("yes", "system register number"),
    "J.6.5": ("yes", "system-call register convention"),
    "J.6.6": ("yes", "translation-enable instructions"),
    "J.6.7": ("yes", "DP register save and restore"),
    "J.6.8": ("yes", "TLB flush semantics, TLBIASID"),
    "J.6.9": ("yes", "status word mode field"),
    "J.6.10": ("yes", "TRAPCC vector"),
    "J.6.11": ("maybe", "system registers for debug, counters"),
    "J.6.12": ("yes", "user-copy fault: instruction semantics"),
    "J.7.1": ("yes", "WFE semantics"),
    "J.7.2": ("no", "coherence protocol, not an instruction"),
    "J.7.3": ("yes", "atomic operands and encoding"),
    "J.7.4": ("yes", "atomics on uncached memory"),
    "J.7.5": ("no", "core classes, not instructions"),
    "J.8.1": ("no", "a device's operations, not processor opcodes"),
    "J.8.2": ("no", "device descriptor"),
    "J.8.3": ("yes", "packed lanes in ordinary registers: new instructions"),
    "J.10.1": ("maybe", "data-independent timing mode"),
    "J.A.1": ("yes", "pointer bits and the address check"),
    "J.D.1": ("maybe", "stack pointer rule; ABI"),
    "J.D.2": ("maybe", "ABI and PLT stub code"),
    "J.9.7": ("maybe", "latency bound of block operations"),
    "J.9.8": ("yes", "block operations and the cache"),
    "J.9.11": ("yes", "memory model beyond four cores"),
    "J.3.7": ("no", "virtio feature subset"),
    "J.5.7": ("no", "USB controller interface"),
    "J.4.10": ("no", "monitor commands"),
    "J.3.10": ("maybe", "a memory type for the framebuffer: page attribute"),
    "J.3.9": ("maybe", "sugar may be new instructions"),
    "J.3.8": ("maybe", "tear-free flip: maybe a barrier or a register"),
    "J.5.6": ("maybe", "syntactic sugar for devices: maybe new instructions"),
    "J.5.2": ("no", "virtio features"),
    "J.5.3": ("no", "device firmware"),
    "J.5.4": ("no", "device failure handling"),
    "J.4.5": ("no", "device firmware"),
    "J.5.1": ("no", "console, timer, entropy devices"),
    "S.utf-8-operations": ("yes", "new operations on UTF-8 text"),
    "S.combining-group-opcodes": ("yes", "opcode groups and encoding"),
    "S.memory-to-memory-moves-and-block-operations": ("yes", "block and move instructions"),
    "S.learning-from-loongarch": ("maybe", "may adopt more instruction-set ideas"),
    "S.qemu-and-llvm-targets": ("maybe", "targets follow the encoding"),
    "S.c64-in-spirit-not-the-hardware": ("no", "a principle"),
    "S.newlisp-environment": ("no", "a software environment"),
    "S.xdmr-flag-and-default-pdp-11-output": ("no", "a compiler flag"),
    "S.physical-address-width-and-device-windows": ("maybe", "address width: addressing and page tables"),
    "H.8.3.5": ("yes", "POPCNT and XNORPOP as instructions"),
    "H.8.4.5": ("maybe", "a vector engine instead of instructions"),
    "H.9.2": ("yes", "extension instructions of the compiler"),
    "H.9.18": ("yes", "a bounds-checked INDEX instruction"),
    "H.A.4.1": ("maybe", "return-address protection: new instructions or checks"),
    "H.A.10.1": ("yes", "lane operations: new instructions"),
    "H.4.7": ("maybe", "start register for the other cores"),
    "H.4.7.1b": ("maybe", "start register for the other cores"),
    "H.4.4.4": ("no", "a monitor key at power-up"),
    "H.B.1.10.1": ("maybe", "an ABI rule"),
    "V.M17": ("yes", "BSEL, MSHA, MAESCTR, MOVUSERD: instructions"),
    "V.M24": ("yes", "WFE wake rule"),
    "V.M25": ("yes", "TRAPCC and ADDV vector; abort semantics"),
    "V.M26": ("yes", "poison bit, .U qualifier, fixup table"),
    "V.M27": ("maybe", "VBR reset value"),
    "V.M28": ("yes", "supervisor mode in the status word"),
    "V.M13": ("maybe", "start register for other cores"),
    "V.M23": ("yes", "priority on interrupt entry: status word"),
    "V.M18": ("maybe", "sealed page bit, pledge mask: page bits"),
    "V.M19": ("maybe", "taint, retire-gated visibility: new semantics"),
    "V.M2": ("no", "interrupt mechanism of devices"),
    "V.M14": ("no", "device initialization"),
    "V.M22": ("maybe", "register file size estimate for 32 registers"),
    "V.M20": ("no", "board choice"),
    "V.M21": ("no", "order of work"),
    "V.P1": ("yes", "the port waits on the opcode decisions"),
    "V.P2": ("no", "branch merge"),
    "V.P3": ("no", "other project"),
    "V.P4": ("maybe", "tests rewritten with new encodings"),
    "W.1": ("no", "board choice"),
    "W.2": ("yes", "the llvm port follows the opcode decisions"),
    "W.3": ("no", "branch merge"),
}


ISA_CHAPTERS = ("6", "7", "9", "A", "B", "D")


def judge(eid, title, text, chapter=""):
    if eid in OVERRIDE:
        return OVERRIDE[eid]
    head = title + " " + text
    found = []
    for rx, why in STRONG:
        if re.search(rx, head):
            found.append(why)
    if found:
        n = len(found)
        if eid.startswith("H.") or eid.startswith("S."):
            yes = n >= 2 or chapter in ISA_CHAPTERS
            return ("yes" if yes else "maybe", ", ".join(found[:2]))
        return ("yes", ", ".join(found[:2]))
    if (eid.startswith("H.") or eid.startswith("S.")) and chapter in ("9", "A", "B"):
        return ("maybe", "instruction-set chapter")
    weak = [why for rx, why in WEAK if re.search(rx, head)]
    if weak and (chapter in ISA_CHAPTERS or not (eid.startswith("H.") or eid.startswith("S."))):
        return ("maybe", ", ".join(weak[:2]))
    return ("no", "not instruction semantics")


# ---------------------------------------------------------------- entries

class Entry:
    def __init__(self, eid, kind, chapter, title):
        self.id = eid
        self.kind = kind
        self.chapter = chapter
        self.title = title
        self.sections = []      # (label, text) printed as wrapped paragraphs
        self.options = []       # (letter, text); letter "" means a group heading
        self.leaning = ""
        self.prec = ""
        self.ref = ""
        self.where = ""
        self.notes = []
        self.affects = "no"
        self.reason = ""
        self.seq = (0, 0)
        self.order = 0
        self.related = []
        self.fulltext = ""


def parse_j(root):
    entries = []
    files = sorted(glob.glob(os.path.join(root, "docs/manual-src/appendix-parts/*-open.md")))
    for f in files:
        text = open(f, encoding="utf-8").read()
        for m in re.finditer(r'^<a id="(\w+)"></a>\n### J\.([0-9A-Z]+)\.(\d+) (.*?)\n(.*?)(?=^<a id="|\Z)',
                             text, re.S | re.M):
            chap, num, title, body = m.group(2), m.group(3), m.group(4), m.group(5)
            eid = "J.%s.%s" % (chap, num)
            e = Entry(eid, "open item", chap if chap in CHAPTERS else "A", plain(title))
            e.seq = (CHAPTER_ORDER.index(chap) if chap in CHAPTER_ORDER else 99, int(num))
            parse_j_body(e, body)
            entries.append(e)
    return entries


HEADS = {
    "Issue.": "issue", "Why it matters.": "why", "Precedents.": "prec",
    "The author's referents.": "ref", "The assistant's leaning.": "lean",
    "Where the body refers to it.": "where",
}


def parse_j_body(e, body):
    paras = split_paras(body)
    cur = None
    store = {"issue": [], "why": [], "prec": [], "ref": [], "lean": [], "where": [], "extra": []}
    group = ""
    opt_texts = []   # (group, text)
    for p in paras:
        first = p.lstrip()
        mh = re.match(r"\*\*([^*]+)\*\*(.*)", first, re.S)
        if re.match(r"\d+\. ", first):
            items = re.split(r"\n(?=\d+\. )", first)
            for it in items:
                mnum = re.match(r"(\d+)\. ", it)
                t = plain(re.sub(r"^\d+\.\s*", "", it))
                opt_texts.append((group, t, int(mnum.group(1)) if mnum else 0))
                group = ""
            continue
        if mh:
            h, rest = mh.group(1), mh.group(2)
            if h in HEADS:
                cur = HEADS[h]
                if plain(rest):
                    store[cur].append(plain(rest))
                continue
            if h.startswith("Options"):
                cur = "options"
                lab = plain(rest).strip(" .")
                group = (plain(h).rstrip(".") + (" " + lab if lab else "")).rstrip(".")
                continue
            cur = "extra"
            full = plain(first)
            if re.search(r"\(a\) .*\(b\) ", full):
                lead, rest2 = re.split(r"\(a\) ", full, maxsplit=1)
                parts = re.split(r"\s*\(([a-z])\)\s", "(a) " + rest2)
                for i in range(1, len(parts) - 1, 2):
                    opt_texts.append((lead.strip() if i == 1 else "", "(%s) %s" % (parts[i], parts[i + 1].strip()), 0))
            else:
                store["extra"].append(full)
            continue
        if cur is None:
            continue
        if first.startswith("* "):
            txt = "; ".join(plain(re.sub(r"^[*-]\s+", "", l)) for l in first.split("\n") if l.strip())
        else:
            txt = plain(first)
        if cur == "options":
            store["extra"].append(txt)
        else:
            store[cur].append(txt)
    issue = " ".join(store["issue"])
    e.sections.append(("Issue", clip(issue, 620) + ("  (Full text: Appendix J, %s.)" % e.id if len(issue) > 620 else "")))
    why = " ".join(store["why"])
    if why:
        e.sections.append(("Why it matters", clip(why, 330)))
    for x in store["extra"]:
        e.sections.append(("Further", clip(x, 420)))
    letter = 0
    numap = {}
    for g, t, num in opt_texts:
        if num:
            numap[num] = chr(65 + letter) if letter < 26 else "Z"
        if g:
            e.options.append(("", g.rstrip(".:") + ":"))
        e.options.append((chr(65 + letter) if letter < 26 else "Z", t))
        letter += 1
    relabel = lambda x: re.sub(r"\b([Oo]ptions?) (\d+)\b", lambda m: "%s %s" % (m.group(1), numap.get(int(m.group(2)), m.group(2))), x)
    e.options = [(l, relabel(t)) for l, t in e.options]
    if not opt_texts:
        e.options.append(("A", "Accept the assistant's leaning below. For: it settles the item. Against: no alternative was written down."))
        e.options.append(("B", "Choose differently (say how in NOTE)."))
    e.leaning = relabel(" ".join(store["lean"]))
    e.prec = clip(" ".join(store["prec"]), 900)
    e.ref = clip(" ".join(store["ref"]), 700)
    e.where = " ".join(store["where"])
    e.fulltext = " ".join([issue, why] + store["extra"] + [t for _, t, _n in opt_texts])


# ---- appendix H

ID_RX = re.compile(r"^\*\*((?:[A-D]\.)?\d+(?:\.\d+)*[a-z]?)\b[^*]*\*\*")


def parse_h(root):
    entries = []
    seen = {}
    files = sorted(glob.glob(os.path.join(root, "docs/manual-src/appendix-parts/*-proposed.md")))
    for f in files:
        base = os.path.basename(f).split("-")[0]
        text = open(f, encoding="utf-8").read()
        chap = (base.lstrip("0") or "0").upper()
        if chap not in CHAPTERS:
            chap = "A"
        state = {"cur": None}
        sec_n = [0]

        def finish():
            en = state["cur"]
            state["cur"] = None
            if en is None or not en._paras:
                return
            body = " ".join(en._paras)
            if "(E)" in en._raw and "(P)" not in en._raw and "(D)" not in en._raw:
                return  # evidence, not a proposal
            n = seen.get(en.id, 0)
            seen[en.id] = n + 1
            if n:
                en.id += chr(ord("a") + n - 1)
            en.fulltext = body
            en.sections.append(("Proposal and explanation", clip(body, 1500, " [... full text in Appendix H]")))
            en.options = [
                ("A", "Accept as proposed. For: it settles the statement. Against: the proposal is the assistant's, not yet the author's."),
                ("B", "Reject it. For: removes an unwanted statement. Against: the manual then needs the gap filled another way."),
                ("C", "Accept with changes (type the changes in NOTE)."),
            ]
            entries.append(en)

        for p in split_paras(text):
            first = p.lstrip()
            hm = re.match(r"#{3,4} (.*)", first)
            if hm:
                finish()
                title = plain(hm.group(1))
                sm = re.match(r"((?:[A-D]\.)?\d+(?:\.\d+)*)\b", title)
                if sm:
                    sid = sm.group(1)
                else:
                    sec_n[0] += 1
                    sid = "%s.s-%s" % (chap, re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:32].strip("-"))
                en = Entry("H." + sid, "proposal", chap, title)
                en._paras, en._raw, en.is_section = [], "", True
                en.seq = (CHAPTER_ORDER.index(chap), len(entries))
                state["cur"] = en
                continue
            im = ID_RX.match(first)
            if im:
                finish()
                body = plain(first)
                en = Entry("H." + im.group(1), "proposal", chap, clip(body, 80, "..."))
                en._paras, en._raw, en.is_section = [body], first, False
                en.seq = (CHAPTER_ORDER.index(chap), len(entries) + 1)
                state["cur"] = en
                continue
            en = state["cur"]
            if en is None:
                continue
            en._paras.append(plain(first))
            en._raw += first
        finish()
    return entries


# ---- confirmation list

def parse_veto(root):
    path = os.path.join(root, "docs/decision-log/data/shared/veto-list.txt")
    entries = []
    for ln in open(path, encoding="utf-8").read().split("\n"):
        m = re.match(r"^([MHIP]\d+) \| (.*)$", ln)
        if not m:
            continue
        code = m.group(1)
        parts = [x.strip() for x in re.split(r"(?<=\s)\|(?=\s|$)", ln[len(code):].lstrip(" |").join(["", ""]) if False else m.group(2))]
        while len(parts) < 4:
            parts.append("")
        item, treat, evid, quest = parts[:4]
        e = Entry("V." + code, "confirmation", "C", plain(item))
        e.seq = ("MHIP".index(code[0]), int(code[1:]))
        if treat:
            e.sections.append(("Current treatment", plain(treat)))
        if evid:
            e.sections.append(("Evidence", plain(evid)))
        e.sections.append(("Question", plain(quest) or "Is this right?"))
        e.options = [
            ("A", "Yes, it is right as stated. For: closes the item. Against: none stated."),
            ("B", "No, change it (say how in NOTE)."),
        ]
        e.fulltext = " ".join([item, treat, evid, quest])
        entries.append(e)
    return entries


# ---- status ledger

def parse_ledger(root):
    text = open(os.path.join(root, "docs/decisions-and-status.md"), encoding="utf-8").read().split("\n")
    entries = []
    section = None
    chap = ""
    cur = None
    kinds = {"# Left to do": "to do", "# Left in the air": "in the air"}
    subj = []
    for ln in text:
        if ln.startswith("# "):
            if cur is not None:
                subj.append(cur)
            cur = None
            section = None
            for k, v in kinds.items():
                if ln.startswith(k):
                    section = v
            continue
        if section is None:
            continue
        if ln.startswith("## "):
            if cur is not None:
                subj.append(cur)
            cur = None
            chap = plain(ln[3:])
            continue
        if ln.startswith("### "):
            if cur is not None:
                subj.append(cur)
            cur = {"kind": section, "chap": chap, "title": plain(ln[4:]), "f": {}}
            continue
        if cur is not None:
            m = re.match(r"^- (Status|Decided|Left|Rationale|Doc differs): (.*)$", ln)
            if m and m.group(1) not in cur["f"]:
                cur["f"][m.group(1)] = m.group(2)
    if cur is not None:
        subj.append(cur)
    used = set()
    for s in subj:
        st = s["f"].get("Status", "")
        if s["kind"] == "to do" and not re.search(r"details|to be determined", st):
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", s["title"].lower()).strip("-")[:44].strip("-")
        eid = "S." + slug
        n = 2
        while eid in used:
            eid = "S.%s-%d" % (slug, n)
            n += 1
        used.add(eid)
        e = Entry(eid, "ledger: " + s["kind"], s["chap"], s["title"])
        e.seq = (0 if s["kind"] == "to do" else 1, len(entries))
        status = re.sub(r"^(TO DO|IN THE AIR)\s*[-—]*\s*", "", plain(st))
        e.sections.append(("Status", status))
        dec = plain(s["f"].get("Decided", ""))
        if dec:
            e.sections.append(("What the author said", clip(dec, 600)))
        left = plain(s["f"].get("Left", ""))
        e.sections.append(("What is missing", clip(left, 600) if left else "Nothing is written down."))
        e.related = sorted(set(re.findall(r"J\.\d+\.\d+|J\.[A-Z]\.\d+", s["f"].get("Left", "") + s["f"].get("Status", ""))))
        if e.related:
            e.notes.append("Related open items: " + ", ".join(e.related))
        if s["kind"] == "to do":
            e.options = [
                ("A", "Decide the details now (type them in NOTE). For: the item can then be built. Against: may be early."),
                ("B", "Keep waiting for the stated condition. For: no premature detail. Against: stays open."),
                ("C", "Drop the item. For: less to do. Against: the earlier decision then has no follow-up."),
            ]
        else:
            e.options = [
                ("A", "Decide it (type the decision in NOTE). For: closes a loose end. Against: may be early."),
                ("B", "Drop it (not wanted). For: removes noise. Against: the idea is lost."),
                ("C", "Keep it as an idea; no decision now. For: nothing is lost. Against: stays in the air."),
            ]
        e.fulltext = " ".join([s["title"], st, dec, left])
        entries.append(e)
    return entries


def standing():
    out = []
    spec = [
        ("W.1", "Which first FPGA board",
         "No board is named in the author's words. The manual proposes the DE10-Nano first and the Zybo Z7-20 or the Kria KV260 when timing "
         "limits; on paper estimates four cores with the floating-point unit fit only a Kria-class board, and no core has been synthesised. "
         "See also V.M20.",
         ["DE10-Nano (Cyclone V SE, hard Cortex-A9, HDMI, MiSTer ecosystem). For: cheap, popular, a hard processor for the harness. Against: smallest logic budget; may not hold the float unit with more than one core.",
          "Zybo Z7-20 (Zynq 7020). For: moderate size, hard Cortex-A9. Against: no hard PCI Express root complex.",
          "Kria KV260 (Zynq UltraScale+). For: largest budget of the three, has a hard root complex. Against: dearest.",
          "ULX3S (open toolchain). For: open tools. Against: loses the hard-core harness."]),
        ("W.2", "Port llvm/ to the new encoding",
         "Decided by the author: yes, after the items that change opcodes, mnemonics or the encoding are resolved. llvm/ is frozen and "
         "its machine-code layer encodes the old r20 encoding. See also V.P1.",
         ["Confirm: port after the opcode-affecting items are decided. For: avoids porting twice. Against: llvm waits.",
          "Port now to the current encoding, redo later. For: llvm moves. Against: likely double work."]),
        ("W.3", "pcc: merge the single-pdp64 branch into master",
         "The branch is pushed; master of pcc is unchanged. See also V.P2.",
         ["Merge now. For: master matches the decided machine. Against: other users of master lose the old targets.",
          "Merge after the opcode-affecting items. For: one merge for the final encoding. Against: master lags.",
          "Do not merge; keep the branch. For: nothing disturbed. Against: two lines to maintain."]),
    ]
    for i, (eid, title, issue, opts) in enumerate(spec):
        e = Entry(eid, "standing decision", "W", title)
        e.seq = (0, i)
        e.sections.append(("Issue", issue))
        for j, o in enumerate(opts):
            e.options.append((chr(65 + j), o))
        e.fulltext = title + " " + issue + " " + " ".join(opts)
        out.append(e)
    return out


# ---------------------------------------------------------------- rendering

def index_line(e):
    t = e.title
    if len(t) > 56:
        t = t[:53] + "..."
    return "  %4d  %-30s %s" % (e.order, e.id[:30], t)


def render(entries, groups):
    L = []
    A = L.append
    A("PDP64 DECISIONS AND STATUS: FEEDBACK FORM")
    A("")
    A("This file is generated by tools/feedback/mkfeedback.py from the open items (Appendix J), the")
    A("proposals (Appendix H), the confirmation list and the status ledger. Re-run the generator")
    A("after any chapter edit; answer by typing on the DECISION and NOTE lines only.")
    A("")
    A("HOW TO ANSWER (read in the pager, edit, write the file)")
    A("")
    A("  Open items (J.*): read the issue and the lettered options; on the line 'DECISION:' type a")
    A("    letter, several letters ('A, C'), 'other: your text', or 'defer'. Put reasons or your")
    A("    own wording on the 'NOTE:' line (it may continue on indented lines below it).")
    A("  Proposals (H.*): each is a statement the assistant proposed. Type A (accept), B (reject)")
    A("    or C (accept with changes; write the changes in NOTE), or 'defer'.")
    A("  Confirmations (V.*): 'Is this right?' Type A (yes) or B (no, with the change in NOTE).")
    A("  Ledger subjects (S.*) and standing decisions (W.*): type a letter, 'other: ...' or")
    A("    'defer'; details of a decision go in NOTE. Lines 'Leaning (assistant)' are not decisions.")
    A("  New questions and decisions of your own: the last section, free text.")
    A("  Entries are in ORDER: those with 'AFFECTS OPCODES: yes' come first, then 'maybe', then 'no',")
    A("  because a decision there can change opcodes, mnemonics or the encoding. Cited rows 'R<n>'")
    A("  are rows of the decision register (docs/decision-register.md). Notes made with the pager's")
    A("  annotation keys are read back as well, by line.")
    A("")
    A(RULE)
    A("INDEX BY AFFECTS OPCODES")
    A(RULE)
    for aff in ("yes", "maybe", "no"):
        sel = [e for e in entries if e.affects == aff]
        A("")
        A("AFFECTS OPCODES: %s  (%d entries)" % (aff, len(sel)))
        for e in sel:
            A(index_line(e))
    A("")
    A(RULE)
    A("INDEX BY CHAPTER")
    A(RULE)
    for key, label in groups:
        sel = sorted((e for e in entries if e.group == key), key=lambda x: x.order)
        if not sel:
            continue
        A("")
        A("%s  (%d entries)" % (label, len(sel)))
        for e in sel:
            A(index_line(e))
    for e in entries:
        A("")
        A(RULE)
        A("ENTRY %s" % e.id)
        A("ORDER: %d   KIND: %s   CHAPTER: %s" % (e.order, e.kind, e.chapter_label))
        L.extend(wrap("TITLE: " + e.title, "   "))
        L.extend(wrap("AFFECTS OPCODES: %s (%s)" % (e.affects, e.reason), "   "))
        A("-" * WIDTH)
        for label, txt in e.sections:
            L.extend(wrap("%s: %s" % (label.upper(), txt), "   "))
        for n in e.notes:
            L.extend(wrap(n, "   "))
        if e.options:
            A("OPTIONS:")
            for letter, txt in e.options:
                if not letter:
                    L.extend(wrap(txt, "     ", "  "))
                else:
                    L.extend(wrap(txt, "      ", "   %s) " % letter))
        if e.leaning:
            L.extend(wrap("Leaning (assistant, not a decision): " + e.leaning, "   "))
        if e.prec:
            L.extend(wrap("PRECEDENTS: " + e.prec, "   "))
        if e.ref:
            L.extend(wrap("AUTHOR'S REFERENTS: " + e.ref, "   "))
        if e.where:
            L.extend(wrap("BODY: " + e.where, "   "))
        A("")
        A("DECISION: ")
        A("NOTE: ")
    A("")
    A(RULE)
    A("NEW QUESTIONS AND DECISIONS")
    A(RULE)
    A("")
    A("Type below any new question, decision or instruction, in your own words. Each block starts")
    A("at a line '--- NEW n ---' and runs to the next one; copy a block to add more.")
    for i in range(1, 6):
        A("")
        A("--- NEW %d ---" % i)
        A("TEXT: ")
    A("")
    A("END OF FORM")
    return "\n".join(L) + "\n"


def build(root):
    entries = []
    entries += parse_j(root)
    entries += parse_h(root)
    entries += parse_veto(root)
    entries += parse_ledger(root)
    entries += standing()
    seen = set()
    for e in entries:
        base, n = e.id, 2
        while e.id in seen:
            e.id = "%s.%d" % (base, n)
            n += 1
        seen.add(e.id)
    by_id = {e.id: e for e in entries}
    kind_rank = {"open item": 0, "proposal": 1, "confirmation": 2, "standing decision": 3}
    for e in entries:
        e.krank = kind_rank.get(e.kind, 4)
        text = e.sections[0][1] if e.kind == "open item" else e.fulltext
        e.affects, e.reason = judge(e.id, e.title, text, e.chapter)
    rank = {"no": 0, "maybe": 1, "yes": 2}
    for e in entries:
        if e.kind.startswith("ledger") and e.related:
            rel = [by_id[r] for r in e.related if r in by_id]
            if rel:
                best = max(rel, key=lambda x: rank[x.affects])
                e.affects, e.reason = best.affects, "as %s: %s" % (best.id, best.reason)
    tier = {"yes": 0, "maybe": 1, "no": 2}
    entries.sort(key=lambda e: (tier[e.affects], e.krank, e.seq[0] if isinstance(e.seq[0], int) else 0,
                                e.seq[1], e.id))
    groups = [(c, CHAPTERS[c]) for c in CHAPTER_ORDER]
    groups += [("C", "Confirmation list"), ("W", "Standing decisions"), ("L", "Status ledger (by its own chapter)")]
    for i, e in enumerate(entries, 1):
        e.order = i
        if e.kind.startswith("ledger"):
            e.group, e.chapter_label = "L", (e.chapter or "ledger")
        elif e.kind == "confirmation":
            e.group, e.chapter_label = "C", "Confirmation list"
        elif e.kind == "standing decision":
            e.group, e.chapter_label = "W", "Standing decisions"
        else:
            e.group = e.chapter if e.chapter in CHAPTERS else "A"
            e.chapter_label = CHAPTERS[e.group]
    return entries, groups


def counts(entries):
    out = {}
    for e in entries:
        k = e.kind.split(":")[0]
        out.setdefault(k, {"yes": 0, "maybe": 0, "no": 0})
        out[k][e.affects] += 1
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(here)))
    ap.add_argument("--output", default=None)
    ap.add_argument("--check", action="store_true", help="fail if the output file is out of date")
    ap.add_argument("--summary", action="store_true", help="print counts")
    a = ap.parse_args(argv)
    out = a.output or os.path.join(a.root, "docs/feedback/decisions-feedback.txt")
    entries, groups = build(a.root)
    text = render(entries, groups)
    over = [i + 1 for i, l in enumerate(text.split("\n")) if len(l) > 100]
    if over:
        sys.exit("mkfeedback: lines over 100 columns: %s" % over[:5])
    if a.summary:
        c = counts(entries)
        print("entries: %d" % len(entries))
        for k, v in sorted(c.items()):
            print("  %-18s %3d  (yes %d, maybe %d, no %d)" % (k, sum(v.values()), v["yes"], v["maybe"], v["no"]))
    if a.check:
        cur = open(out, encoding="utf-8").read() if os.path.exists(out) else None
        if cur != text:
            sys.exit("mkfeedback: %s is out of date; run tools/feedback/mkfeedback.py" % out)
        print("mkfeedback: up to date")
        return 0
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
