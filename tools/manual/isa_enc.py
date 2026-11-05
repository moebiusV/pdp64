"""Alternative prose for the entries whose text for pdp64/r20 states how the original encoding lays the instruction out: for pdp64/16 and pdp64/32 the field
named here replaces the one in the entry (tools/mkmanual.py; the other fields of those entries are trimmed by memberprose.py).  The layouts themselves are the
charts, generated from the grammars; what is written here is meaning only."""

ATOMNOTE = ('The sub-opcodes and the semantics of this group are specified. The ISA text still does not fix where the operands go; the grammars of the prefix-coded encodings **assume** a placement '
            '(errata 87, assumption 4: three registers, the address in a register, in the order written; four for `CAS` and `CASDB`), so the forms below name the roles and the placement is *(P)*. '
            'The reference executor does not implement the group.')

NOTES = {
    'MOV': 'A register is always written in full: a narrow load sign-extends to 64 bits and there is no partial-register write anywhere. The register-to-register forms of the sized moves are the conversion set: `MOVB R1, R2` sign-extends the low byte of `R1` into `R2`.',
    'MOVZ': 'There is no zero-extending 64-bit move (it would be `MOVQ`). The register-to-register forms are the zero-extending half of the conversion set.',
    'LEA': '`LEA 0(PC), Rd` is how the program counter is read: it puts the address of the `LEA` itself in `Rd`. The base of every PC-relative displacement is the address of the first parcel of the instruction.',
    'MOVU': 'The ordinary moves fault on a misaligned address (the alignment fault is the tag check of section 9.5); these are the explicit forms for data that is not aligned.',
    'ADDM': 'The forms with a memory destination are in the ordinary memory families of the encoding, with every addressing form (errata 87).',
    'BCC': 'Condition numbers: `al` 0 (`BR`), `ne` 1, `eq` 2, `pl` 3, `mi` 4, `vc` 5, `vs` 6, `cc`/`hs` 7, `cs`/`lo` 8, `ge` 9, `lt` 10, `gt` 11, `le` 12, `hi` 13, `los` 14. Conditions on the flags: `ne` `!Z`; `eq` `Z`; `pl` `!N`; `mi` `N`; `vc` `!V`; `vs` `V`; `cc` `!C`; `cs` `C`; `ge` `N == V`; `lt` `N != V`; `gt` `!Z and N == V`; `le` `Z or N != V`; `hi` `!C and !Z`; `los` `C or Z`. The displacement counts 2-byte parcels; the reach of each form is in its chart.',
    'CBCC': 'The family has several forms for each condition (the layouts of this entry): the second operand is a register or an immediate of some width, and the reach differs. A `cbCC` that no form reaches is assembled by `as64` as `CMP` and `bCC`, which **writes the flags** (errata 87, assumption 6; the integration measured 4 such sites in 34,387 for pdp64/16 and 17 in 34,524 for pdp64/32, errata 90).',
    'BTAG': 'For runtimes that keep a 3-bit type tag in the low bits of a pointer (`lowtag`). The displacement is signed and counts parcels.',
    'SET': 'The condition is numbered as the low nibble of the branch opcodes (`al` 0, `ne` 1, `eq` 2, ... `los` 14).',
    'RET': 'Not privileged: it is the partner of `CALL`.',
    'FRINT': 'The rounding mode is in the instruction, never in a mode bit. The alternative spellings `FRINTD`, `FRINTDZ`, ... are aliases.',
    'SHIFT': 'The count is read as an unsigned 64-bit value, so a count of 64 or more shifts the value entirely away. Small immediate counts have one-parcel forms (the layouts of this entry); `ASL` and `ASR` are the by-one forms; rotates are `ROR` and `RORI`.',
    'ASL': 'The by-one form of `SHL`.', 'ASR': 'The by-one form of `SAR`.',
    'PUSHM': 'The registers are pushed in ascending order, so `POPM` with the same mask restores them. The mask is the low 32 bits of the number (errata 87, assumption 7); the one-parcel form takes an 8-bit mask scaled by 256, which names `R8` to `R15`.',
    'POPM': 'The mirror of `PUSHM`.',
    'PUSH': '',
    'TRAP': 'The replacement for the PDP-11 `IOT` and `EMT`. In these encodings `TRAP` and `TRAPL` are one word with an 8-bit vector number (`docs/encoding-proposal.md`).',
    'PUSHX': 'For a handler that wants to be interrupted: it can save the exception state and lower the priority.',
    'MFSR': 'The register is chosen by name. A write to `PTBR`, `ASID` or `MMUCTL` flushes the translation buffer.\n\n{{SYSREGS}}',
    'COUNT': '`CTZ` is the VAX `FFS`. Bit manipulation is core on a machine that does filesystem and bignum work, not an extension.',
    'RORI': '', 'DSHR': 'x86 `SHRD`, ARM `EXTR`. A 128-bit left shift by k is `DSHR hi, hi, lo, #(64-k)` then `SHL #k, lo`.',
    'EXTB': 'Position and width are immediate operands; a width of 64 cannot be encoded (errata 87, assumption 8).',
    'JMPI': 'The one deferred reference the architecture admits, for control transfer only: the PLT stub (`JMPI got_slot(PC)`) and virtual-method dispatch (`CALLI vtbl_off(Robj)`). It needs a memory operand.',
    'FMADD': 'The alternative spellings `FMADDD`, ... are aliases.',
    'FDIV': '`FDIV` and `FSQRT` are multi-cycle sequencer operations and rarely appear in a one-parcel form. The alternative spellings `FDIVD`, `FSQRTD` are aliases.',
}
for _i in ('CAS', 'SWAP', 'XADD', 'XAND', 'XMAX', 'LLSC'):
    NOTES[_i] = ATOMNOTE
EXC = {'LEA': 'The operand must name memory (a register or an immediate is not a form). No memory access is made, so the instruction takes no memory fault. A reserved encoding aborts with the illegal-instruction vector.'}
