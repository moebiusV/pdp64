"""Dictionary entries, part 3: atomics and system instructions."""
from isa_common import *

ATNOTE = ('The sub-opcodes and the semantics of this group are specified; the placement of the operands of each form is unspecified, and the forms below name the roles.')
ATFLAG = 'Not specified beyond "none for the read-modify-write forms"; `SC` reports success in its result register.'
ATEXC = 'Page fault, protection fault, alignment fault (the address must be naturally aligned) or bus error. The access is atomic with respect to every initiator, cores and devices alike.'
ATCF = '7.12 (the atomic instructions), 7.3 (the atomics in detail: the reservation monitor), 7.2 (the memory model).'

ENTRIES = [
    E('CAS', 'atomics', ['cas', 'casdb'], 'Compare and swap',
      ['CAS expected, new, (address)        ; operand placement and size encoding unspecified; size is 4 or 8 bytes', 'CASDB ...                            ; with a full barrier'],
      '''old <- M[address]                         ; 4 or 8 bytes, naturally aligned
if old == expected then M[address] <- new
result <- old          ; the program compares result with expected to learn whether the swap happened''', ATFLAG, ATEXC, '9.13, 7.12', notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('SWAP', 'atomics', ['swap', 'swapdb'], 'Atomic exchange', ['SWAP value, (address)', 'SWAPDB ...'],
      '''old <- M[address] ; M[address] <- value ; result <- old''', ATFLAG, ATEXC, '9.13, 7.12', notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XADD', 'atomics', ['xadd', 'xadddb'], 'Atomic fetch and add', ['XADD value, (address)', 'XADDDB ...'],
      '''old <- M[address] ; M[address] <- old + value ; result <- old''', ATFLAG, ATEXC, '9.13, 7.12', notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XAND', 'atomics', ['xand', 'xanddb', 'xor_', 'xor_db', 'xxor', 'xxordb'], 'Atomic fetch and and, or, xor',
      ['XAND value, (address)', 'XOR_ value, (address)        ; the trailing underscore keeps the mnemonic distinct from XOR', 'XXOR value, (address)', 'each with a DB form'],
      '''old <- M[address]
XAND: M[address] <- old AND value
XOR_: M[address] <- old OR value
XXOR: M[address] <- old XOR value
result <- old''', ATFLAG, ATEXC, '9.13, 7.12', notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('XMAX', 'atomics', ['xmax', 'xmaxdb', 'xmin', 'xmindb', 'xmaxu', 'xmaxudb', 'xminu', 'xminudb'], 'Atomic fetch and minimum or maximum',
      ['XMAX value, (address)', 'XMIN ..., XMAXU ..., XMINU ...', 'each with a DB form'],
      '''old <- M[address] ; M[address] <- max(old, value) (XMAX, XMAXU) or min (XMIN, XMINU) ; result <- old
signed for XMAX and XMIN, unsigned for the U forms''', ATFLAG, ATEXC, '9.13, 7.12', notes=ATNOTE, cf=ATCF, xnote=ATNOTE),
    E('LLSC', 'atomics', ['ll', 'sc'], 'Load-linked and store-conditional', ['LL (address), Rd', 'SC value, (address), result'],
      '''LL: Rd <- M[address] ; take a reservation on the granule containing address
SC: if the reservation is intact then M[address] <- value ; result <- 0 (success)
    else nothing is written ; result <- 1 (failure)
a write to the granule by any initiator, core or device, clears the reservation''', ATFLAG, ATEXC, '9.13, 7.12',
      notes='A short `LL`/`SC` sequence must eventually succeed if no other initiator keeps writing the granule (the RISC-V guarantee for constrained sequences). ' + ATNOTE + ' The result convention shown for `SC` is the usual one and is unspecified.', cf=ATCF, xnote=ATNOTE),

    # ---- SYS, class 0 ----
    E('NOP', 'system', ['nop', 'lpad'], 'No operation and landing pad', ['NOP', 'LPAD'], 'nothing', NOFLAGS, NONE, '9.14',
      notes='`LPAD` marks a legal target of an indirect jump or call; no instruction enforces it in ABI version 1.', cf='Appendix A, section A.1 (landing pads).'),
    E('RTI', 'system', ['rti', 'rtt'], 'Return from interrupt or exception', ['RTI', 'RTT'],
      '''PC <- EPC ; PSW <- EPSW           ; a PSW with the reserved mode 2 in either mode field aborts
RTT: and then set the trace bit T after the return''', 'Replaced by `EPSW`, including the flags.', PRIV, '9.14',
      notes='`RTT` sets the trace bit *after* the return rather than before, which is what lets a debugger single-step out of its own trap handler.', cf='6.2 (exceptions and interrupts), 6.7.'),
    E('RET', 'system', ['ret'], 'Return from subroutine', ['RET'], 'PC <- M[SP] ; SP <- SP + 8', NOFLAGS, MEMX, '9.14', notes='Not privileged, though it is in the system escape: it is the two-byte partner of `CALL`.'),
    E('HALT', 'system', ['halt'], 'Halt the processor', ['HALT'], 'stop the processor', NOFLAGS, PRIV, '9.14', cf='6.6.'),
    E('BPT', 'system', ['bpt'], 'Breakpoint', ['BPT'], 'take the breakpoint vector with EPC = the address of the next instruction', NOFLAGS, 'Enters the kernel by the `BPT` vector.', '9.14',
      notes='A trap like any other, but kept as its own two-byte instruction because a debugger patches it over an existing instruction, so it must be the shortest instruction the machine has.', cf='6.2.'),
    E('FENCE', 'system', ['fence'], 'Memory fence', ['FENCE'], 'order the memory accesses before it against those after it, for every initiator that observes them', NOFLAGS, NONE, '9.14',
      notes='Owed to devices (one `FENCE` separates writing a device\'s registers from setting its go bit) and to other cores.', cf='7.2 (the memory model), 2.2 (what the processor owes the bus).'),
    E('WFE', 'system', ['wfe', 'wait'], 'Wait for an event', ['WFE'], 'sleep until an interrupt is pending or another core executes SEV', NOFLAGS, PRIV, '9.14',
      notes='`WAIT` is an assembler alias. Whether `WFE` wakes on a pending but masked interrupt (the idle-loop question) is open.', cf='7.6 (waiting and signalling).'),
    E('SEV', 'system', ['sev'], 'Send an event', ['SEV'], 'wake every core waiting in WFE', NOFLAGS, NONE, '9.14', cf='7.6.'),
    E('TLBA', 'system', ['tlbia', 'tlbsync', 'icinva'], 'Invalidate all translations; wait for translation invalidations; invalidate the whole instruction cache',
      ['TLBIA', 'TLBSYNC', 'ICINVA'],
      '''TLBIA   : invalidate every translation-buffer entry on this core and, by broadcast, on the others
TLBSYNC : wait until the invalidations this core started have completed on every core
ICINVA  : invalidate the whole instruction cache''', NOFLAGS, 'Privileged (`TLBIA`, `TLBSYNC`); the reference executor treats `ICINVA` as a no-op.', '9.14',
      cf='7.5 (translation and instruction-cache coherence).'),
    # ---- SYSX ----
    E('PUSHX', 'system', ['pushx', 'popx'], 'Push and pop the exception state', ['PUSHX', 'POPX'],
      '''PUSHX: SP <- SP - 16 ; M[SP] <- EPSW ; M[SP + 8] <- EPC
POPX : EPSW <- M[SP] ; EPC <- M[SP + 8] ; SP <- SP + 16''', NOFLAGS, PRIV + ' `SP` must be 8-byte aligned (a misaligned-access abort); both words are checked before either is touched.', '9.14',
      notes='Four bytes (the `SYSX` escape, sub-opcodes 0 and 1) and two bytes on page 2. For a handler that wants to be interrupted: it can save the exception state and lower the priority.', cf='6.2, 6.7.'),
    E('ISYNC', 'system', ['isync'], 'Instruction synchronisation', ['ISYNC'],
      'make earlier writes to PTBR, ASID, MMUCTL and VBR, and earlier ICINVs, take effect for the instructions that follow', NOFLAGS, PRIV + ' A non-zero pad byte is an illegal instruction.', '9.14',
      notes='The architecture promises the effect only after the next `ISYNC`; an in-order implementation may make it immediate, and software must not rely on that.', cf='7.5, 6.3.'),
    E('HINT', 'system', ['hint'], 'Hint', ['HINT #n        ; n = 0 to 255'], 'no architectural effect', NOFLAGS, NONE, '9.14',
      notes='Defined codes: 0 a plain no-op hint, 1 pause (spin-wait), 2 speculation barrier. Every other code is a reserved hint that executes as a no-op; software shall not use it. Not privileged.'),
    # ---- SYSREG ----
    E('MFSR', 'system', ['mfsr', 'mtsr'], 'Move from and to a system register', ['MFSR Rd, name', 'MTSR name, Rs'],
      '''MFSR: Rd <- system register `name`
MTSR: system register `name` <- Rs         ; read-only registers are an illegal instruction''', NOFLAGS, PRIV + ' An unassigned system register is an illegal instruction.', '9.14',
      notes='The register is chosen by name (a number in parcel 1); the instruction is four bytes. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.\n\n{{SYSREGS}}', cf='6.3 (system registers).'),
    # ---- SYS classes with operands ----
    E('MTPS', 'system', ['mtps', 'mfps'], 'Move to and from the processor status word', ['MTPS Rs', 'MFPS Rd'],
      '''MTPS: PSW <- Rs          ; in user mode only the flags N Z V C are written
MFPS: Rd <- PSW''', '`MTPS` writes the flags from `Rs`; `MFPS` writes none.', 'A `MTPS` value with the reserved mode 2 in a mode field aborts.', '9.14', cf='6.1 (modes and the status word).'),
    E('SPL', 'system', ['spl'], 'Set the interrupt priority level', ['SPL #n        ; n = 0 to 7'], 'PSW.priority <- n', NOFLAGS + ' The condition flags are untouched.', PRIV + ' A priority above 7 is an illegal instruction.', '9.14',
      notes='Kept despite `MTPS` writing the whole word because it sets the priority alone: a kernel raising priority around a critical section must not clobber the flags.', cf='6.2.'),
    E('TRAP', 'system', ['trap', 'trapl'], 'System call and trap', ['TRAP #n        ; n = 0 to 15, two bytes', 'TRAPL #n       ; n = 0 to 255, four bytes'],
      '''enter the kernel by vector (TRAP_BASE + n), with EPC = the address of the next instruction''', NOFLAGS, 'Enters the kernel; not privileged.', '9.14',
      notes='The replacement for the PDP-11 `IOT` and `EMT`. `TRAPL` reaches the vectors 0 to 255 with `n` in the high byte of parcel 1.', cf='6.2, 6.5 (system calls).'),
    E('TLBI', 'system', ['tlbi'], 'Invalidate a translation', ['TLBI Rs'], 'invalidate the translation-buffer entry for the page containing the address in Rs, on this core and by broadcast on the others', NOFLAGS, PRIV, '9.14',
      cf='7.5, 6.4.'),
    E('MTASID', 'system', ['mtasid', 'mfasid'], 'Move to and from the address-space identifier', ['MTASID Rs', 'MFASID Rd'],
      '''MTASID: ASID <- Rs[15:0]          ; the translation buffer is flushed in the reference executor
MFASID: Rd <- ASID''', NOFLAGS, PRIV, '9.14', notes='The `ASID` tags translation-buffer entries so a context switch is one store.', cf='6.4.'),
    E('MTDP', 'system', ['mtdp', 'mfdp'], 'Move to and from the direct pointer', ['MTDP Rs', 'MFDP Rd'], '''MTDP: DP <- Rs
MFDP: Rd <- DP''', NOFLAGS, NONE, '9.14',
      notes='`DP` is the thread pointer in user mode and the per-CPU pointer in kernel mode; there is one copy per mode.', cf='7.4 (per-CPU state).'),
    E('MTDMW', 'system', ['mtdmw'], 'Move to a direct-mapping window', ['MTDMW Rs'], 'DMW0 <- Rs          ; storage only: the operand names no window and the format of the windows is unspecified', NOFLAGS, PRIV, '9.14',
      notes='The direct-mapping windows have no defined format.', cf='6.4.'),
    E('MFCPUID', 'system', ['mfcpuid'], 'Read the processor identifier', ['MFCPUID Rd'], 'Rd <- CPUID', NOFLAGS, NONE, '9.14',
      notes='The index of this core, for per-CPU data.', cf='7.4, 7.8.'),
    E('ICINV', 'system', ['icinv'], 'Invalidate the instruction cache for an address', ['ICINV Rs'], 'invalidate the instruction-cache line containing the address in Rs', NOFLAGS,
      'The reference executor treats it as a no-op; privilege as for the other cache-maintenance instructions.', '9.14', cf='7.5.'),
    E('PROBE', 'system', ['prober', 'probew'], 'Probe an address for read or write access', ['PROBER Rd, Rs', 'PROBEW Rd, Rs'],
      '''Rd <- 1 if the address in Rs is readable (PROBER) or writable (PROBEW) in the previous mode, else 0
no fault is taken''', NOFLAGS, PRIV, '9.14',
      notes='Taken from the VAX `PROBER` and `PROBEW`: the kernel validates a user address before using it.', cf='6.5 (the user-memory guard), 6.4.'),
]
