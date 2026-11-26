# Claims about other architectures in the no-flags text, checked

Checked on 2026-11-26 against the primary source named; each quotation is under 25 words.

## RISC-V unprivileged specification

Address: https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html (the page that https://docs.riscv.org/reference/isa/unpriv/rv32.html redirects to as the latest version, fetched 2026-11-26; one load, downloaded into a temporary directory that was deleted afterwards).

* Section on conditional branches (control transfer instructions). The text says the branches compare two registers and choose that "rather than use condition codes (x86, ARM, SPARC, PowerPC)". Used in the manual (branches and control flow, "Modern comparables"): the specification of RISC-V says its conditional branches compare two registers "rather than use condition codes".
* Section on integer computational instructions. The overflow check for an unsigned addition is given as "add t0, t1, t2; bltu t0, t1, overflow": the sum compared with an addend, a branch if lower. Used in the manual (integer arithmetic, precedent of the carry idiom): the same test as the pdp64's `ADD` then `SETLO`.

## Removed because not verified

These sentences cited another architecture as a reason for, or as company in, having no flags, or stated an unverified fact about one; they were deleted:

* "RISC-V and MIPS are compare-and-branch machines with no flags, as the pdp64 is; AArch64 has CBZ and TBZ beside its flags; x86 uses flags."
* "MIPS and RISC-V compute a carry the same way, with a set-if-less-than." (replaced by the verified RISC-V sentence above)
* "`slt` on MIPS and RISC-V and AArch64's conditional set are the nearest to `SETCC`", and "the way `slt` does it on MIPS and RISC-V and `setcc` on the x86" (story of `SETCC`).
* "AArch64 keeps flags where RISC-V and the pdp64 refuse them", "RISC-V, like the pdp64, has no flags".
* "LoongArch ... can afford compare-and-branch (it has no flags either)", and "Adopted from it: ... no condition codes" in the LoongArch section.
* "LoongArch and RISC-V chose fused compare-and-branch instead of flags, and this architecture declines that" (story of `CBCC`, which was also false of the machine as it now is).
* "Macro-op fusion in current x86 and ARM cores joins a compare and a branch in the decoder" and the compare-and-branch machines (MIPS, RISC-V) long-branch remark in the commentary of the branch group.

## Kept, from this repository

* The PDP-11 names `BHIS`/`BCC` and `BLO`/`BCS`, and `C` as the borrow of `SUB` and `CMP`: `docs/pdp64-isa.md` section 4.2 (the PDP-11 sense).
* The PDP-11 add-with-carry idiom (`add` of the high words, `add` of the low words, `adc` of the high word): the PDP-11 had `ADC`, which the old specification of this machine kept (`docs/CHANGES-SINCE-R20.md`).
