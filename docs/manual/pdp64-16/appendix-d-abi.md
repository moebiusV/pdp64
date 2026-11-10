# Appendix D. The ABI, version 1

[← manual index](00-index.md)

**The application binary interface fixes how compiled code, the linker and the operating system agree: the sizes of types, which registers carry arguments and results, who saves what, how the stack looks, and how position-independent code reaches its data.** These are decided choices (section 9.16 states what the instruction set makes cheap). The source is [`../abi.md`](../../abi.md); the compiler, the assembler and the linker follow it, and the version number allows a later change without breaking old binaries; in version 1 `long double` is `double`.

## D.1 The conventions


| | |
|---|---|
| Data model | LP64: `char` 8, `short` 16, `int` 32, `long` 64, `long long` 64, pointers 64. Little-endian. `char` is signed. `long double` is `double`. |
| Alignment | natural; the stack pointer is a multiple of **8** at all times (data alignment is architectural, ISA 7.4: a quad access to an address not a multiple of 8 aborts; the 2-byte parcel alignment is for instructions only). No 16-byte alignment: no type or register is wider than a quad. Open: whether 8 stays ([J.D.1](appendix-j-open.md#jd1)). |
| Registers | `R0`-`R5` arguments, `R0` (and `R1`) results, `R0`-`R7` and `R12` caller-saved; `R8`-`R11`, `R15` callee-saved; `R12` linker scratch; `R13` frame pointer (callee-saved, optional); `R14` stack pointer. |
| Floating point | `binary64` in a general register, `binary32` in the low 32 bits sign-extended (ISA 2.3); passed and returned exactly like integers. |
| Arguments | in order in `R0`-`R5` (a struct of up to 16 bytes takes one or two consecutive, as many as needed); the rest pushed right to left, each in an 8-byte slot (a larger struct in as many slots as it needs, by value). |
| Results | `R0`; `R0:R1` for a 128-bit pair or a struct up to 16 bytes; a larger struct through a hidden pointer passed in `R0` (the arguments then start at `R1`), and returned in `R0`. |
| Calls | `CALL`/`CALLI` push the return address; `RET` pops it. The caller removes stack arguments. |
| Varargs | the callee stores `R0`-`R5` in a save area directly below the stack arguments; `va_list` is a pointer into the area, then on into the stack arguments. One area suffices because floats use the same registers. |
| Red zone | none (version 1). |
| Symbols | no leading underscore. |
| Landing pads | off in version 1; the assembler provides `.lpad`. Open: when they become mandatory ([J.D.2](appendix-j-open.md#jd2)). |
| PIC | globals through `d(PC)`; imported symbols through `MOVQ got(PC),Rd`; calls to imports through `CALLI got(PC)`; TLS local-exec `MOVQ off(DP),Rd`. |


## D.2 Variadic calls

In a call to a function declared with `...`, every argument goes in an 8-byte slot, in order: slots 0-5 are `r0`-`r5`, later slots are on the stack. A
structure of any size is passed by value in consecutive slots and may split between `r5` and the stack. A variadic callee leaves its named parameters in
their slots (`fp+16+8k`) and `va_start` is the address after the last named slot; `va_list` is a `char *` and `va_copy` is assignment. The prologue pops the
return address, pushes `r5`..`r0` and pushes the return address again, so the register save area is contiguous with the stack arguments.

## D.3 The hot-register tables

**D.3.1** In a one-parcel form a 3-bit register field is an index into a table of the eight hottest registers, and in pdp64/32 a 4-bit field is an index into a table of the sixteen hottest. The tables are part of the ABI, because the encoding depends on them and the compiler's register allocator prefers the hot registers. *(D)*

| CPU | 3-bit table (index 0 to 7) | 4-bit table (index 0 to 15) |
|---|---|---|
| pdp64/16 | `R0 R1 R8 R2 SP R3 R9 R10` | none (the fields are register numbers) |
| pdp64/32 | `R0 R1 R8 R2 SP R3 R9 R10` | `R0 R1 R8 R2 SP R3 R9 R10 R11 R4 R15 R5 R24 R25 R26 R6` |

**D.3.2** The 3-bit table covers 90.8% of the register uses of the compiled corpus. `MOV2` takes only registers of the 3-bit table. A different allocation changes the sizes and not the correctness; the measured effect of preferring the hot registers in the allocator is at most 0.03%. *(E)*

**D.3.3** A register index beyond a table is an illegal instruction. *(D)*

## D.4 The register-save masks and the registers above R15

**D.4.1** `PUSHM`, `POPM` and `POPMRET` name registers by bit: bit n is `R`n. The mask is 16 bits, carried in 8, 16 or 32 bits by the length of the form. The 8-bit mask of `POPMRET` is scaled by 256 and names `R8` to `R15`, so a save of `R24` to `R31` is not fused with its return. *(D)*

## D.5 What the ABI leaves open

Open: the stack alignment, 8 or 16 ([J.D.1](appendix-j-open.md#jd1)); and mandatory landing pads, lazy against eager binding and whether imports are always called without a PLT stub beyond version 1 ([J.D.2](appendix-j-open.md#jd2)).
