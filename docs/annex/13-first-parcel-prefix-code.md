# Part 7. Encoding and the instruction set

## {{#annex-first-parcel}} The first-parcel prefix code: what the common instructions cost

**The decision.** Every instruction begins with a 16-bit **parcel** whose leading bits are a **prefix code**, so that the first parcel alone says what the instruction is and how long it is (two, four or six bytes), and the shortest prefixes belong to the instructions the compiler emits most.

**The problem.** The PDP-11 packed an instruction into 16 bits as 4 bits of operation and two 6-bit **specifiers** (3 bits of addressing mode, 3 of register); an operand that needed more (an address, a constant) followed in extra words. It was dense, and its length was a function of the first word alone, although of both specifiers at once. The VAX read operand specifiers one after another, one byte or more each, so that the length of an instruction was known only after the last was read; x86 reads prefixes, an opcode, a mode byte and more in sequence. Dense and variable length cost a lot to decode on a wide machine; fixed length (every instruction 4 bytes, as on classic Arm and RISC-V) decodes trivially and costs code size, so more instruction cache misses.

A **prefix code** is a set of bit strings none of which begins another (the idea of Huffman's code: the commonest symbols get the shortest strings). If the leading bits of the first parcel are such a string, the first parcel matches at most one form, with no look-ahead, and the match gives the length as well. I gave the choice of lengths to an optimiser that was shown the compiled programs (841 files), so a common instruction such as an add of two registers is a prefix of a few bits and has room for its register fields, while a rare one is long.

### Before and after

**Before** (the same five operations on three other instruction sets; each snippet assembled here with clang or `as`, `snippets/foreign/sizes-*.s`):

```
x86-64                           RISC-V rv64g          Arm AArch64
addq %rsi,%rdi        3 bytes    add a0,a0,a1   4      add x0,x0,x1       4
movq (%rdx),%rcx      3          ld a2,0(a3)    4      ldr x2,[x3]        4
movq 8(%rdx),%rcx     4          ld a2,8(a3)    4      ldr x2,[x3,#8]     4
cmpq %rsi,%rdi ; je   3+2        beq a0,a1,1f   4      cmp x0,x1 ; b.eq   4+4
movq $5,%rax          7          li a0,5        4      mov x0,#5          4
                      22 bytes                 20                        24
```

*(Six, five and six instructions. With the compressed extension, RISC-V (`rv64gc`) takes 12 bytes for the same five lines, which is shorter than 16: I show this because it is true. The measure that matters is the whole program: on the repository's corpus of compiled programs rv64gc comes to 1.22 times the pdp64's bytes at `-Os` and 1.35 at `-O1`, because it needs more instructions, though each is shorter: 2.93 bytes an instruction against 3.26.)*

**After** (pdp64, `snippets/foreign/sizes-pdp64.s`, assembled with `build/as64`):

```
        add     r1, r2          ; 2 bytes
        movq    (r3), r4        ; 4
        movq    8(r3), r4       ; 4
        cbeq    r1, r2, 1f      ; 4: compare and branch in one instruction
1:      movq    #5, r5          ; 2
                                ; 16 bytes, five instructions
```

*(An add of two registers and a small immediate are two bytes, a load four, and compare-and-branch is one instruction of four bytes. A return from interrupt, a rare instruction, is six.)*

### What it enables

* **Dense code with an easy decoder.** The length of an instruction is a function of its first 16 bits, so a fetch unit finds where the next instruction starts after one lookup; no byte-by-byte scan as on x86.
* **A measured encoding.** The corpus of compiled programs is 964,158 bytes in 296,070 instructions (3.26 bytes an instruction), 11.04% fewer bytes than the first encoding; over six large programs the programs execute 24.21% fewer instructions and 28.94% fewer bytes than on the first encoding.
* **Common things short, rare things long**, by construction, not by custom: the optimiser pays for each opcode slot in what the frequent forms lose.
* **A wild jump that fails early.** 3,278 of the 65,536 first-parcel patterns (5.0%) match no prefix and are illegal instructions; so is a sub-opcode that no mnemonic uses.

### What it saves us from

* **A user instruction that stops the machine.** The F00F bug of the Pentium: "All models of Pentium ... have the F0 0F bug, which lets nonprivileged users lock up the system" (a message in the Linux kernel's `arch/x86/kernel/cpu/intel.c`, as the repository records it from the local source tree). Here every pattern of the first parcel is either a defined instruction or the illegal-instruction exception, and the security corpus probes the whole table of first parcels.
* **Instruction length that depends on what follows.** A length known only after reading operand after operand is a hazard for the fetch stage and for software that must find instruction boundaries (a debugger, a disassembler, a tool that patches code).
* **Code size by decree.** A fixed 4-byte instruction costs the instruction cache; here frequent forms are 2 bytes.

I do not claim immunity to a fault of the **placement** kind. Intel's JCC erratum (the microcode fix made branches that overlay or end on a 32-byte boundary unable to fill the decoded-instruction cache, "0-4%" slower on some benchmarks, and software pads with prefix bytes to avoid it) was a fix whose cost depended on where instructions sit relative to a fetch block. The pdp64's instructions are two-byte aligned and up to six bytes, so one can cross a cache line; the decision keeps the *length* a function of the first parcel but does not exempt us from the rule that no fix may depend on placement.

### What it costs

The decoder reads up to 16 bits to find the length, and the fetch path must handle an instruction that crosses a fetch block. Byte-granular encoding as in x86 would buy perhaps a tenth of the code size and cost a full alignment rotator and a cross-line splice; parcels of 16 bits are the compromise. Rare instructions are long (an `RTI` is six bytes); a 64-bit constant is loaded from a pool: 16 bytes in all for one such load with its pool word, counted from an assembled object.

### What it puts off limits

Instructions are 2-byte aligned and at most 3 parcels; there is no 64-bit immediate inside an instruction, and no byte-granular instruction.

### Where the manual states it

{{r:every-instruction-begins}}, {{r:prefixes-form-a-prefix-code}}, {{r:length-of-an-instruction}}, {{r:illegal-first-parcel-patterns}} and {{r:measured-on-the-841-file}}.
