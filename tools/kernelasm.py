#!/usr/bin/env python3
"""kernelasm.py: mnemonic statistics of the hand-written assembly of the Linux, FreeBSD, NetBSD and OpenBSD kernels, compared with what compilers emit.

Research use only.  The kernel sources are GPL or BSD licensed; nothing is copied into this repository, only counts of mnemonics.

HOW TO REPRODUCE (the revisions used for docs/kernel-asm-survey.md are in that document and in docs/codegen-data/kernelasm/sources.txt)
  1. Clone, blobless and sparse, OUTSIDE the repository (nothing under kernel-src is ever committed):
       mkdir -p ~/claude/kernel-src && cd ~/claude/kernel-src
       git clone --depth 1 --filter=blob:none --sparse https://github.com/torvalds/linux linux
       git clone --depth 1 --filter=blob:none --sparse https://github.com/freebsd/freebsd-src freebsd
       git clone --depth 1 --filter=blob:none --sparse https://github.com/NetBSD/src netbsd
       git clone --depth 1 --filter=blob:none --sparse https://github.com/openbsd/src openbsd
     then in each clone `git sparse-checkout set <dirs>`; the directories are listed in docs/kernel-asm-survey.md section 2
     (Linux arch/{x86,arm64,arm,riscv,mips,powerpc,loongarch,m68k,sparc,s390,alpha}/{kernel,lib,mm,boot,include,entry,kvm} and a few more;
     FreeBSD sys/{amd64,i386,x86,arm64,arm,riscv,powerpc}; NetBSD sys/arch/{vax,m68k,alpha,sparc64,sparc,amd64,x86,i386,aarch64,riscv,arm,mips,powerpc,
     hp300,sun3,mac68k,amiga,hppa} and sys/lib/libkern/arch; OpenBSD sys/arch/{amd64,i386,arm64,armv7,arm,riscv64,powerpc,powerpc64,sparc64,mips64,
     alpha,hppa,m88k} and sys/lib/libkern/arch).
  2. The compiled-code side is the assembly of the fair corpus, /tmp/p64opt/archcmp/<arch>/*.s (the comparison agent's output).
  3. python3 tools/kernelasm.py all --src ~/claude/kernel-src --corpus /tmp/p64opt/archcmp --out docs/codegen-data/kernelasm
     (sub-commands: extract, corpus, join, sample FAMILY KERNEL N, all).
  Date of the first run: 2026-10-22.

METHOD
  Assembler files (.S, .s): comments and C comments are removed, preprocessor lines are dropped (but the bodies of `#define` are kept, since they hold
  instructions), labels are removed, the statement is split on `;`, and the first word of each statement is the mnemonic.  Directives (a word that starts with `.`)
  are skipped.  A word that contains an upper-case letter is taken to be a macro invocation and is counted apart (kernel_macros.csv), except for a small table of
  macros that are one instruction (WRAPPERS below).  A lower-case word that is the name of a macro defined in the same tree is skipped as well.
  C and header files: every `asm`, `__asm__`, `__asm`, `asm volatile`, `asm goto` and `asm_inline` is found, its parenthesis is read, all string literals
  before the first top-level `:` are joined (this also takes the strings that are arguments of ALTERNATIVE-style wrapper macros), `\\n` and `\\t` are turned into
  separators, and the result is parsed like assembler.  A few well known identifier macros between the strings are expanded (LOCK_PREFIX, _ASM_MOV, ...).
  Stringized macro parameters (`#op`) hide a mnemonic; they are resolved in a second pass when the macro is invoked with a literal argument.
  Normalisation (norm()): the same function is applied to the kernel side and to the compiler side so that the two are comparable.
    x86: AT&T size suffix b/w/l/q (and 64) stripped when the stem is a known mnemonic; lock/rep prefixes kept as part of the mnemonic ("lock add", "rep movs");
         movzbl-style forms become movzx and movsbl-style forms movsx; jcc, cmovcc and setcc become j.cc, cmov.cc, set.cc.
    arm (32-bit): condition code suffixes and the flag-setting `s` removed when the stem is a known mnemonic.
    aarch64: `b.eq` and friends become b.cond.   riscv: .aq/.rl/.aqrl and the compressed `c.` prefix removed; .w/.d kept.
    ppc: trailing `.` (record form), `+`/`-` (branch hints) removed.   sparc: annul/predict suffixes after a comma removed.   alpha: /v /su... removed.
    m68k: .b/.w/.l/.s removed.   vax: trailing operand count 2/3/4 removed (addl3 is addl).   mips, loongarch, s390: unchanged.
  The kernel statistics are STATIC (instruction statements in the source), not weighted by how often they run.
"""
import argparse, csv, os, re, sys
from collections import Counter, defaultdict

# --------------------------------------------------------------------------------------------------------------------
# which files belong to which (kernel, family)
# --------------------------------------------------------------------------------------------------------------------
LINUX_ARCH = {'x86': 'x86', 'arm64': 'arm64', 'arm': 'arm', 'riscv': 'riscv', 'mips': 'mips', 'powerpc': 'ppc', 'loongarch': 'loongarch',
              'm68k': 'm68k', 'sparc': 'sparc', 's390': 's390', 'alpha': 'alpha'}
FREEBSD_DIR = {'amd64': 'x86', 'i386': 'x86', 'x86': 'x86', 'arm64': 'arm64', 'arm': 'arm', 'riscv': 'riscv', 'powerpc': 'ppc'}
NETBSD_ARCH = {'vax': 'vax', 'm68k': 'm68k', 'hp300': 'm68k', 'sun3': 'm68k', 'mac68k': 'm68k', 'amiga': 'm68k', 'alpha': 'alpha', 'sparc64': 'sparc',
               'sparc': 'sparc', 'amd64': 'x86', 'x86': 'x86', 'i386': 'x86', 'aarch64': 'arm64', 'riscv': 'riscv', 'arm': 'arm', 'mips': 'mips',
               'powerpc': 'ppc', 'hppa': 'hppa'}
OPENBSD_ARCH = {'amd64': 'x86', 'i386': 'x86', 'arm64': 'arm64', 'armv7': 'arm', 'arm': 'arm', 'riscv64': 'riscv', 'powerpc': 'ppc', 'powerpc64': 'ppc',
                'sparc64': 'sparc', 'mips64': 'mips', 'alpha': 'alpha', 'hppa': 'hppa', 'm88k': 'm88k'}
LIBKERN_ARCH = {'x86_64': 'x86', 'amd64': 'x86', 'i386': 'x86', 'aarch64': 'arm64', 'arm': 'arm', 'riscv': 'riscv', 'mips': 'mips', 'powerpc': 'ppc',
                'm68k': 'm68k', 'vax': 'vax', 'alpha': 'alpha', 'sparc64': 'sparc', 'sparc': 'sparc', 'hppa': 'hppa', 'mips64': 'mips',
                'powerpc64': 'ppc', 'm88k': 'm88k', 'arm64': 'arm64', 'riscv64': 'riscv', 'armv7': 'arm'}
# path pieces that are not kernel code: crypto (SIMD kernels would drown the statistics), device trees, selftests
SKIP_PARTS = ('/crypto/', '/dts/', '/tools/testing/', '/configs/', '/boot/dts/', '/dist/', '.lds.S', '/vdso/', '/fpsp040/', '/ifpsp060/', '/math-emu/')
ASM_EXT = ('.S', '.s')
C_EXT = ('.c', '.h', '.cc', '.inc')

def classify_path(kernel, rel):
    """return family for a path relative to the clone root, or None"""
    p = '/' + rel
    if any(s in p for s in SKIP_PARTS):
        return None
    parts = rel.split('/')
    if kernel == 'linux':
        if parts[0] == 'arch' and len(parts) > 2 and parts[1] in LINUX_ARCH:
            return LINUX_ARCH[parts[1]]
    elif kernel == 'freebsd':
        if parts[0] == 'sys' and len(parts) > 2 and parts[1] in FREEBSD_DIR:
            return FREEBSD_DIR[parts[1]]
    elif kernel == 'netbsd':
        if rel.startswith('sys/arch/') and len(parts) > 3:
            return NETBSD_ARCH.get(parts[2])
        if rel.startswith('sys/lib/libkern/arch/') and len(parts) > 5:
            return LIBKERN_ARCH.get(parts[4])
    elif kernel == 'openbsd':
        if rel.startswith('sys/arch/') and len(parts) > 3:
            return OPENBSD_ARCH.get(parts[2])
        if rel.startswith('sys/lib/libkern/arch/') and len(parts) > 5:
            return LIBKERN_ARCH.get(parts[4])
    return None

# --------------------------------------------------------------------------------------------------------------------
# syntax per family
# --------------------------------------------------------------------------------------------------------------------
COMMENT = {  # regex of a line comment, searched outside string literals
    'x86': r'#', 'arm64': r'//', 'arm': r'@', 'riscv': r'#', 'mips': r'#', 'ppc': r'#', 'loongarch': r'#', 'm68k': r'\|', 'sparc': r'!',
    's390': r'#', 'alpha': r'#', 'vax': r'#', 'hppa': r';', 'm88k': r';',
}
NO_SEMI = {'hppa', 'm88k'}   # ';' starts a comment there, so it is not a separator
CORPUS_COMMENT = dict(COMMENT)
CORPUS_COMMENT.update({'m68k': r'[|#]', 'pdp64': r';'})

# one-instruction macros of assembler files (upper-case words)
WRAPPERS = {
    'x86': {'SWAPGS': 'swapgs', 'SYSRETQ': 'sysret', 'SYSRETL': 'sysret', 'SYSRET64': 'sysret', 'IRETQ': 'iret', 'IRET': 'iret', 'IRETL': 'iret',
            'SYSEXIT': 'sysexit', 'SWAPGS_UNSAFE_STACK': 'swapgs', 'INTERRUPT_RETURN': 'iret', 'ENABLE_INTERRUPTS': 'sti', 'DISABLE_INTERRUPTS': 'cli',
            'LOCK': 'lock', 'MPLOCKED': 'lock', 'LOCK_PREFIX': 'lock', 'RET': 'ret', 'STI': 'sti', 'CLI': 'cli', 'HLT': 'hlt',
            'CLAC': 'clac', 'STAC': 'stac', 'ASM_CLAC': 'clac', 'ASM_STAC': 'stac', 'ENDBR': 'endbr64', 'CALLQ': 'call', 'RETQ': 'ret',
            'SWAPGS_FENCE': 'lfence', 'NOP': 'nop', 'UD2': 'ud2', 'INT3': 'int3', 'LRET': 'lret', 'LRETQ': 'lret', 'PAUSE': 'pause', 'CPUID': 'cpuid',
            'RDMSR': 'rdmsr', 'WRMSR': 'wrmsr', 'RDTSC': 'rdtsc'},
    'ppc': {'RFI': 'rfi', 'RFID': 'rfid', 'RFEBB': 'rfebb', 'HRFID': 'hrfid', 'MTMSRD': 'mtmsrd', 'MTMSR': 'mtmsr', 'SYNC': 'sync', 'ISYNC': 'isync',
            'EIEIO': 'eieio', 'LWSYNC': 'lwsync', 'MFMSR': 'mfmsr', 'TLBSYNC': 'tlbsync', 'TLBIE': 'tlbie', 'RFCI': 'rfci', 'RFMCI': 'rfmci', 'RFDI': 'rfdi',
            'SC': 'sc', 'TRAP': 'trap', 'BLR': 'blr', 'BCTR': 'bctr', 'MFSPR': 'mfspr', 'MTSPR': 'mtspr'},
}

def strip_c_comments(text):
    return re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), text, flags=re.S)

def strip_line_comment(line, fam, table=COMMENT):
    """cut a line comment outside of double quotes"""
    rx = re.compile(table.get(fam, '#'))
    out = []
    inq = False
    i = 0
    while i < len(line):
        c = line[i]
        if c == '"' and (i == 0 or line[i - 1] != '\\'):
            inq = not inq
        if not inq and rx.match(line, i):
            break
        out.append(c)
        i += 1
    return ''.join(out)

# --------------------------------------------------------------------------------------------------------------------
# normalisation of mnemonics
# --------------------------------------------------------------------------------------------------------------------
X86_BASE = set('''mov movabs lea push pop pushf popf pusha popa pushad popad call jmp ret lret leave enter nop xchg cmpxchg cmpxchg8b cmpxchg16b xadd
add sub adc sbb and or xor not neg inc dec mul imul div idiv cmp test bt bts btr btc bsf bsr tzcnt lzcnt popcnt shl shr sar sal rol ror rcl rcr shld shrd
cbw cwd cdq cqo cwde cdqe cltq cqto cltd cwtl cbtw cwtd cld std cli sti hlt pause lfence mfence sfence clflush clflushopt clwb invd wbinvd invlpg invpcid
rdmsr wrmsr rdtsc rdtscp rdpmc cpuid swapgs sysret sysexit sysenter syscall iret lcall ljmp lgdt lidt sgdt sidt lldt ltr sldt str lmsw smsw clts verr verw lar lsl
in out ins outs movs stos scas cmps lods fxsave fxrstor xsave xrstor xsaveopt xsavec xsaves xrstors fnstcw fldcw fnstsw fninit fnsave frstor fwait wait emms
rdrand rdseed rdfsbase wrfsbase rdgsbase wrgsbase stac clac vmcall vmlaunch vmresume vmxon vmxoff vmread vmwrite vmptrld vmptrst vmclear vmmcall vmrun vmload
vmsave clgi stgi int int3 into ud2 monitor mwait monitorx mwaitx umonitor umwait tpause xgetbv xsetbv rdpkru wrpkru endbr64 endbr32 rdpid bswap sahf lahf
cmc clc stc xlat xlatb movbe crc32 prefetcht0 prefetcht1 prefetcht2 prefetchnta prefetchw ldmxcsr stmxcsr fld fldz fld1 fst fstp fild fistp fadd fmul fsub fdiv
fxch fchs fabs fsqrt fcom fcomp fucom fucomp fucomi fucomip fcomi fcomip fnstenv fldenv fnclex fnop invept invvpid rsm getsec
adcx adox mulx rorx sarx shlx shrx andn bextr blsi blsmsk blsr bzhi pdep pext serialize rdssp incssp saveprevssp rstorssp wrss wruss setssbsy clrssbsy
ud0 ud1 icebp retf aam aad aaa aas daa das bound arpl xend xbegin xabort xtest enqcmd enqcmds movdir64b movdiri wbnoinvd cldemote
tdcall seamcall seamret senduipi uiret clui stui testui hreset lkgs eretu erets invlpgb tlbsync stosb'''.split())
X86_PREFIX = {'lock', 'rep', 'repz', 'repe', 'repnz', 'repne', 'data16', 'data32', 'rex', 'rex64', 'rex.w', 'notrack', 'bnd', 'xacquire', 'xrelease', 'addr32'}
X86_JCC = set('jo jno jb jnae jc jnb jae jnc je jz jne jnz jbe jna ja jnbe js jns jp jpe jnp jpo jl jnge jge jnl jle jng jg jnle jcxz jecxz jrcxz'.split())
ARM_BASE = set('''adc add adr adrl and asr b bfc bfi bic bkpt bl blx bx bxj cbnz cbz cdp cdp2 clrex clz cmn cmp cps cpsid cpsie csdb dbg dmb dsb eor eret hvc isb it ite itt itte ittt
ldc ldc2 ldm ldmda ldmdb ldmia ldmib ldr ldrb ldrbt ldrd ldrex ldrexb ldrexd ldrexh ldrh ldrht ldrsb ldrsbt ldrsh ldrsht ldrt lsl lsr mcr mcr2 mcrr mla mls mov movt movw mrc mrc2 mrrc
mrs msr mul mvn nop orn orr pkhbt pld pldw pli pop push qadd qsub rbit rev rev16 revsh rfe ror rrx rsb rsc sbc sbfx sdiv sel sev sevl smc smlal smull srs ssat stc stc2 stm stmda stmdb stmia stmib str strb strbt strd
strex strexb strexd strexh strh strht strt sub svc swp swpb sxtb sxth tbb tbh teq tst ubfx udf udiv umlal umull usat uxtb uxth vabs vadd vcmp vcvt vdiv vldm vldr vmov vmrs vmsr vmul vneg vpop vpush vsqrt vstm vstr vsub
wfe wfi yield sxtab uxtab setend ssbb pssbb sb tsb esb ldaex ldaexb ldaexh ldaexd stlex stlexb stlexh stlexd lda ldab ldah stl stlb stlh
smmla smmul smlabb smlad smlald smusd umaal usad8 uadd8 uqadd8 pkhtb blxns bxns sg tt ttt tta ttat nops'''.split())
ARM_COND = ('eq', 'ne', 'cs', 'hs', 'cc', 'lo', 'mi', 'pl', 'vs', 'vc', 'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al')

def norm_x86(m):
    if m in X86_JCC:
        return 'j.cc'
    if re.fullmatch(r'cmov(n?[abceglopsz]|n?[abgl]e|p[eo]|n?[ab]e)', m):
        return 'cmov.cc'
    if re.fullmatch(r'set(n?[abceglopsz]|n?[abgl]e|p[eo]|n?[ab]e)', m):
        return 'set.cc'
    if re.fullmatch(r'movz[bw][wlq]?', m) or m == 'movzx':
        return 'movzx'
    if re.fullmatch(r'movs[bw][wlq]', m) or m in ('movslq', 'movsx', 'movsxd'):
        return 'movsx'
    if m in X86_BASE:
        return m
    if m.endswith('64') and m[:-2] in X86_BASE:
        return m[:-2]
    if len(m) > 2 and m[-1] in 'bwlq' and m[:-1] in X86_BASE:
        return m[:-1]
    return m

def norm_arm(m):
    if m in ARM_BASE:
        return m
    mm = m
    for w in ('.w', '.n'):
        if mm.endswith(w):
            mm = mm[:-2]
    if mm in ARM_BASE:
        return mm
    for c in ARM_COND + ('',):
        if c and not mm.endswith(c):
            continue
        stem = mm[:len(mm) - len(c)] if c else mm
        if stem in ARM_BASE:
            return stem
        if stem.endswith('s') and stem[:-1] in ARM_BASE:
            return stem[:-1]
    return m

VAX_RE = re.compile(r'^(.*[a-z])([234])$')

def norm(fam, m):
    if fam == 'x86':
        return norm_x86(m)
    if fam == 'arm':
        return norm_arm(m)
    if fam == 'arm64':
        return 'b.cond' if m.startswith('b.') else m
    if fam == 'riscv':
        m = re.sub(r'\.(aqrl|aq|rl)$', '', m)
        return m[2:] if m.startswith('c.') else m
    if fam == 'ppc':
        return m.rstrip('.+-') or m
    if fam in ('sparc', 'hppa'):
        return m.split(',')[0]
    if fam == 'alpha':
        return m.split('/')[0]
    if fam == 'm68k':
        return re.sub(r'\.[bwls]$', '', m)
    if fam == 'vax':
        mm = VAX_RE.match(m)
        if mm and mm.group(1)[-1] in 'bwlqdfgh':
            return mm.group(1)
    return m

# --------------------------------------------------------------------------------------------------------------------
# statement parsing
# --------------------------------------------------------------------------------------------------------------------
LABEL_RE = re.compile(r'^\s*(?:[A-Za-z_.$][\w.$]*|\d+)\s*:(?!:)')
WORD_RE = re.compile(r'^[a-z][a-z0-9_.,/+\-]*$')

def statements_of(text, fam, table=COMMENT, keep_define=True):
    """yield statement strings (label-stripped, comment-stripped, case untouched) from assembler text"""
    text = strip_c_comments(text)
    text = re.sub(r'\\\n', ' ', text)         # cpp continuation lines
    for raw in text.split('\n'):
        line = re.sub(r'//.*', '', raw) if fam == 'arm64' else strip_line_comment(raw, fam, table)
        s = line.strip()
        if not s:
            continue
        if s.startswith('#'):
            m = re.match(r'#\s*define\s+[A-Za-z_]\w*(\([^)]*\))?\s+(.*)$', s)
            if m and keep_define:
                s = m.group(2)
            else:
                continue
        for st in ([s] if fam in NO_SEMI else s.split(';')):
            while True:
                st = st.strip()
                m = LABEL_RE.match(st)
                if not m:
                    break
                st = st[m.end():]
            st = st.strip()
            if st:
                yield st

def first_word(st):
    m = re.match(r'(\S+)\s*(.*)$', st)
    return (m.group(1), m.group(2)) if m else (None, '')

class Tally:
    def __init__(self):
        self.mn = Counter()          # (fam, kernel, kind, mnemonic) -> count
        self.files = defaultdict(set)
        self.macros = Counter()      # (fam, kernel, word) -> count
        self.operands = Counter()    # (fam, kernel, mnemonic, operand) -> count
        self.bytes_enc = Counter()   # (fam, kernel) -> count of .byte/.inst statements inside inline asm
        self.stats = Counter()

    def add(self, fam, kernel, kind, m, f):
        k = (fam, kernel, kind, m)
        self.mn[k] += 1
        if len(self.files[k]) < 3:
            self.files[k].add(f)

GPR_LIKE = re.compile(r'^(%|\$|#|\(|\[|\{|[-+]?\d|[xwrvqdsha]\d+$|[atsc]\d+$|ra$|sp$|gp$|tp$|zero$|fp$|lr$|pc$|xzr$|wzr$|e?[abcd]x$|r[0-9a-z]+$|c\d+$|p\d+$)')
SYSREG_MN = {
    'arm64': {'mrs', 'msr'}, 'arm': {'mrc', 'mcr', 'mrrc', 'mcrr', 'mrs', 'msr'},
    'riscv': {'csrr', 'csrw', 'csrs', 'csrc', 'csrrw', 'csrrs', 'csrrc', 'csrwi', 'csrsi', 'csrci', 'csrrwi', 'csrrsi', 'csrrci'},
    'ppc': {'mfspr', 'mtspr', 'mfdcr', 'mtdcr'}, 'mips': {'mfc0', 'mtc0', 'dmfc0', 'dmtc0'}, 'm68k': {'movec'},
    'alpha': {'call_pal', 'hw_mfpr', 'hw_mtpr'}, 'sparc': {'rdpr', 'wrpr', 'rd', 'wr', 'rdhpr', 'wrhpr'}, 'vax': {'mtpr', 'mfpr'},
    'loongarch': {'csrrd', 'csrwr', 'csrxchg'}, 's390': {'stctl', 'lctl', 'stctg', 'lctlg'}, 'hppa': {'mfctl', 'mtctl'}, 'x86': {'mov'},
}
DIRECTIVE_NODOT = set('global globl text data align even section type size set equ file ident comm lcomm skip space word long byte quad asciz ascii p2align weak hidden local macro endm rept endr include irp org end proc seg popsection pushsection zero string short half balign bss comment machine arch option fpu cpu syntax thumb arm code16 code32 code64'.split())
SKIP_WORDS = {'if', 'else', 'endif', 'ifdef', 'ifndef', 'define', 'include', 'undef', 'elif', 'error', 'pragma', 'line', 'return', 'for', 'while', 'do', 'goto',
              'sizeof', 'void', 'int', 'static', 'unsigned', 'long', 'struct', 'const', 'volatile', 'asm', 'extern', 'char', 'switch', 'case', 'break',
              'continue', 'typedef', 'enum', 'union', 'inline'}

def handle_statement(st, fam, kernel, kind, f, tally, macro_names, pending):
    w, rest = first_word(st)
    if w is None:
        return
    if w.startswith('.'):
        if w in ('.byte', '.inst', '.long', '.word', '.4byte', '.short') and kind == 'inline':
            tally.bytes_enc[(fam, kernel)] += 1
        return
    if not (w[0].isalpha() or w[0] == '_') or w in SKIP_WORDS or (w in DIRECTIVE_NODOT and fam in ('m68k', 'vax', 'sparc', 'hppa', 'm88k', 'alpha')):
        return
    wl = w.lower()
    if w != wl:
        wr = WRAPPERS.get(fam, {})
        if w in wr:
            wl = wr[w]
        else:
            tally.macros[(fam, kernel, w)] += 1
            return
    if '_' in wl and fam not in ('loongarch', 'alpha'):
        tally.macros[(fam, kernel, w)] += 1
        return
    if wl in macro_names.get((fam, kernel), ()):
        tally.macros[(fam, kernel, w)] += 1
        return
    if not WORD_RE.match(wl):
        return
    if fam == 'x86' and wl in X86_PREFIX:
        r2 = rest.strip()
        if not r2:
            pending[0] = wl
            return
        w2, _ = first_word(r2)
        if w2 and w2[0].isalpha():
            tally.add(fam, kernel, kind, wl + ' ' + norm('x86', w2.lower()), f)
        return
    m = norm(fam, wl)
    if fam == 'x86' and pending[0]:
        m = pending[0] + ' ' + m
        pending[0] = None
    tally.add(fam, kernel, kind, m, f)
    if wl in SYSREG_MN.get(fam, ()):
        ops = [o.strip().lower() for o in re.split(r',(?![^(\[]*[)\]])', rest) if o.strip()]
        if fam == 'x86':
            for o in ops:
                if re.fullmatch(r'%?(cr\d+|db\d|dr\d)', o):
                    tally.operands[(fam, kernel, 'mov-sysreg', o.lstrip('%'))] += 1
            return
        if fam == 'arm' and wl in ('mrc', 'mcr', 'mrrc', 'mcrr'):
            tally.operands[(fam, kernel, wl, ' '.join(re.sub(r'\s+', '', o) for o in ops[:1] + ops[2:] if not o.startswith('%')))] += 1
            return
        if fam == 'alpha':
            if ops:
                tally.operands[(fam, kernel, wl, ops[0])] += 1
            return
        for o in ops:
            if not GPR_LIKE.match(o) and re.match(r'^[a-z_][\w.]*$', o):
                tally.operands[(fam, kernel, m, o)] += 1
                break

# ---------------- C inline asm ----------------
ASM_KW = re.compile(r'\b(__asm__|__asm|asm_inline|__asm_inline|asm)\b')
STR_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
IDN_RE = re.compile(r'[A-Za-z_]\w*')
QUAL_RE = re.compile(r'\s*(volatile|__volatile__|__volatile|goto|inline|__inline__|const|__const__)\b')
IDENT_EXPAND = {'LOCK_PREFIX': 'lock; ', 'LOCK_PREFIX_HERE': '', 'MPLOCKED': 'lock; ', '_ASM_MOV': 'mov ', '_ASM_ADD': 'add ', '_ASM_SUB': 'sub ',
                '_ASM_INC': 'inc ', '_ASM_DEC': 'dec ', '_ASM_PUSH': 'push ', '_ASM_POP': 'pop ', '_ASM_XADD': 'xadd ', '_ASM_AND': 'and ', '_ASM_OR': 'or ',
                '_ASM_XOR': 'xor ', '_ASM_BTS': 'bts ', '_ASM_BTR': 'btr ', '_ASM_BTC': 'btc ', '_ASM_CALL': 'call ', '_ASM_JMP': 'jmp ', '_ASM_LEA': 'lea ',
                '_ASM_CMPXCHG': 'cmpxchg ', '_ASM_SHL': 'shl ', '_ASM_SHR': 'shr ', '_ASM_ROL': 'rol ', '_ASM_ROR': 'ror ', '_ASM_TEST': 'test ',
                '_ASM_CMP': 'cmp ', '_ASM_BSF': 'bsf ', '_ASM_BSR': 'bsr ', '_ASM_XCHG': 'xchg ', '_ASM_NOP': 'nop ', '_ASM_IRET': 'iret ',
                'ASM_CLAC': 'clac ', 'ASM_STAC': 'stac ', 'LOCK_PREFIX_ALT': 'lock; '}

def read_paren(text, i):
    """text[i] == '('; return (index after the matching ')', items before the first top-level ':')"""
    depth, items, j, n, seen_colon = 0, [], i, len(text), False
    while j < n:
        c = text[j]
        if c == '"':
            m = STR_RE.match(text, j)
            if not m:
                j += 1
                continue
            if not seen_colon:
                items.append(('s', m.group(1)))
            j = m.end()
            continue
        if c == "'":
            k = text.find("'", j + 1)
            j = k + 1 if k > 0 else j + 1
            continue
        if c == '/' and text.startswith('/*', j):
            k = text.find('*/', j + 2)
            j = k + 2 if k > 0 else n
            continue
        if c == '/' and text.startswith('//', j):
            k = text.find('\n', j)
            j = k if k > 0 else n
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return j + 1, items
        elif c == ':' and depth == 1:
            seen_colon = True
        elif c.isalpha() or c == '_':
            m = IDN_RE.match(text, j)
            idn = m.group(0)
            if not seen_colon:
                if idn in IDENT_EXPAND:
                    items.append(('s', IDENT_EXPAND[idn]))
                elif j > 0 and text[j - 1] == '#' and depth >= 1:
                    items.append(('p', idn))
            j = m.end()
            continue
        j += 1
    return n, items

def unescape(s):
    return s.replace('\\n', '\n').replace('\\t', ' ').replace('\\r', ' ').replace('\\"', '"').replace('\\\\', '\\')

def inline_blocks(text):
    for m in ASM_KW.finditer(text):
        j = m.end()
        while True:
            m2 = QUAL_RE.match(text, j)
            if not m2:
                break
            j = m2.end()
        m3 = re.compile(r'\s*\(').match(text, j)
        if not m3:
            continue
        end, items = read_paren(text, m3.end() - 1)
        if not items:
            continue
        parts = [unescape(v) if k == 's' else '\n@@%s@@ ' % v for k, v in items]
        yield m.start(), ''.join(parts)

def process_c(text, fam, kernel, rel, tally, macro_names, param_macros):
    n_blocks = 0
    for off, tmpl in inline_blocks(text):
        n_blocks += 1
        pending = [None]
        for st in statements_of(tmpl, fam, keep_define=False):
            w, rest = first_word(st)
            if w and w.startswith('@@') and w.endswith('@@'):
                pname = w[2:-2]
                prev = text.rfind('#define', 0, off)
                if prev >= 0:
                    mm = re.match(r'#define\s+([A-Za-z_]\w*)\(([^)]*)\)', text[prev:])
                    if mm:
                        params = [p.strip() for p in mm.group(2).split(',')]
                        if pname in params:
                            param_macros[(fam, kernel)].add((mm.group(1), params.index(pname)))
                continue
            handle_statement(st, fam, kernel, 'inline', rel, tally, macro_names, pending)
    tally.stats[(fam, kernel, 'inline', 'asmblocks')] += n_blocks

def split_args(s):
    out, d, cur = [], 0, []
    for c in s:
        if c in '([{':
            d += 1
        elif c in ')]}':
            d -= 1
        if c == ',' and d == 0:
            out.append(''.join(cur))
            cur = []
        else:
            cur.append(c)
    out.append(''.join(cur))
    return out

def resolve_param_macros(files_text, param_macros, tally):
    """second pass: invocations of macros whose stringized parameter is a mnemonic (e.g. ATOMIC_OP(andnot, stclr))"""
    for (fam, kernel), pm in param_macros.items():
        for name, idx in pm:
            rx = re.compile(r'\b%s\s*\(' % re.escape(name))
            for rel, text in files_text.get((fam, kernel), []):
                for m in rx.finditer(text):
                    if 'define' in text[max(0, m.start() - 12):m.start()]:
                        continue
                    end, _ = read_paren(text, m.end() - 1)
                    args = split_args(text[m.end():end - 1])
                    if idx < len(args):
                        a = args[idx].strip()
                        if re.fullmatch(r'[a-z][a-z0-9_.]*', a):
                            tally.add(fam, kernel, 'inline-macro', norm(fam, a), rel)

MACRO_DEF_RE = re.compile(r'^\s*(?:\.macro\s+([A-Za-z_]\w*)|#\s*define\s+([A-Za-z_]\w*))', re.M)

def process_asm_file(text, fam, kernel, rel, tally, macro_names):
    pending = [None]
    tally.stats[(fam, kernel, 'asm', 'lines')] += sum(1 for l in text.split('\n') if l.strip())
    for m in re.finditer(r'\bALTERNATIVE\w*\s*\(', text):
        end, items = read_paren(text, m.end() - 1)
        for k, v in items:
            if k == 's':
                for st in statements_of(unescape(v), fam, keep_define=False):
                    handle_statement(st, fam, kernel, 'asm', rel, tally, macro_names, pending)
    for st in statements_of(text, fam):
        handle_statement(st, fam, kernel, 'asm', rel, tally, macro_names, pending)

# --------------------------------------------------------------------------------------------------------------------
# driver: extract
# --------------------------------------------------------------------------------------------------------------------
KERNELS = ['linux', 'freebsd', 'netbsd', 'openbsd']

def walk_sources(src, kernel):
    root = os.path.join(src, kernel)
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d != '.git']
        for f in fn:
            full = os.path.join(dp, f)
            rel = os.path.relpath(full, root)
            fam = classify_path(kernel, rel)
            if fam is None:
                continue
            ext = os.path.splitext(f)[1]
            if ext in ASM_EXT or ext in C_EXT:
                yield rel, full, fam, ext

def read(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return ''

def do_extract(src, out):
    tally = Tally()
    macro_names = defaultdict(set)
    param_macros = defaultdict(set)
    files_text = defaultdict(list)
    cache = {}
    for kernel in KERNELS:
        if not os.path.isdir(os.path.join(src, kernel)):
            continue
        for rel, full, fam, ext in walk_sources(src, kernel):
            text = read(full)
            cache[(kernel, rel)] = (fam, ext, text)
            for m in MACRO_DEF_RE.finditer(text):
                nm = m.group(1) or m.group(2)
                if nm and nm == nm.lower():
                    macro_names[(fam, kernel)].add(nm)
    for (kernel, rel), (fam, ext, text) in sorted(cache.items()):
        if ext in ASM_EXT:
            tally.stats[(fam, kernel, 'asm', 'files')] += 1
            process_asm_file(text, fam, kernel, rel, tally, macro_names)
        elif ASM_KW.search(text):
            tally.stats[(fam, kernel, 'inline', 'files')] += 1
            process_c(text, fam, kernel, rel, tally, macro_names, param_macros)
            files_text[(fam, kernel)].append((rel, text))
    resolve_param_macros(files_text, param_macros, tally)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'kernel_mnemonics.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'kernel', 'kind', 'mnemonic', 'count', 'example_files'])
        for k, c in sorted(tally.mn.items(), key=lambda kv: (kv[0][0], kv[0][1], -kv[1], kv[0][3])):
            w.writerow(list(k) + [c, ' '.join(sorted(tally.files[k]))])
    with open(os.path.join(out, 'kernel_macros.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'kernel', 'macro_word', 'count'])
        for k, c in sorted(tally.macros.items(), key=lambda kv: (kv[0][0], kv[0][1], -kv[1])):
            if c >= 2:
                w.writerow(list(k) + [c])
    with open(os.path.join(out, 'kernel_sysreg_operands.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'kernel', 'mnemonic', 'operand', 'count'])
        for k, c in sorted(tally.operands.items(), key=lambda kv: (kv[0][0], kv[0][2], -kv[1])):
            w.writerow(list(k) + [c])
    with open(os.path.join(out, 'kernel_extraction_stats.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'kernel', 'kind', 'what', 'count'])
        for k, c in sorted(tally.stats.items()):
            w.writerow(list(k) + [c])
        for (fam, kernel), c in sorted(tally.bytes_enc.items()):
            w.writerow([fam, kernel, 'inline', 'byte_encoded_statements', c])
    print('extract: %d (family,kernel,kind,mnemonic) rows' % len(tally.mn), file=sys.stderr)

# --------------------------------------------------------------------------------------------------------------------
# the compiler side
# --------------------------------------------------------------------------------------------------------------------
CORPUS = {
    'x86': ['amd64-clang', 'amd64-gcc', 'i386-clang', 'i386-gcc'], 'arm64': ['aarch64', 'aarch64-gcc'], 'arm': ['arm', 'arm-v7', 'arm-gcc'],
    'riscv': ['riscv64', 'riscv64gc', 'riscv64gc-gcc', 'riscv64zb'], 'mips': ['mips64'], 'ppc': ['ppc32', 'ppc32-gcc', 'ppc64', 'ppc64-gcc'],
    'loongarch': ['loongarch64', 'loongarch64-gcc'], 'm68k': ['m68k', 'm68k-gcc'], 'sparc': ['sparcv9', 'sparc64-gcc'], 's390': ['systemz', 'systemz-gcc'],
    'vax': ['vax-gcc'], 'pdp64': ['pdp64'],
}

def corpus_family_counts(corpus, fam, dirs):
    cnt, per_dir = Counter(), Counter()
    for d in dirs:
        p = os.path.join(corpus, d)
        if not os.path.isdir(p):
            continue
        for f in sorted(os.listdir(p)):
            if not f.endswith('.s'):
                continue
            text = read(os.path.join(p, f))
            for st in statements_of(text, fam if fam != 'pdp64' else 'pdp64', CORPUS_COMMENT, keep_define=False):
                w, rest = first_word(st)
                if not w or w.startswith('.') or not w[0].isalpha():
                    continue
                wl = w.lower()
                if fam == 'pdp64':
                    cnt[wl] += 1
                    per_dir[d] += 1
                    continue
                if fam == 'x86' and wl in X86_PREFIX:
                    if not rest.strip():
                        continue
                    w2, _ = first_word(rest.strip())
                    if w2 and w2[0].isalpha():
                        cnt[wl + ' ' + norm('x86', w2.lower())] += 1
                        per_dir[d] += 1
                    continue
                if not WORD_RE.match(wl):
                    continue
                cnt[norm(fam, wl)] += 1
                per_dir[d] += 1
    return cnt, per_dir

def do_corpus(corpus, out):
    os.makedirs(out, exist_ok=True)
    rows, tot = [], []
    for fam, dirs in CORPUS.items():
        cnt, per_dir = corpus_family_counts(corpus, fam, dirs)
        rows += [(fam, m, c) for m, c in cnt.items()]
        tot.append((fam, ' '.join(dirs), sum(cnt.values())))
        print('corpus', fam, sum(cnt.values()), len(cnt), file=sys.stderr)
    with open(os.path.join(out, 'compiler_mnemonics.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'mnemonic', 'count'])
        for r in sorted(rows, key=lambda r: (r[0], -r[2], r[1])):
            w.writerow(r)
    with open(os.path.join(out, 'compiler_totals.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['family', 'corpus_dirs', 'instructions'])
        w.writerows(tot)

# --------------------------------------------------------------------------------------------------------------------
# join: the compiler-invisible inventory
# --------------------------------------------------------------------------------------------------------------------
def load_csv(path):
    with open(path, newline='') as fh:
        return list(csv.DictReader(fh))

def do_join(out, thresh=1e-5):
    kern = load_csv(os.path.join(out, 'kernel_mnemonics.csv'))
    comp = load_csv(os.path.join(out, 'compiler_mnemonics.csv'))
    tot = {r['family']: int(r['instructions']) for r in load_csv(os.path.join(out, 'compiler_totals.csv'))}
    cc = defaultdict(Counter)
    for r in comp:
        cc[r['family']][r['mnemonic']] += int(r['count'])
    agg = defaultdict(lambda: defaultdict(Counter))
    for r in kern:
        agg[r['family']][r['mnemonic']][r['kernel']] += int(r['count'])
    rows = []
    for fam, mm in agg.items():
        T = tot.get(fam, 0)
        for m, kc in mm.items():
            c = cc[fam].get(m, 0)
            frac = (c / T) if T else None
            rows.append({'family': fam, 'mnemonic': m, 'kernel_total': sum(kc.values()),
                         'linux': kc.get('linux', 0), 'freebsd': kc.get('freebsd', 0), 'netbsd': kc.get('netbsd', 0), 'openbsd': kc.get('openbsd', 0),
                         'compiler_count': c, 'compiler_total': T, 'compiler_fraction': ('%.3e' % frac) if frac is not None else '',
                         'invisible': ('' if T == 0 else ('yes' if frac < thresh else 'no'))})
    rows.sort(key=lambda r: (r['family'], -r['kernel_total'], r['mnemonic']))
    with open(os.path.join(out, 'compiler_invisible.csv'), 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print('join: %d rows' % len(rows), file=sys.stderr)


# --------------------------------------------------------------------------------------------------------------------
# classification of the compiler-invisible mnemonics by purpose
# --------------------------------------------------------------------------------------------------------------------
CLASS_ORDER = ['exception entry/return and system call', 'privileged register access', 'interrupt masking', 'TLB and MMU maintenance', 'cache maintenance',
               'memory barrier and ordering', 'atomics and exclusive access', 'spin-wait, idle and hints', 'user-memory access', 'per-CPU and thread base',
               'context and FPU/vector state', 'string and memory block', 'bit manipulation', 'CPU identification and feature', 'timers and counters',
               'random numbers', 'hypervisor, secure and firmware calls', 'debug and breakpoints', 'speculation control', 'other']
CLASS_TABLE = {
 'x86': {
  'exception entry/return and system call': 'iret sysret sysexit sysenter syscall int into lret uiret eretu erets senduipi rsm ud1',
  'privileged register access': 'rdmsr wrmsr lgdt lidt lldt ltr sgdt sidt sldt str lmsw smsw clts xsetbv xgetbv rdpkru wrpkru verr verw lar lsl rdmsrlist wrmsrlist wrmsrns in out ins outs',
  'interrupt masking': 'cli sti clui stui testui',
  'TLB and MMU maintenance': 'invlpg invpcid invept invvpid invlpgb tlbsync',
  'cache maintenance': 'invd wbinvd clflush clflushopt clwb cldemote wbnoinvd prefetcht0 prefetcht1 prefetcht2 prefetchnta prefetchw',
  'memory barrier and ordering': 'mfence lfence sfence serialize',
  'atomics and exclusive access': 'xchg cmpxchg cmpxchg8b cmpxchg16b xadd bts btr btc',
  'spin-wait, idle and hints': 'pause hlt mwait monitor umwait tpause umonitor monitorx mwaitx',
  'user-memory access': 'stac clac',
  'per-CPU and thread base': 'swapgs rdgsbase wrgsbase rdfsbase wrfsbase lkgs',
  'context and FPU/vector state': 'xsave xrstor xsaveopt xsavec xsaves xrstors fxsave fxrstor fnsave frstor fnstenv fldenv emms fninit fnclex fldcw fnstcw fnstsw ldmxcsr stmxcsr vzeroupper vzeroall fwait wait',
  'string and memory block': 'movs stos scas cmps lods',
  'bit manipulation': 'bsf bsr tzcnt lzcnt popcnt bt bswap movbe crc32 bextr pdep pext',
  'CPU identification and feature': 'cpuid rdpid',
  'timers and counters': 'rdtsc rdtscp rdpmc',
  'random numbers': 'rdrand rdseed',
  'hypervisor, secure and firmware calls': 'vmcall vmlaunch vmresume vmxon vmxoff vmread vmwrite vmptrld vmptrst vmclear vmmcall vmrun vmload vmsave stgi clgi tdcall seamcall seamret getsec',
  'debug and breakpoints': 'int3 ud2 icebp',
  'speculation control': 'endbr64 endbr32 rdssp incssp saveprevssp rstorssp wrss wruss setssbsy clrssbsy',
 },
 'arm64': {
  'exception entry/return and system call': 'eret eretaa eretab svc drps',
  'privileged register access': 'mrs msr sys sysl',
  'TLB and MMU maintenance': 'tlbi',
  'cache maintenance': 'dc ic',
  'memory barrier and ordering': 'dmb dsb isb',
  'atomics and exclusive access': 'ldxr stxr ldaxr stlxr ldxp stxp ldaxp stlxp ldxrb stxrb ldaxrb stlxrb ldxrh stxrh ldaxrh stlxrh clrex cas casa casal casl casb casab casalb caslb cash casah casalh caslh casp caspa caspal caspl swp swpa swpal swpl swpb swpab swpalb swplb swph swpah swpalh swplh ldadd ldadda ldaddal ldaddl ldaddb ldaddab ldaddalb ldaddlb ldaddh ldaddah ldaddalh ldaddlh ldclr ldclra ldclral ldclrl ldclrb ldclrh ldset ldseta ldsetal ldsetl ldsetb ldseth ldeor ldeora ldeoral ldeorl ldeorb ldeorh ldsmax ldsmin ldumax ldumin stadd staddl staddb staddh stclr stclrl stclrb stclrh stset stsetl stsetb stseth steor steorl steorb steorh ldapr ldaprb ldaprh ldar ldarb ldarh stlr stlrb stlrh ldlar stllr',
  'spin-wait, idle and hints': 'wfe wfi sev sevl yield wfet wfit hint',
  'user-memory access': 'ldtr ldtrb ldtrh ldtrsb ldtrsh ldtrsw sttr sttrb sttrh',
  'string and memory block': 'cpyp cpym cpye cpyfp cpyfm cpyfe setp setm sete setgp setgm setge',
  'bit manipulation': 'rbit cls',
  'hypervisor, secure and firmware calls': 'hvc smc',
  'debug and breakpoints': 'brk hlt dcps1 dcps2 dcps3 udf',
  'speculation control': 'csdb sb ssbb psb tsb esb bti paciasp autiasp pacibsp autibsp pacia autia pacib autib paciza autiza xpaci xpacd xpaclri gcsb gcspushm gcsss1 gcsss2 gcspopm chkfeat',
 },
 'arm': {
  'exception entry/return and system call': 'eret rfe rfeia rfeda rfedb rfeib srs srsia srsda srsdb srsib svc swi udf',
  'privileged register access': 'mrs msr mrc mcr mrc2 mcr2 mrrc mcrr cdp',
  'interrupt masking': 'cps cpsid cpsie',
  'cache maintenance': 'pld pldw pli',
  'memory barrier and ordering': 'dmb dsb isb',
  'atomics and exclusive access': 'ldrex strex ldrexb strexb ldrexh strexh ldrexd strexd clrex swp swpb ldaex stlex ldaexb stlexb ldaexh stlexh ldaexd stlexd lda stl ldab stlb ldah stlh',
  'spin-wait, idle and hints': 'wfe wfi sev sevl yield',
  'user-memory access': 'ldrt strt ldrbt strbt ldrht strht ldrsht ldrsbt',
  'bit manipulation': 'rbit clz rev rev16 revsh',
  'hypervisor, secure and firmware calls': 'hvc smc',
  'debug and breakpoints': 'bkpt',
  'speculation control': 'csdb sb ssbb pssbb esb tsb',
  'context and FPU/vector state': 'vmrs vmsr vpush vpop vldm vstm',
 },
 'riscv': {
  'exception entry/return and system call': 'sret mret uret mnret ecall dret',
  'privileged register access': 'csrr csrw csrs csrc csrrw csrrs csrrc csrwi csrsi csrci csrrwi csrrsi csrrci',
  'TLB and MMU maintenance': 'sfence.vma sfence.inval.ir sfence.w.inval sinval.vma hfence.vvma hfence.gvma hinval.vvma hinval.gvma',
  'cache maintenance': 'cbo.clean cbo.flush cbo.inval cbo.zero prefetch.i prefetch.r prefetch.w',
  'memory barrier and ordering': 'fence fence.i fence.tso',
  'atomics and exclusive access': 'lr.w lr.d sc.w sc.d amoswap.w amoswap.d amoadd.w amoadd.d amoand.w amoand.d amoor.w amoor.d amoxor.w amoxor.d amomax.w amomax.d amomin.w amomin.d amomaxu.w amomaxu.d amominu.w amominu.d amocas.w amocas.d amocas.q',
  'spin-wait, idle and hints': 'wfi pause wrs.nto wrs.sto',
  'bit manipulation': 'clz ctz cpop rev8 orc.b',
  'timers and counters': 'rdtime rdcycle rdinstret',
  'hypervisor, secure and firmware calls': 'hlv.b hlv.h hlv.w hlv.d hlvx.hu hlvx.wu hsv.b hsv.h hsv.w hsv.d',
  'debug and breakpoints': 'ebreak unimp',
  'context and FPU/vector state': 'vsetvli vsetivli vsetvl',
  'speculation control': 'lpad',
 },
 'mips': {
  'exception entry/return and system call': 'eret eretnc deret syscall',
  'privileged register access': 'mfc0 mtc0 dmfc0 dmtc0 mfhc0 mthc0 mfc2 mtc2 rdpgpr wrpgpr mfgc0 mtgc0 dmfgc0 dmtgc0',
  'interrupt masking': 'di ei',
  'TLB and MMU maintenance': 'tlbp tlbr tlbwi tlbwr tlbinv tlbinvf tlbgp tlbgr tlbgwi tlbgwr tlbginv tlbginvf',
  'cache maintenance': 'cache cachee synci prefe pref',
  'memory barrier and ordering': 'sync ehb ssnop',
  'atomics and exclusive access': 'll lld sc scd lle sce',
  'spin-wait, idle and hints': 'wait pause',
  'user-memory access': 'lwe lhe lbe lbue lhue swe she sbe lwle lwre swle swre',
  'bit manipulation': 'clz clo dclz dclo wsbh dsbh dshd ext dext ins dins',
  'timers and counters': 'rdhwr',
  'hypervisor, secure and firmware calls': 'hypcall',
  'debug and breakpoints': 'break sdbbp teq tne tge tlt',
  'context and FPU/vector state': 'cfc1 ctc1 cfc2 ctc2',
 },
 'ppc': {
  'exception entry/return and system call': 'rfi rfid hrfid rfscv rfebb rfci rfmci rfdi rfsvc sc scv',
  'privileged register access': 'mfspr mtspr mfmsr mtmsr mtmsrd mfdcr mtdcr mfsr mtsr mfsrin mtsrin mfcr mtcrf mtcr mfsprg mtsprg mfdbat mtdbat mfibat mtibat mfpvr mtdec mfdec mfsdr1 mtsdr1 mtsrr0 mfsrr0 mtsrr1 mfsrr1',
  'interrupt masking': 'wrteei wrtee',
  'TLB and MMU maintenance': 'tlbie tlbiel tlbsync tlbia tlbivax tlbre tlbwe tlbsx slbia slbie slbmte slbmfee slbmfev slbfee slbsync slbiag ptesync',
  'cache maintenance': 'dcbf dcbi dcbst dcbz dcbzl dcbt dcbtst dcbtls dcbstps dcbfps icbi icbt icblc dcblc dcbtstls',
  'memory barrier and ordering': 'sync lwsync hwsync eieio isync mbar msync',
  'atomics and exclusive access': 'lwarx ldarx stwcx stdcx lbarx lharx stbcx sthcx lqarx stqcx lwat ldat stwat stdat',
  'spin-wait, idle and hints': 'wait nap sleep doze rvwinkle stop',
  'string and memory block': 'lswx stswx lswi stswi',
  'bit manipulation': 'cntlzw cntlzd cnttzd cnttzw popcntb popcntw popcntd',
  'timers and counters': 'mftb mftbu mftbl',
  'random numbers': 'darn',
  'hypervisor, secure and firmware calls': 'hvc',
  'debug and breakpoints': 'trap tw twi td tdi twge twlt',
  'context and FPU/vector state': 'mffs mtfsf mtfsfi mtfsb0 mtfsb1 mfvscr mtvscr mfvsrd mtvsrd',
 },
 'loongarch': {
  'exception entry/return and system call': 'ertn syscall',
  'privileged register access': 'csrrd csrwr csrxchg iocsrrd.b iocsrrd.h iocsrrd.w iocsrrd.d iocsrwr.b iocsrwr.h iocsrwr.w iocsrwr.d',
  'TLB and MMU maintenance': 'invtlb tlbsrch tlbrd tlbwr tlbfill tlbclr tlbflush',
  'cache maintenance': 'cacop preld preldx',
  'memory barrier and ordering': 'dbar ibar',
  'atomics and exclusive access': 'll.w ll.d sc.w sc.d sc.q amswap.w amswap.d amadd.w amadd.d amand.w amand.d amor.w amor.d amxor.w amxor.d ammax.w ammax.d ammin.w ammin.d amswap_db.w amswap_db.d amadd_db.w amadd_db.d amand_db.w amand_db.d amor_db.w amor_db.d amxor_db.w amxor_db.d ammax_db.w ammax_db.d ammin_db.w ammin_db.d amcas.w amcas.d amcas_db.w amcas_db.d amcas.b amcas.h amswap.b amswap.h amadd.b amadd.h',
  'spin-wait, idle and hints': 'idle',
  'bit manipulation': 'clo.w clo.d clz.w clz.d cto.w cto.d ctz.w ctz.d revb.2h revb.4h revb.2w revb.d bitrev.4b bitrev.8b bitrev.w bitrev.d',
  'timers and counters': 'rdtime.d rdtimel.w rdtimeh.w',
  'hypervisor, secure and firmware calls': 'hvcl gcsrrd gcsrwr gcsrxchg',
  'debug and breakpoints': 'break dbcl',
  'user-memory access': 'ldgt.b ldgt.h ldgt.w ldgt.d stgt.b stgt.h stgt.w stgt.d ldle.b ldle.h ldle.w ldle.d stle.b stle.h stle.w stle.d',
  'CPU identification and feature': 'cpucfg',
 },
 'm68k': {
  'exception entry/return and system call': 'rte rtd trap trapv trapcc chk',
  'privileged register access': 'movec reset stop pmove',
  'TLB and MMU maintenance': 'pflush pflusha pflushs pflushr pflushn pflushan ploadr ploadw ptestr ptestw',
  'cache maintenance': 'cinv cpush cinvl cinva cinvp cpushl cpusha cpushp',
  'atomics and exclusive access': 'tas cas cas2',
  'user-memory access': 'moves',
  'context and FPU/vector state': 'fsave frestore fmovem movem',
  'bit manipulation': 'bfffo bfextu bfexts bfins bfset bfclr bfchg bftst bset bclr bchg btst',
  'debug and breakpoints': 'bkpt illegal',
  'string and memory block': 'cmpm',
 },
 'sparc': {
  'exception entry/return and system call': 'retry done rett ta tcc te tne tg tl tleu tgu tvc tvs tn tpos tneg',
  'privileged register access': 'rdpr wrpr rd wr rdhpr wrhpr rdasr wrasr',
  'TLB and MMU maintenance': 'flush flushw',
  'cache maintenance': 'prefetch prefetcha',
  'memory barrier and ordering': 'membar stbar',
  'atomics and exclusive access': 'casa casxa ldstub ldstuba swap swapa cas casx',
  'bit manipulation': 'popc',
  'context and FPU/vector state': 'save restore',
  'user-memory access': 'lda ldxa stxa sta lduba ldsba lduha ldsha lduwa ldswa ldda stda stba stha stwa',
 },
 's390': {
  'exception entry/return and system call': 'svc lpsw lpswe lpswey',
  'privileged register access': 'lctl lctlg stctl stctg spx stpx stap spka ipk sckpf ssm stosm stnsm epsw sac sacf',
  'TLB and MMU maintenance': 'ptlb ipte idte csp cspg crdte ptlbe',
  'cache maintenance': 'iske sske rrbe rrbm pfmf pfd',
  'memory barrier and ordering': 'bcr',
  'atomics and exclusive access': 'cs csg cds cdsg csst laa laag laal laalg lan lang lao laog lax laxg ts',
  'spin-wait, idle and hints': 'sigp',
  'user-memory access': 'mvcp mvcs mvcos lura lurag stura sturg',
  'context and FPU/vector state': 'stmg lmg stm lm stfpc lfpc vlm vstm',
  'string and memory block': 'mvc mvcl mvcle clc clcl clcle xc oc nc tr trt trtr srst mvst clst mvn mvo mvz pack unpk',
  'bit manipulation': 'flogr popcnt',
  'timers and counters': 'stck stckf stcke stckc sckc stpt spt',
  'random numbers': 'prno',
  'hypervisor, secure and firmware calls': 'diag sie',
  'CPU identification and feature': 'stidp stfle stsi',
  'debug and breakpoints': 'bpt',
 },
 'alpha': {
  'exception entry/return and system call': 'call_pal callsys rti retsys',
  'privileged register access': 'hw_mfpr hw_mtpr mfpr mtpr',
  'memory barrier and ordering': 'mb wmb trapb excb',
  'atomics and exclusive access': 'ldl_l ldq_l stl_c stq_c',
  'cache maintenance': 'imb',
  'bit manipulation': 'ctlz cttz ctpop',
  'timers and counters': 'rpcc',
  'CPU identification and feature': 'amask implver',
  'spin-wait, idle and hints': 'halt',
 },
 'vax': {
  'exception entry/return and system call': 'rei chmk chme chms chmu',
  'privileged register access': 'mtpr mfpr movpsl',
  'context and FPU/vector state': 'svpctx ldpctx pushr popr',
  'atomics and exclusive access': 'bbssi bbcci adawi insqhi insqti remqhi remqti insque remque',
  'user-memory access': 'prober probew',
  'string and memory block': 'movc3 movc5 cmpc3 cmpc5 locc skpc scanc spanc matchc movtc movtuc crc',
  'bit manipulation': 'ffs ffc extv extzv insv cmpv cmpzv',
  'spin-wait, idle and hints': 'halt',
  'debug and breakpoints': 'bpt',
 },
 'hppa': {
  'exception entry/return and system call': 'rfi rfir break be ble',
  'privileged register access': 'mfctl mtctl mtsm rsm ssm mfsp mtsp',
  'TLB and MMU maintenance': 'pitlb pdtlb pitlbe pdtlbe idtlba idtlbp iitlba iitlbp',
  'cache maintenance': 'fic fice fdc fdce',
  'memory barrier and ordering': 'sync syncdma',
  'atomics and exclusive access': 'ldcw ldcd',
 },
 'm88k': {
  'exception entry/return and system call': 'rte tb0 tb1 tcnd',
  'privileged register access': 'ldcr stcr xcr fldcr fstcr fxcr',
  'atomics and exclusive access': 'xmem',
 },
}

def class_of(fam, m):
    tbl = CLASS_TABLE.get(fam, {})
    if fam == 'x86' and m.startswith('lock '):
        return 'atomics and exclusive access'
    if fam == 'x86' and m.split(' ')[0] in ('rep', 'repz', 'repnz', 'repe', 'repne') and len(m.split(' ')) > 1:
        return 'privileged register access' if m.split(' ')[1] in ('ins', 'outs') else 'string and memory block'
    for cls, names in tbl.items():
        if m in names.split():
            return cls
    return 'other'

def do_classify(out):
    rows = load_csv(os.path.join(out, 'compiler_invisible.csv'))
    for r in rows:
        r['class'] = class_of(r['family'], r['mnemonic'])
    fields = ['family', 'mnemonic', 'class', 'kernel_total', 'linux', 'freebsd', 'netbsd', 'openbsd', 'compiler_count', 'compiler_total', 'compiler_fraction', 'invisible']
    with open(os.path.join(out, 'classified.csv'), 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r[k] for k in fields})
    agg = defaultdict(lambda: [0, 0])
    for r in rows:
        if r['invisible'] in ('yes', ''):
            a = agg[(r['class'], r['family'])]
            a[0] += 1
            a[1] += int(r['kernel_total'])
    with open(os.path.join(out, 'class_summary.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['class', 'family', 'distinct_invisible_mnemonics', 'occurrences'])
        for (c, f), (d, o) in sorted(agg.items()):
            w.writerow([c, f, d, o])
    print('classify: %d rows' % len(rows), file=sys.stderr)

def do_sample(src, fam, kernel, n):
    import random
    random.seed(1)
    files = [(r, f) for r, f, fa, e in walk_sources(src, kernel) if fa == fam and e in ASM_EXT]
    random.shuffle(files)
    for rel, full in files[:n]:
        tally = Tally()
        process_asm_file(read(full), fam, kernel, rel, tally, {})
        print('==', rel, dict(Counter({k[3]: v for k, v in tally.mn.items()}).most_common(14)))

def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('cmd', choices=['extract', 'corpus', 'join', 'classify', 'all', 'sample'])
    ap.add_argument('rest', nargs='*')
    ap.add_argument('--src', default=os.path.expanduser('~/claude/kernel-src'))
    ap.add_argument('--corpus', default='/tmp/p64opt/archcmp')
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', 'codegen-data', 'kernelasm'))
    a = ap.parse_args()
    if a.cmd in ('extract', 'all'):
        do_extract(a.src, a.out)
    if a.cmd in ('corpus', 'all'):
        do_corpus(a.corpus, a.out)
    if a.cmd in ('join', 'all'):
        do_join(a.out)
    if a.cmd in ('classify', 'all'):
        do_classify(a.out)
    if a.cmd == 'sample':
        do_sample(a.src, a.rest[0], a.rest[1], int(a.rest[2]))

if __name__ == '__main__':
    main()
