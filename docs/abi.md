# pdp64 ABI, version 1

[← pdp64 index](../README.md)

The choices below are fixed for version 1 (the ISA, §19.5, leaves the ABI open).

| | |
|---|---|
| Data model | LP64: `char` 8, `short` 16, `int` 32, `long` 64, `long long` 64, pointers 64. Little-endian. `char` is signed. `long double` is `double`. |
| Alignment | natural; the stack pointer is a multiple of 8 at all times (data alignment is architectural, ISA 7.4: a quad access to an address not a multiple of 8 aborts; the 2-byte parcel alignment is for instructions only). No 16-byte alignment: no type or register is wider than a quad. |
| Registers | `R0`-`R5` arguments, `R0` (and `R1`) results, `R0`-`R7` and `R12` caller-saved; `R8`-`R11`, `R15` callee-saved; `R12` linker scratch; `R13` frame pointer (callee-saved, optional); `R14` stack pointer. |
| Floating point | `binary64` in a general register, `binary32` in the low 32 bits sign-extended (ISA 2.3); passed and returned exactly like integers. |
| Arguments | in order in `R0`-`R5` (a struct of up to 16 bytes takes one or two consecutive, as many as needed); the rest pushed right to left, each in an 8-byte slot (a larger struct in as many slots as it needs, by value). |
| Results | `R0`; `R0:R1` for a 128-bit pair or a struct up to 16 bytes; a larger struct through a hidden pointer passed in `R0` (the arguments then start at `R1`), and returned in `R0`. |
| Calls | `CALL`/`CALLI` push the return address; `RET` pops it. The caller removes stack arguments. |
| Varargs | the callee stores `R0`-`R5` in a save area directly below the stack arguments; `va_list` is a pointer into the area, then on into the stack arguments. One area suffices because floats use the same registers. |
| Red zone | none (version 1). |
| Symbols | no leading underscore. |
| Landing pads | off in version 1; the assembler provides `.lpad`. |
| PIC | globals through `d(PC)`; imported symbols through `MOVQ got(PC),Rd`; calls to imports through `CALLI got(PC)`; TLS local-exec `MOVQ off(DP),Rd`. |

## Register tables of the prefix-coded encodings (draft)

The encodings pdp64/16 and pdp64/32 (`spec/README.md`) give one-parcel forms to a few registers: a 3-bit register field is an index into a table of the eight hottest registers,
a 4-bit field (pdp64/32) into the sixteen hottest. The tables are measured on the compiled corpus with the registers assigned as above, and they are part of the ABI: the compiler's
allocation should prefer them, and `mov2` (two register moves in one parcel) takes only registers of the 3-bit table.

| encoding | 3-bit table (index 0-7) | 4-bit table (index 0-15) |
|---|---|---|
| pdp64/16 | `r0 r1 r8 r2 sp r3 r9 r10` | none |
| pdp64/32 | `r0 r1 r8 r2 sp r3 r9 r10` | `r0 r1 r8 r2 sp r3 r9 r10 r11 r4 r15 r5 r24 r25 r26 r6` |

In pdp64/32, `r16`-`r31` are the added registers; the draft convention is `r24`-`r26` callee-saved (the 32-register compile of the corpus used them so); the rest of `r16`-`r31` is not yet assigned.

## Variadic calls

In a call to a function declared with `...`, every argument goes in an 8-byte slot, in order: slots 0-5 are `r0`-`r5`, later slots are on the stack. A
structure of any size is passed by value in consecutive slots and may split between `r5` and the stack. A variadic callee leaves its named parameters in
their slots (`fp+16+8k`) and `va_start` is the address after the last named slot; `va_list` is a `char *` and `va_copy` is assignment. The prologue pops the
return address, pushes `r5`..`r0` and pushes the return address again, so the register save area is contiguous with the stack arguments.
