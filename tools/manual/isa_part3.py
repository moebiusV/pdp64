"""Dictionary entries, part 3: atomics and system instructions."""
from isa_common import *

ATNOTE = ('The size is in the spelling: the bare name is the 8-byte word, and the 4-byte word has `L` after the operation (as `MOVL` against `MOVQ`): `AADD` and `AADDL`, `CAS` and `CASL`, `ABIS` and `ABISL`, `LL` and `LLL`, `SC` and `SCL`. A 4-byte word reads the low four bytes of `Rs` (and of the expected value in `Rd`) and puts the old value into `Rd` sign-extended, as a 4-byte load does. There is no offset: the address is the register `Ra` and nothing else.')
ATFLAG = 'None. `SC` reports success in `Rd` (0 for success, 1 for failure).'
ATEXC = 'All precise: nothing has changed, `EPC` is the instruction and `EVA` the address. An address that is not naturally aligned for the size takes the misalignment fault (no atomic is ever split over two words, two blocks or two pages, so nothing takes the bus for it). Memory that is not ordinary cached memory (uncached memory, a device\'s registers) takes the store protection fault. A page that is not present, or cannot be written, takes the fault of a store: an atomic reads and writes, and `LL` and `SC` check the access as a store too. The access is atomic with respect to every initiator, cores and devices alike.'
ATCF = '{{r:atomic-operations}} (atomic operations: the reservation monitor), {{r:multiprocessor-instructions-at-a-glance}} (the multiprocessor instructions at a glance), {{r:memory-ordering-from-sequential-consistency}} (the memory model).'

ENTRIES = [
    E('CAS', 'atomics', ['cas', 'casl'], 'Compare and swap',
      ['CAS Rs, (Ra), Rd        ; three registers, the destination last: Rd holds the expected value going in and the old value coming out, Rs the new value, Ra the address (no offset); 8 bytes', 'CASL ...                ; the same on 4 bytes'],
      '''old <- M[Ra]                              ; 8 bytes (4 for CASL), naturally aligned, ordinary cached memory
if old == Rd then M[Ra] <- Rs                  ; CASL compares and writes the low 4 bytes of Rd and Rs
Rd <- old              ; the program compares Rd with the value it expected to learn whether the swap happened''', NOFLAGS, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('SWAP', 'atomics', ['swap', 'swapl'], 'Atomic exchange', ['SWAP Rs, (Ra), Rd        ; Ra the address (no offset), Rs the value, Rd the old value', 'SWAPL ...                ; 4 bytes'],
      '''old <- M[Ra] ; M[Ra] <- Rs ; Rd <- old       ; 8 bytes (4 for SWAPL)''', NOFLAGS, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('AADD', 'atomics', ['aadd', 'aaddl'], 'Atomic fetch and add', ['AADD Rs, (Ra), Rd        ; Ra the address (no offset), Rs the operand, Rd the old value; 8 bytes', 'AADDL ...                ; 4 bytes'],
      '''old <- M[Ra] ; M[Ra] <- old + Rs ; Rd <- old     ; 8 bytes (4 for AADDL; the sum wraps in 4 bytes)''', NOFLAGS, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('AAND', 'atomics', ['aand', 'aandl', 'abis', 'abisl', 'axor', 'axorl'], 'Atomic fetch and and, bit set (or), xor',
      ['AAND Rs, (Ra), Rd', 'ABIS Rs, (Ra), Rd        ; the machine\'s own BIS, bit set, the inclusive or', 'AXOR Rs, (Ra), Rd', 'each with an L form (AANDL, ABISL, AXORL: 4 bytes)'],
      '''old <- M[Ra]
AAND: M[Ra] <- old AND Rs
ABIS: M[Ra] <- old OR Rs
AXOR: M[Ra] <- old XOR Rs
Rd <- old''', NOFLAGS, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('AMAX', 'atomics', ['amax', 'amaxl', 'amin', 'aminl', 'amaxu', 'amaxul', 'aminu', 'aminul'], 'Atomic fetch and minimum or maximum',
      ['AMAX Rs, (Ra), Rd', 'AMIN ..., AMAXU ..., AMINU ...', 'each with an L form (AMAXL, AMAXUL, AMINL, AMINUL: 4 bytes)'],
      '''old <- M[Ra] ; M[Ra] <- max(old, Rs) (AMAX, AMAXU) or min (AMIN, AMINU) ; Rd <- old
signed for AMAX and AMIN, unsigned for the U forms; the 4-byte forms compare 4-byte numbers''', NOFLAGS, ATEXC, notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('LLSC', 'atomics', ['ll', 'lll', 'sc', 'scl'], 'Load-linked and store-conditional', ['LL (Ra), Rd        ; 8 bytes', 'LLL (Ra), Rd       ; 4 bytes', 'SC Rs, (Ra), Rd    ; 8 bytes', 'SCL Rs, (Ra), Rd   ; 4 bytes'],
      '''LL: Rd <- M[Ra] ; take a reservation on the aligned 128-byte block that contains the address
SC: if the reservation is intact and Ra is the address (and the size) of the LL
    then M[Ra] <- Rs ; Rd <- 0 (success)
    else nothing is written ; Rd <- 1 (failure)
    and the reservation is over, whether the SC wrote or not''', ATFLAG, ATEXC,
      notes='The reservation is the core\'s: it ends at every `SC`, at every exit to the hypervisor and at `GENTER`, at every exception entry and every return (`RTI`, `RTT`), when another core or a device writes the marked block, and when the sequence breaks the rule of a constrained loop: between the `LL` and the `SC` at most 16 instructions run, they are instructions of registers only (no load, no store, no other atomic, no system instruction), and a taken branch goes forward. Such a loop must eventually succeed if no other initiator keeps writing the block; a sequence that breaks the rule is not hung, its `SC` fails. The marked block is fixed at 128 bytes (an implementation may keep track of less, never of less than the word, so software that wants no failure from a neighbour\'s write keeps the word alone in its block). ' + ATNOTE, cf=ATCF, xnote=ATNOTE),

    # ---- SYS, class 0 ----
    E('NOP', 'system', ['nop', 'lpad'], 'No operation and landing pad', ['NOP', 'LPAD'], 'nothing', NOFLAGS, NONE,
      notes='`LPAD` marks a legal target of an indirect jump or call; no instruction enforces it in ABI version 1.', cf='Appendix {{c:id03001|n}}, section {{r:page-bit-that-enforces-landing-pads}} (landing pads).'),
    E('RTI', 'system', ['rti', 'rtt'], 'Return from interrupt or exception', ['RTI #mask', 'RTT #mask'],
      '''PC <- EPC ; PSW <- EPSW           ; a PSW with the reserved mode 2 in either mode field aborts
if the mode returned to is lesser than the current mode: every Rn (n = 0 to 31, n != 14) whose bit n of mask is zero <- 0
    and, if bit 14 of mask is zero, the vector registers and FPSR <- 0
RTT: and then set the trace bit T after the return''', NOFLAGS, PRIV,
      notes='The mask is 32 bits, carried in parcels 1 (high half) and 2 (low half), so the instruction is six bytes; there is no form without it. `R14` is the stack pointer of the mode returned to and is never cleared, so bit 14 names the vector registers and the floating-point flags. To the same mode the mask is ignored. `RTT` sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler. The constants `RTIMASK_ALL`, `RTIMASK_NONE`, `RTIMASK_CALLEE` and `RTIMASK_SYSCALL` name the usual masks; `RTIMASK_ALL` is the one spelling that leaves the kernel\'s registers visible.', cf='{{r:exceptions-interrupts-and-traps}} (exceptions and interrupts), {{r:kernel-system-instructions-exceptions}}.'),
    E('RET', 'system', ['ret'], 'Return from subroutine', ['RET'], 'PC <- M[SP] ; SP <- SP + 8', NOFLAGS, MEMX, notes='Not privileged, though it is in the system escape: it is the two-byte partner of `CALL`.'),
    E('HALT', 'system', ['halt'], 'Halt the processor', ['HALT'], 'stop the processor', NOFLAGS, PRIV, cf='{{r:reset-and-the-first-kernel}}.'),
    E('BPT', 'system', ['bpt'], 'Breakpoint', ['BPT'], 'take the breakpoint vector with EPC = the address of the next instruction', NOFLAGS, 'Enters the kernel by the `BPT` vector.',
      notes='A trap like any other, but kept as its own two-byte instruction because a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has.', cf='{{r:exceptions-interrupts-and-traps}}.'),
    E('FENCE', 'system', ['fence'], 'Memory fence', ['FENCE'], 'order the memory accesses before it against those after it, for every initiator that observes them', NOFLAGS, NONE,
      notes='Owed to devices (one `FENCE` separates writing a device\'s registers from setting its go bit) and to other cores.', cf='{{r:memory-ordering-from-sequential-consistency}} (the memory model), {{r:pci-express-links-packets-and-configuration}} (what the processor owes the bus).'),
    E('WFE', 'system', ['wfe'], 'Wait for an event', ['WFE'], 'sleep until an interrupt is pending or another core executes SEV', NOFLAGS, PRIV,
      cf='{{r:waiting-signalling-and-interrupting-another}} (waiting and signalling).'),
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
    E('GENTER', 'system', ['genter'], 'Enter a guest', ['GENTER #mask'],
      '''if H = 0: exit to the hypervisor (code 12)
else: ISYNC ; discard the guest's cached translations if the arena's flag or the epoch word says so ; PSW <- HEPSW ; make the guest's registers the live ones ; PC <- HEPC ; H <- 0
      every Rn (n != 14) whose bit n of mask is zero <- 0 ; if bit 14 of mask is zero, the vector registers and FPSR <- 0 ; any LL reservation is cleared''', NOFLAGS,
      'Legal only in the hypervisor mode (H = 1). A guest (H = 0) that executes it, in kernel mode, exits to the hypervisor with exit code 12; in a guest\'s user mode it is the guest\'s privileged-instruction exception (the guest\'s own privilege check comes first). On a machine with no hypervisor (HVE clear) it is an illegal instruction. A reserved mode in `HEPSW` is an illegal instruction and nothing changes.',
      notes='The one new instruction of the hypervisor mode ({{r:hypervisor-mode-the-rules}}). It includes an `ISYNC`: the earlier writes to `PTBR`, `MMUCTL`, `ASID`, `VBR`, `GTBR` and `HTRAP` take effect for what follows. It loads the status word from `HEPSW` and the program counter from `HEPC`, makes the guest\'s registers the live ones (the ordinary register names mean the guest\'s own again), clears `H`, and clears every general register whose bit the mask does not name and, with bit 14 of the mask zero, the vector registers and the floating-point flags. There is only this form: the mask is in the instruction and no system register holds it, and the hypervisor keeps nothing in registers across the guest\'s run. Nothing else is done: no translation-buffer entry is removed unless the arena\'s flag or the epoch word says so ({{r:guest-never-sees-a-stale}}), and no general register is written but the ones the mask clears. If a virtual interrupt line is pending and above the guest\'s priority, it is taken before the first guest instruction. There is no instruction that leaves a guest: a guest leaves by an exit (a trapped instruction, a hypercall by `TRAP #n`, an interrupt, a stage-2 fault).', cf='{{r:genter-enters-a-guest-before}}, {{r:rti-mask-is-the-only}}, {{r:kernel-system-instructions-exceptions}}.'),
    # ---- SYSREG ----
    E('MFSR', 'system', ['mfsr', 'mtsr'], 'Move from and to a system register', ['MFSR Rd, name', 'MTSR name, Rs'],
      '''MFSR: Rd <- system register `name`
MTSR: system register `name` <- Rs         ; read-only registers are an illegal instruction''', NOFLAGS, PRIV + ' An unassigned system register is an illegal instruction.',
      notes='The register is chosen by name (a number in parcel 1); the instruction is four bytes. A write to `MMUCTL` that changes bit 0 discards every cached translation, and a write to `PTBR` that is not accompanied by a new `ASID` discards the entries of the current `ASID`; a write to `ASID` discards nothing that is promised ({{r:writes-to-mmuctl-ptbr}}), and its low 16 bits are the address-space identifier that tags the translation-buffer entries, so that a context switch is one store ({{r:accessed-dirty-tlb-and-asids}}); `CPUID` is the index of this core, for per-CPU data: reading it is privileged like every system register ({{r:instructions-abort-with-the-privileged}}, {{r:mfcpuid-is-privileged-each-guest}}), and the kernel reads it once and keeps it in the per-CPU structure ({{r:per-cpu-state-and-cheap-context}}, {{r:cores-that-differ-classes}}); each takes effect at the next `ISYNC` ({{r:write-to-ptbr-asid-or}}).\n\n{{SYSREGS}}', cf='{{r:system-registers-mfsr-and-mtsr}} (system registers).'),
    # ---- SYS classes with operands ----
    E('MTPS', 'system', ['mtps', 'mfps'], 'Move to and from the processor status word', ['MTPS Rs', 'MFPS Rd'],
      '''MTPS: PSW <- Rs          ; privileged
MFPS: Rd <- PSW''', NOFLAGS, '`MTPS` is privileged. A `MTPS` value with the reserved mode 2 in a mode field aborts.', cf='{{r:modes-and-the-status-word}} (modes and the status word).'),
    E('SPL', 'system', ['spl'], 'Set the interrupt priority level', ['SPL #n        ; n = 0 to 7'], 'PSW.priority <- n', NOFLAGS, PRIV + ' A priority above 7 is an illegal instruction.',
      notes='Kept despite `MTPS` writing the whole word because it sets the priority alone: a kernel raising priority around a critical section leaves the trace bit and the modes as they are.', cf='{{r:exceptions-interrupts-and-traps}}.'),
    E('TRAP', 'system', ['trap'], 'System call and trap', ['TRAP #n        ; n = 0 to 255, two bytes'],
      '''enter the kernel by vector (TRAP_BASE + n), with EPC = the address of the next instruction''', NOFLAGS, 'Enters the kernel; not privileged.',
      notes='The replacement for the PDP-11 `IOT` and `EMT`. The 8-bit vector number is in the one parcel, so every `TRAP #n` is two bytes. The sub-opcode 10 is a second encoding of the same instruction; the assembler writes 01 and a disassembler prints `TRAP` for both.', cf='{{r:exceptions-interrupts-and-traps}}, {{r:user-memory-guard-and-system-calls}} (system calls).'),
    E('TLBI', 'system', ['tlbi'], 'Invalidate a translation', ['TLBI Rs'], 'invalidate the translation-buffer entry for the page containing the address in Rs, on this core and by broadcast on the others', NOFLAGS, PRIV,
      cf='{{r:memory-ordering-from-sequential-consistency}}, {{r:accessed-dirty-tlb-and-asids}}.'),
    E('TLBIAS', 'system', ['tlbias', 'tlbigp'], 'Invalidate by address-space number; invalidate by guest-physical page', ['TLBIAS Rs', 'TLBIGP Rs'],
      '''TLBIAS: invalidate the non-global translations of address-space number Rs[15:0], of the tag in force, on this core and by broadcast on the others
TLBIGP: (H = 1 only) invalidate the translations of the tag in GTBR that used the guest-physical page named by Rs''', NOFLAGS,
      PRIV + ' `TLBIAS` in a guest exits under the same trap-control bit as `TLBI`. `TLBIGP` is legal only in the hypervisor mode: a guest in kernel mode exits with code 12, in user mode takes its own privileged-instruction exception, and with no hypervisor (HVE clear) it is an illegal instruction.',
      notes='An implementation may discard more than is asked: one that keeps no guest-physical page discards the whole tag for `TLBIGP`. `TLBIGP` is the invalidate of a hypervisor that has changed one second-stage entry.', cf='{{r:tlbi-rn-invalidates-the-translation}}, {{r:each-translation-buffer-entry}}.')
,
    E('MTDP', 'system', ['mtdp', 'mfdp'], 'Move to and from the direct pointer', ['MTDP Rs', 'MFDP Rd'], '''MTDP: DP <- Rs
MFDP: Rd <- DP''', NOFLAGS, NONE,
      notes='`DP` is the thread pointer in user mode and the per-CPU pointer in kernel mode; there is one copy per mode.', cf='{{r:per-cpu-state-and-cheap-context}} (per-CPU state).'),
    E('ICINV', 'system', ['icinv'], 'Invalidate the instruction cache for an address', ['ICINV Rs'], 'invalidate the instruction-cache line containing the address in Rs', NOFLAGS,
      'Not privileged ({{r:not-privileged-mtdp-and-mfdp}}): a program that generates code needs it.', cf='{{r:memory-ordering-from-sequential-consistency}}.'),
    E('PROBE', 'system', ['prober', 'probew'], 'Probe an address for read or write access', ['PROBER Rd, Rs', 'PROBEW Rd, Rs'],
      '''Rd <- 1 if the address in Rs is readable (PROBER) or writable (PROBEW) in the previous mode, else 0
no fault is taken''', NOFLAGS, PRIV,
      notes='Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it.', cf='{{r:user-memory-guard-and-system-calls}} (the user-memory guard), {{r:from-segments-to-pages-virtual-memory}}.'),
]
