"""Dictionary entries, part 3: atomics and system instructions."""
from isa_common import *

ATNOTE = ('The sub-opcodes and the semantics of this group are specified.')
ATFLAG = 'None for the read-modify-write forms; `SC` reports success in `Rd`.'
ATEXC = 'Page fault, protection fault, bus error, or a precise fault (nothing changed, `EPC` the instruction) on an address that is not naturally aligned and on memory that is not ordinary cached memory (uncached memory or a device register). The access is atomic with respect to every initiator, cores and devices alike.'
ATCF = '{{r:atomic-operations}} (atomic operations: the reservation monitor), {{r:multiprocessor-instructions-at-a-glance}} (the multiprocessor instructions at a glance), {{r:memory-ordering-from-sequential-consistency}} (the memory model).'

ENTRIES = [
    E('CAS', 'atomics', ['cas', 'casdb'], 'Compare and swap',
      ['CAS Rd, Rs, (Ra)        ; three registers: Rd holds the expected value going in and the old value coming out, Rs the new value, Ra the address (no offset); size is 4 or 8 bytes', 'CASDB ...               ; with a full barrier'],
      '''old <- M[Ra]                              ; 4 or 8 bytes, naturally aligned, ordinary cached memory
if old == Rd then M[Ra] <- Rs
Rd <- old              ; the program compares Rd with the value it expected to learn whether the swap happened''', ATFLAG, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('SWAP', 'atomics', ['swap', 'swapdb'], 'Atomic exchange', ['SWAP Rd, Rs, (Ra)        ; Ra the address (no offset), Rs the value, Rd the old value', 'SWAPDB ...'],
      '''old <- M[Ra] ; M[Ra] <- Rs ; Rd <- old''', ATFLAG, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XADD', 'atomics', ['xadd', 'xadddb'], 'Atomic fetch and add', ['XADD Rd, Rs, (Ra)        ; Ra the address (no offset), Rs the operand, Rd the old value; size 4 or 8 bytes', 'XADDDB ...'],
      '''old <- M[Ra] ; M[Ra] <- old + Rs ; Rd <- old''', ATFLAG, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XAND', 'atomics', ['xand', 'xanddb', 'xor_', 'xor_db', 'xxor', 'xxordb'], 'Atomic fetch and and, or, xor',
      ['XAND Rd, Rs, (Ra)', 'XOR_ Rd, Rs, (Ra)        ; the trailing underscore keeps the mnemonic distinct from XOR', 'XXOR Rd, Rs, (Ra)', 'each with a DB form'],
      '''old <- M[Ra]
XAND: M[Ra] <- old AND Rs
XOR_: M[Ra] <- old OR Rs
XXOR: M[Ra] <- old XOR Rs
Rd <- old''', ATFLAG, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XMAX', 'atomics', ['xmax', 'xmaxdb', 'xmin', 'xmindb', 'xmaxu', 'xmaxudb', 'xminu', 'xminudb'], 'Atomic fetch and minimum or maximum',
      ['XMAX Rd, Rs, (Ra)', 'XMIN ..., XMAXU ..., XMINU ...', 'each with a DB form'],
      '''old <- M[Ra] ; M[Ra] <- max(old, Rs) (XMAX, XMAXU) or min (XMIN, XMINU) ; Rd <- old
signed for XMAX and XMIN, unsigned for the U forms''', ATFLAG, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('LLSC', 'atomics', ['ll', 'sc'], 'Load-linked and store-conditional', ['LL Rd, (Ra)', 'SC Rd, Rs, (Ra)'],
      '''LL: Rd <- M[Ra] ; take a reservation on the granule containing the address
SC: if the reservation is intact then M[Ra] <- Rs ; Rd <- 0 (success)
    else nothing is written ; Rd <- 1 (failure)
a write to the granule by any initiator, core or device, clears the reservation''', ATFLAG, ATEXC,
      notes='A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). ' + ATNOTE, cf=ATCF, xnote=ATNOTE),

    # ---- SYS, class 0 ----
    E('NOP', 'system', ['nop', 'lpad'], 'No operation and landing pad', ['NOP', 'LPAD'], 'nothing', NOFLAGS, NONE,
      notes='`LPAD` marks a legal target of an indirect jump or call; no instruction enforces it in ABI version 1.', cf='Appendix {{a:id03001|n}}, section {{r:page-bit-that-enforces-landing-pads}} (landing pads).'),
    E('RTI', 'system', ['rti', 'rtt'], 'Return from interrupt or exception', ['RTI #mask', 'RTT #mask'],
      '''PC <- EPC ; PSW <- EPSW           ; a PSW with the reserved mode 2 in either mode field aborts
if the mode returned to is lesser than the current mode: every Rn (n = 0 to 31, n != 14) whose bit n of mask is zero <- 0
    and, if bit 14 of mask is zero, the vector registers and FPSR <- 0
RTT: and then set the trace bit T after the return''', 'Replaced by `EPSW`, including the flags.', PRIV,
      notes='The mask is 32 bits, carried in parcels 1 (high half) and 2 (low half), so the instruction is six bytes; there is no form without it. `R14` is the stack pointer of the mode returned to and is never cleared, so bit 14 names the vector registers and the floating-point flags. To the same mode the mask is ignored. `RTT` sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler. The constants `RTIMASK_ALL`, `RTIMASK_NONE`, `RTIMASK_CALLEE` and `RTIMASK_SYSCALL` name the usual masks; `RTIMASK_ALL` is the one spelling that leaves the kernel\'s registers visible.', cf='{{r:exceptions-interrupts-and-traps}} (exceptions and interrupts), {{r:kernel-system-instructions-exceptions}}.'),
    E('RET', 'system', ['ret'], 'Return from subroutine', ['RET'], 'PC <- M[SP] ; SP <- SP + 8', NOFLAGS, MEMX, notes='Not privileged, though it is in the system escape: it is the two-byte partner of `CALL`.'),
    E('HALT', 'system', ['halt'], 'Halt the processor', ['HALT'], 'stop the processor', NOFLAGS, PRIV, cf='{{r:reset-and-the-first-kernel}}.'),
    E('BPT', 'system', ['bpt'], 'Breakpoint', ['BPT'], 'take the breakpoint vector with EPC = the address of the next instruction', NOFLAGS, 'Enters the kernel by the `BPT` vector.',
      notes='A trap like any other, but kept as its own two-byte instruction because a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has.', cf='{{r:exceptions-interrupts-and-traps}}.'),
    E('FENCE', 'system', ['fence'], 'Memory fence', ['FENCE'], 'order the memory accesses before it against those after it, for every initiator that observes them', NOFLAGS, NONE,
      notes='Owed to devices (one `FENCE` separates writing a device\'s registers from setting its go bit) and to other cores.', cf='{{r:memory-ordering-from-sequential-consistency}} (the memory model), {{r:pci-express-links-packets-and-configuration}} (what the processor owes the bus).'),
    E('WFE', 'system', ['wfe', 'wait'], 'Wait for an event', ['WFE'], 'sleep until an interrupt is pending or another core executes SEV', NOFLAGS, PRIV,
      notes='`WAIT` is an assembler alias.', cf='{{r:waiting-signalling-and-interrupting-another}} (waiting and signalling).'),
    E('SEV', 'system', ['sev'], 'Send an event', ['SEV'], 'wake every core waiting in WFE', NOFLAGS, NONE, cf='{{r:cache-coherence}}.'),
    E('TLBA', 'system', ['tlbia', 'tlbsync', 'icinva'], 'Invalidate all translations; wait for translation invalidations; invalidate the whole instruction cache',
      ['TLBIA', 'TLBSYNC', 'ICINVA'],
      '''TLBIA   : invalidate every translation-buffer entry on this core and, by broadcast, on the others
TLBSYNC : wait until the invalidations this core started have completed on every core
ICINVA  : invalidate the whole instruction cache''', NOFLAGS, 'Privileged (`TLBIA`, `TLBSYNC`)',
      cf='{{r:translation-and-instruction-cache-coherence}} (translation and instruction-cache coherence).'),
    # ---- SYSX ----
    E('PUSHX', 'system', ['pushx', 'popx'], 'Push and pop the exception state', ['PUSHX', 'POPX'],
      '''PUSHX: SP <- SP - 16 ; M[SP] <- EPSW ; M[SP + 8] <- EPC
POPX : EPSW <- M[SP] ; EPC <- M[SP + 8] ; SP <- SP + 16''', NOFLAGS, PRIV + ' `SP` must be 8-byte aligned (a misaligned-access abort); both words are checked before either is touched.',
      notes='For a handler that wants to be interrupted: it can save the exception state and lower the priority.', cf='{{r:exceptions-interrupts-and-traps}}, {{r:kernel-system-instructions-exceptions}}.'),
    E('ISYNC', 'system', ['isync'], 'Instruction synchronisation', ['ISYNC'],
      'make earlier writes to PTBR, ASID, MMUCTL and VBR, and earlier ICINVs, take effect for the instructions that follow', NOFLAGS, 'Not privileged ({{r:not-privileged-mtdp-and-mfdp}}). A non-zero pad byte is an illegal instruction.',
      notes='The architecture promises the effect only after the next `ISYNC`; an in-order implementation may make it immediate, and software must not rely on that. It is not privileged, so that a program that writes instructions can issue `ICINV` and then `ISYNC` ({{r:makes-new-instructions-visible}}); the writes to `PTBR`, `ASID`, `MMUCTL` and `VBR` that it also covers are themselves privileged.', cf='{{r:memory-ordering-from-sequential-consistency}}, {{r:system-registers-mfsr-and-mtsr}}.'),
    E('HINT', 'system', ['hint'], 'Hint', ['HINT #n        ; n = 0 to 255'], 'no architectural effect', NOFLAGS, NONE,
      notes='Defined codes: 0 a plain no-op hint, 1 pause (spin-wait), 2 speculation barrier. Every other code is a reserved hint that executes as a no-op; software shall not use it. Not privileged.'),
    E('STUA', 'system', ['stua', 'clua'], 'Set and clear the user-access guard', ['STUA', 'CLUA'],
      '''STUA: PSW.UA <- 1
CLUA: PSW.UA <- 0''', NOFLAGS, PRIV + ' A non-zero pad byte is an illegal instruction.',
      notes='`UA` is bit 12 of the status word. With `UA` clear, a kernel-mode data access (a load, a store or an operand of a block instruction) to a page whose `U` bit is set takes the load or store protection fault; `PROBER`, `PROBEW` and an instruction fetch are not affected. Exception entry clears `UA` and `EPSW` keeps the old value; `RTI` restores it, and `MTPS` writes it from kernel mode. Outside kernel mode the bit has no effect.', cf='{{r:user-memory-guard-and-system-calls}}, {{r:ua-in-the-status-word}}.'),
    E('GENTER', 'system', ['genter'], 'Enter a guest', ['GENTER #mask'],
      '''if H = 0: exit to the hypervisor (code 18)
else: ISYNC ; discard the guest's cached translations if the arena's flag or the epoch word says so ; PSW <- HEPSW ; make the guest's registers the live ones ; PC <- HEPC ; H <- 0
      every Rn (n != 14) whose bit n of mask is zero <- 0 ; if bit 14 of mask is zero, the vector registers and FPSR <- 0 ; any LL reservation is cleared''', NOFLAGS,
      'Legal only in the hypervisor mode (H = 1). A guest (H = 0) that executes it, in kernel mode, exits to the hypervisor with exit code 18; in a guest\'s user mode it is the guest\'s privileged-instruction exception (the guest\'s own privilege check comes first). On a machine with no hypervisor (HVE clear) it is an illegal instruction. A reserved mode in `HEPSW` is an illegal instruction and nothing changes.',
      notes='The one new instruction of the hypervisor mode ({{r:hypervisor-mode-the-rules}}). It includes an `ISYNC`: the earlier writes to `PTBR`, `MMUCTL`, `ASID`, `VBR`, `GTBR` and `HTRAP` take effect for what follows. It loads the status word from `HEPSW` and the program counter from `HEPC`, makes the guest\'s registers the live ones (the ordinary register names mean the guest\'s own again), clears `H`, and clears every general register whose bit the mask does not name and, with bit 14 of the mask zero, the vector registers and the floating-point flags. There is only this form: the mask is in the instruction and no system register holds it, and the hypervisor keeps nothing in registers across the guest\'s run. Nothing else is done: no translation-buffer entry is removed unless the arena\'s flag or the epoch word says so ({{r:guest-never-sees-a-stale}}), and no general register is written but the ones the mask clears. If a virtual interrupt line is pending and above the guest\'s priority, it is taken before the first guest instruction. There is no instruction that leaves a guest: a guest leaves by an exit (a trapped instruction, a hypercall by `TRAP #n`, an interrupt, a stage-2 fault).', cf='{{r:genter-enters-a-guest-before}}, {{r:rti-mask-is-the-only}}, {{r:kernel-system-instructions-exceptions}}.'),
    # ---- SYSREG ----
    E('MFSR', 'system', ['mfsr', 'mtsr'], 'Move from and to a system register', ['MFSR Rd, name', 'MTSR name, Rs'],
      '''MFSR: Rd <- system register `name`
MTSR: system register `name` <- Rs         ; read-only registers are an illegal instruction''', NOFLAGS, PRIV + ' An unassigned system register is an illegal instruction.',
      notes='The register is chosen by name (a number in parcel 1); the instruction is four bytes. A write to `MMUCTL` that changes bit 0 discards every cached translation, and a write to `PTBR` that is not accompanied by a new `ASID` discards the entries of the current `ASID`; a write to `ASID` discards nothing that is promised ({{r:writes-to-mmuctl-ptbr}}); each takes effect at the next `ISYNC` ({{r:write-to-ptbr-asid-or}}).\n\n{{SYSREGS}}', cf='{{r:system-registers-mfsr-and-mtsr}} (system registers).'),
    # ---- SYS classes with operands ----
    E('MTPS', 'system', ['mtps', 'mfps'], 'Move to and from the processor status word', ['MTPS Rs', 'MFPS Rd'],
      '''MTPS: PSW <- Rs          ; in user mode only the flags N Z V C are written
MFPS: Rd <- PSW''', '`MTPS` writes the flags from `Rs`; `MFPS` writes none.', 'A `MTPS` value with the reserved mode 2 in a mode field aborts.', cf='{{r:modes-and-the-status-word}} (modes and the status word).'),
    E('SPL', 'system', ['spl'], 'Set the interrupt priority level', ['SPL #n        ; n = 0 to 7'], 'PSW.priority <- n', NOFLAGS + ' The condition flags are untouched.', PRIV + ' A priority above 7 is an illegal instruction.',
      notes='Kept despite `MTPS` writing the whole word because it sets the priority alone: a kernel raising priority around a critical section must not clobber the flags.', cf='{{r:exceptions-interrupts-and-traps}}.'),
    E('TRAP', 'system', ['trap', 'trapl'], 'System call and trap', ['TRAP #n        ; n = 0 to 15, two bytes', 'TRAPL #n       ; n = 0 to 255, four bytes'],
      '''enter the kernel by vector (TRAP_BASE + n), with EPC = the address of the next instruction''', NOFLAGS, 'Enters the kernel; not privileged.',
      notes='The replacement for the PDP-11 `IOT` and `EMT`. `TRAPL` reaches the vectors 0 to 255 with `n` in the high byte of parcel 1.', cf='{{r:exceptions-interrupts-and-traps}}, {{r:user-memory-guard-and-system-calls}} (system calls).'),
    E('TLBI', 'system', ['tlbi'], 'Invalidate a translation', ['TLBI Rs'], 'invalidate the translation-buffer entry for the page containing the address in Rs, on this core and by broadcast on the others', NOFLAGS, PRIV,
      cf='{{r:memory-ordering-from-sequential-consistency}}, {{r:accessed-dirty-tlb-and-asids}}.'),
    E('TLBIAS', 'system', ['tlbias', 'tlbigp'], 'Invalidate by address-space number; invalidate by guest-physical page', ['TLBIAS Rs', 'TLBIGP Rs'],
      '''TLBIAS: invalidate the non-global translations of address-space number Rs[15:0], of the tag in force, on this core and by broadcast on the others
TLBIGP: (H = 1 only) invalidate the translations of the tag in GTBR that used the guest-physical page named by Rs''', NOFLAGS,
      PRIV + ' `TLBIAS` in a guest exits under the same trap-control bit as `TLBI`. `TLBIGP` is legal only in the hypervisor mode: a guest in kernel mode exits with code 18, in user mode takes its own privileged-instruction exception, and with no hypervisor (HVE clear) it is an illegal instruction.',
      notes='An implementation may discard more than is asked: one that keeps no guest-physical page discards the whole tag for `TLBIGP`. `TLBIGP` is the invalidate of a hypervisor that has changed one second-stage entry.', cf='{{r:tlbi-rn-invalidates-the-translation}}, {{r:each-translation-buffer-entry}}.')
,
    E('MTASID', 'system', ['mtasid', 'mfasid'], 'Move to and from the address-space identifier', ['MTASID Rs', 'MFASID Rd'],
      '''MTASID: ASID <- Rs[15:0]          
MFASID: Rd <- ASID''', NOFLAGS, PRIV, notes='The `ASID` tags translation-buffer entries so a context switch is one store.', cf='{{r:accessed-dirty-tlb-and-asids}}.'),
    E('MTDP', 'system', ['mtdp', 'mfdp'], 'Move to and from the direct pointer', ['MTDP Rs', 'MFDP Rd'], '''MTDP: DP <- Rs
MFDP: Rd <- DP''', NOFLAGS, NONE,
      notes='`DP` is the thread pointer in user mode and the per-CPU pointer in kernel mode; there is one copy per mode.', cf='{{r:per-cpu-state-and-cheap-context}} (per-CPU state).'),
    E('MTDMW', 'system', ['mtdmw'], 'Move to a direct-mapping window', ['MTDMW Rs'], 'DMW0 <- Rs          ; stored; it has no effect on translation', NOFLAGS, PRIV,
      notes='The direct-mapping windows are stored and have no effect on translation.', cf='{{r:splitting-the-space-and-the-layout}}.'),
    E('MFCPUID', 'system', ['mfcpuid'], 'Read the processor identifier', ['MFCPUID Rd'], 'Rd <- CPUID', NOFLAGS, PRIV,
      notes='The index of this core, for per-CPU data. It is privileged ({{r:instructions-abort-with-the-privileged}}, {{r:mfcpuid-is-privileged-each-guest}}): the kernel reads it once and keeps it in the per-CPU structure.', cf='{{r:per-cpu-state-and-cheap-context}}, {{r:cores-that-differ-classes}}.'),
    E('ICINV', 'system', ['icinv'], 'Invalidate the instruction cache for an address', ['ICINV Rs'], 'invalidate the instruction-cache line containing the address in Rs', NOFLAGS,
      'Not privileged ({{r:not-privileged-mtdp-and-mfdp}}): a program that generates code needs it.', cf='{{r:memory-ordering-from-sequential-consistency}}.'),
    E('PROBE', 'system', ['prober', 'probew'], 'Probe an address for read or write access', ['PROBER Rd, Rs', 'PROBEW Rd, Rs'],
      '''Rd <- 1 if the address in Rs is readable (PROBER) or writable (PROBEW) in the previous mode, else 0
no fault is taken''', NOFLAGS, PRIV,
      notes='Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it.', cf='{{r:user-memory-guard-and-system-calls}} (the user-memory guard), {{r:from-segments-to-pages-virtual-memory}}.'),
]
