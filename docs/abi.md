# pdp64 ABI, version 1

Accepted choices (the ISA, §19.5, leaves the ABI open).

| | |
|---|---|
| Data model | LP64: `char` 8, `short` 16, `int` 32, `long` 64, `long long` 64, pointers 64. Little-endian. `char` is signed. `long double` is `double`. |
| Alignment | natural; the stack pointer is a multiple of **8** at all times (data alignment is architectural, ISA 7.4: a quad access to an address not a multiple of 8 aborts; the 2-byte parcel alignment is for instructions only). No 16-byte alignment: no type or register is wider than a quad. |
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

## Variadic calls (added with the first back end)

In a call to a function declared with `...`, every argument goes in an 8-byte slot, in order: slots 0-5 are `r0`-`r5`, later slots are on the stack. A
structure of any size is passed by value in consecutive slots and may split between `r5` and the stack. A variadic callee leaves its named parameters in
their slots (`fp+16+8k`) and `va_start` is the address after the last named slot; `va_list` is a `char *` and `va_copy` is assignment. The prologue pops the
return address, pushes `r5`..`r0` and pushes the return address again, so the register save area is contiguous with the stack arguments.
