# The bit layouts of every opcode (pdp64/r20)

[← dictionary index](index.md)

Every opcode of the original encoding has a chart here: one for each distinct layout (class of instruction, length, and body) that the grammar admits. The fields and their widths are the bit rules of `spec/pdp64.hbnf.in` (parcel 0 is `len opcode reg low`, and the body that follows is chosen by the guards of its alternatives), the numbers are the enumerations of `spec/pdp64-mnemonics.hbnf`, and what a field is called is `spec/pdp64-layout.hbnf`. The charts are generated from those files by `tools/mkmanual.py`; changing a field in a grammar changes the chart.

**How to read a chart.** Each row is one 16-bit parcel, bit 15 on the left, the bit numbers above the boxes. A shaded box has a fixed value, written in it; a white box is a field of the instruction. Fields are named `opN.part` for the part of the Nth operand of the assembly syntax (`op1.d` is the displacement of the first operand); a field the layout splits is `name[1]`, `name[2]` from the top. A register field of 3 or 4 bits holds an index into the hot-register table of the ABI, not a register number.

## The charts

### Moves, address formation and the ALU

<a id="r20-mem-0"></a>
#### r20-mem-0: Moves, address formation and the ALU, one parcel (`len = 00`)

![Layout r20-mem-0](../figures/r20-mem-0.svg)

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-1"></a>
#### r20-mem-1: Moves, address formation and the ALU, two parcels (`len = 01`)

![Layout r20-mem-1](../figures/r20-mem-1.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-1-2"></a>
#### r20-mem-1-2: Moves, address formation and the ALU, two parcels (`len = 01`)

![Layout r20-mem-1-2](../figures/r20-mem-1-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-1-3"></a>
#### r20-mem-1-3: Moves, address formation and the ALU, two parcels (`len = 01`)

![Layout r20-mem-1-3](../figures/r20-mem-1-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-1-4"></a>
#### r20-mem-1-4: Moves, address formation and the ALU, two parcels (`len = 01`)

![Layout r20-mem-1-4](../figures/r20-mem-1-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-2"></a>
#### r20-mem-2: Moves, address formation and the ALU, three parcels (`len = 10`)

![Layout r20-mem-2](../figures/r20-mem-2.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-2-2"></a>
#### r20-mem-2-2: Moves, address formation and the ALU, three parcels (`len = 10`)

![Layout r20-mem-2-2](../figures/r20-mem-2-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-2-3"></a>
#### r20-mem-2-3: Moves, address formation and the ALU, three parcels (`len = 10`)

![Layout r20-mem-2-3](../figures/r20-mem-2-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

<a id="r20-mem-2-4"></a>
#### r20-mem-2-4: Moves, address formation and the ALU, three parcels (`len = 10`)

![Layout r20-mem-2-4](../figures/r20-mem-2-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

`reg` is the register `Rd` (the source of a store); `low` is a second register (`Rs`) at `len = 00` and the addressing mode from `len = 01`; the extension parcels hold the operand (section 9.5).

| Mnemonic | Opcode |
|---|---|
| `MOVQ` | `000000 (0x00)`, `000001 (0x01)` |
| `MOVL` | `000010 (0x02)`, `000011 (0x03)` |
| `MOVW` | `000100 (0x04)`, `000101 (0x05)` |
| `MOVB` | `000110 (0x06)`, `000111 (0x07)` |
| `MOVZL` | `001000 (0x08)` |
| `MOVZW` | `001001 (0x09)` |
| `MOVZB` | `001010 (0x0A)` |
| `LEA` | `001011 (0x0B)` |
| `ADD` | `010110 (0x16)` |
| `SUB` | `010111 (0x17)` |
| `BIC` | `011000 (0x18)` |
| `BIS` | `011001 (0x19)` |
| `CMP` | `011010 (0x1A)` |
| `BIT` | `011011 (0x1B)` |
| `XOR` | `011100 (0x1C)` |
| `AND` | `011101 (0x1D)` |
| `MUL` | `011110 (0x1E)` |
| `MULH` | `011111 (0x1F)` |
| `SHL` | `100000 (0x20)` |
| `SHR` | `100001 (0x21)` |
| `SAR` | `100010 (0x22)` |
| `FADD` | `100100 (0x24)` |
| `FSUB` | `100101 (0x25)` |
| `FMUL` | `100110 (0x26)` |
| `FCMP` | `100111 (0x27)` |

### Conditional branches

<a id="r20-br-0"></a>
#### r20-br-0: Conditional branches, one parcel (`len = 00`)

![Layout r20-br-0](../figures/r20-br-0.svg)

The displacement is signed and counts 2-byte parcels from the first parcel of the instruction.

| Mnemonic | Opcode |
|---|---|
| `BR` | `110000 (0x30)` |
| `BNE` | `110001 (0x31)` |
| `BEQ` | `110010 (0x32)` |
| `BPL` | `110011 (0x33)` |
| `BMI` | `110100 (0x34)` |
| `BVC` | `110101 (0x35)` |
| `BVS` | `110110 (0x36)` |
| `BCC` | `110111 (0x37)` |
| `BCS` | `111000 (0x38)` |
| `BGE` | `111001 (0x39)` |
| `BLT` | `111010 (0x3A)` |
| `BGT` | `111011 (0x3B)` |
| `BLE` | `111100 (0x3C)` |
| `BHI` | `111101 (0x3D)` |
| `BLOS` | `111110 (0x3E)` |

<a id="r20-br-1"></a>
#### r20-br-1: Conditional branches, two parcels (`len = 01`)

![Layout r20-br-1](../figures/r20-br-1.svg)

The displacement is signed and counts 2-byte parcels from the first parcel of the instruction.

| Mnemonic | Opcode |
|---|---|
| `BR` | `110000 (0x30)` |
| `BNE` | `110001 (0x31)` |
| `BEQ` | `110010 (0x32)` |
| `BPL` | `110011 (0x33)` |
| `BMI` | `110100 (0x34)` |
| `BVC` | `110101 (0x35)` |
| `BVS` | `110110 (0x36)` |
| `BCC` | `110111 (0x37)` |
| `BCS` | `111000 (0x38)` |
| `BGE` | `111001 (0x39)` |
| `BLT` | `111010 (0x3A)` |
| `BGT` | `111011 (0x3B)` |
| `BLE` | `111100 (0x3C)` |
| `BHI` | `111101 (0x3D)` |
| `BLOS` | `111110 (0x3E)` |

<a id="r20-br-2"></a>
#### r20-br-2: Conditional branches, three parcels (`len = 10`)

![Layout r20-br-2](../figures/r20-br-2.svg)

The displacement is signed and counts 2-byte parcels from the first parcel of the instruction.

| Mnemonic | Opcode |
|---|---|
| `BR` | `110000 (0x30)` |
| `BNE` | `110001 (0x31)` |
| `BEQ` | `110010 (0x32)` |
| `BPL` | `110011 (0x33)` |
| `BMI` | `110100 (0x34)` |
| `BVC` | `110101 (0x35)` |
| `BVS` | `110110 (0x36)` |
| `BCC` | `110111 (0x37)` |
| `BCS` | `111000 (0x38)` |
| `BGE` | `111001 (0x39)` |
| `BLT` | `111010 (0x3A)` |
| `BGT` | `111011 (0x3B)` |
| `BLE` | `111100 (0x3C)` |
| `BHI` | `111101 (0x3D)` |
| `BLOS` | `111110 (0x3E)` |

### Compare and branch

<a id="r20-cb-1"></a>
#### r20-cb-1: Compare and branch, two parcels (`len = 01`)

![Layout r20-cb-1](../figures/r20-cb-1.svg)

`low` is the condition; the immediate and the displacement are signed.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101000 (0x28)` | `0001 (0x1)` |
| `CBEQ` | `101000 (0x28)` | `0010 (0x2)` |
| `CBPL` | `101000 (0x28)` | `0011 (0x3)` |
| `CBMI` | `101000 (0x28)` | `0100 (0x4)` |
| `CBVC` | `101000 (0x28)` | `0101 (0x5)` |
| `CBVS` | `101000 (0x28)` | `0110 (0x6)` |
| `CBCC` | `101000 (0x28)` | `0111 (0x7)` |
| `CBCS` | `101000 (0x28)` | `1000 (0x8)` |
| `CBGE` | `101000 (0x28)` | `1001 (0x9)` |
| `CBLT` | `101000 (0x28)` | `1010 (0xA)` |
| `CBGT` | `101000 (0x28)` | `1011 (0xB)` |
| `CBLE` | `101000 (0x28)` | `1100 (0xC)` |
| `CBHI` | `101000 (0x28)` | `1101 (0xD)` |
| `CBLOS` | `101000 (0x28)` | `1110 (0xE)` |

<a id="r20-cb-1-2"></a>
#### r20-cb-1-2: Compare two registers and branch, two parcels (`len = 01`)

![Layout r20-cb-1-2](../figures/r20-cb-1-2.svg)

Parcel 1 starts with the condition; `Ra` and `Rb` are compared.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101010 (0x2A)` | `0001 (0x1)` |
| `CBEQ` | `101010 (0x2A)` | `0010 (0x2)` |
| `CBPL` | `101010 (0x2A)` | `0011 (0x3)` |
| `CBMI` | `101010 (0x2A)` | `0100 (0x4)` |
| `CBVC` | `101010 (0x2A)` | `0101 (0x5)` |
| `CBVS` | `101010 (0x2A)` | `0110 (0x6)` |
| `CBCC` | `101010 (0x2A)` | `0111 (0x7)` |
| `CBCS` | `101010 (0x2A)` | `1000 (0x8)` |
| `CBGE` | `101010 (0x2A)` | `1001 (0x9)` |
| `CBLT` | `101010 (0x2A)` | `1010 (0xA)` |
| `CBGT` | `101010 (0x2A)` | `1011 (0xB)` |
| `CBLE` | `101010 (0x2A)` | `1100 (0xC)` |
| `CBHI` | `101010 (0x2A)` | `1101 (0xD)` |
| `CBLOS` | `101010 (0x2A)` | `1110 (0xE)` |

<a id="r20-cb-2"></a>
#### r20-cb-2: Compare and branch, three parcels (`len = 10`)

![Layout r20-cb-2](../figures/r20-cb-2.svg)

`low` is the condition; the immediate and the displacement are signed.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101000 (0x28)` | `0001 (0x1)` |
| `CBEQ` | `101000 (0x28)` | `0010 (0x2)` |
| `CBPL` | `101000 (0x28)` | `0011 (0x3)` |
| `CBMI` | `101000 (0x28)` | `0100 (0x4)` |
| `CBVC` | `101000 (0x28)` | `0101 (0x5)` |
| `CBVS` | `101000 (0x28)` | `0110 (0x6)` |
| `CBCC` | `101000 (0x28)` | `0111 (0x7)` |
| `CBCS` | `101000 (0x28)` | `1000 (0x8)` |
| `CBGE` | `101000 (0x28)` | `1001 (0x9)` |
| `CBLT` | `101000 (0x28)` | `1010 (0xA)` |
| `CBGT` | `101000 (0x28)` | `1011 (0xB)` |
| `CBLE` | `101000 (0x28)` | `1100 (0xC)` |
| `CBHI` | `101000 (0x28)` | `1101 (0xD)` |
| `CBLOS` | `101000 (0x28)` | `1110 (0xE)` |

<a id="r20-cb-2-2"></a>
#### r20-cb-2-2: Compare and branch, three parcels (`len = 10`)

![Layout r20-cb-2-2](../figures/r20-cb-2-2.svg)

`low` is the condition; the immediate and the displacement are signed.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101001 (0x29)` | `0001 (0x1)` |
| `CBEQ` | `101001 (0x29)` | `0010 (0x2)` |
| `CBPL` | `101001 (0x29)` | `0011 (0x3)` |
| `CBMI` | `101001 (0x29)` | `0100 (0x4)` |
| `CBVC` | `101001 (0x29)` | `0101 (0x5)` |
| `CBVS` | `101001 (0x29)` | `0110 (0x6)` |
| `CBCC` | `101001 (0x29)` | `0111 (0x7)` |
| `CBCS` | `101001 (0x29)` | `1000 (0x8)` |
| `CBGE` | `101001 (0x29)` | `1001 (0x9)` |
| `CBLT` | `101001 (0x29)` | `1010 (0xA)` |
| `CBGT` | `101001 (0x29)` | `1011 (0xB)` |
| `CBLE` | `101001 (0x29)` | `1100 (0xC)` |
| `CBHI` | `101001 (0x29)` | `1101 (0xD)` |
| `CBLOS` | `101001 (0x29)` | `1110 (0xE)` |

<a id="r20-cb-2-3"></a>
#### r20-cb-2-3: Compare two registers and branch, three parcels (`len = 10`)

![Layout r20-cb-2-3](../figures/r20-cb-2-3.svg)

Parcel 1 starts with the condition; `Ra` and `Rb` are compared.

| Mnemonic | Opcode | `low` |
|---|---|---|
| `CBNE` | `101010 (0x2A)` | `0001 (0x1)` |
| `CBEQ` | `101010 (0x2A)` | `0010 (0x2)` |
| `CBPL` | `101010 (0x2A)` | `0011 (0x3)` |
| `CBMI` | `101010 (0x2A)` | `0100 (0x4)` |
| `CBVC` | `101010 (0x2A)` | `0101 (0x5)` |
| `CBVS` | `101010 (0x2A)` | `0110 (0x6)` |
| `CBCC` | `101010 (0x2A)` | `0111 (0x7)` |
| `CBCS` | `101010 (0x2A)` | `1000 (0x8)` |
| `CBGE` | `101010 (0x2A)` | `1001 (0x9)` |
| `CBLT` | `101010 (0x2A)` | `1010 (0xA)` |
| `CBGT` | `101010 (0x2A)` | `1011 (0xB)` |
| `CBLE` | `101010 (0x2A)` | `1100 (0xC)` |
| `CBHI` | `101010 (0x2A)` | `1101 (0xD)` |
| `CBLOS` | `101010 (0x2A)` | `1110 (0xE)` |

### SOB

<a id="r20-sob-1"></a>
#### r20-sob-1: SOB, two parcels (`len = 01`)

![Layout r20-sob-1](../figures/r20-sob-1.svg)

The displacement is signed and counts parcels.

| Mnemonic | Opcode |
|---|---|
| `SOB` | `111111 (0x3F)` |

<a id="r20-sob-2"></a>
#### r20-sob-2: SOB, three parcels (`len = 10`)

![Layout r20-sob-2](../figures/r20-sob-2.svg)

The displacement is signed and counts parcels.

| Mnemonic | Opcode |
|---|---|
| `SOB` | `111111 (0x3F)` |

### Tag branches

<a id="r20-tag-1"></a>
#### r20-tag-1: Tag branches, two parcels (`len = 01`)

![Layout r20-tag-1](../figures/r20-tag-1.svg)

`sense` is 0 for `BTAG` and 1 for `BNTAG`; `tag` is the 3-bit tag.

| Mnemonic | Opcode |
|---|---|
| `BTAG` | `010101 (0x15)` |
| `BNTAG` | `010101 (0x15)` |

<a id="r20-tag-2"></a>
#### r20-tag-2: Tag branches, three parcels (`len = 10`)

![Layout r20-tag-2](../figures/r20-tag-2.svg)

`sense` is 0 for `BTAG` and 1 for `BNTAG`; `tag` is the 3-bit tag.

| Mnemonic | Opcode |
|---|---|
| `BTAG` | `010101 (0x15)` |
| `BNTAG` | `010101 (0x15)` |

### Single operand (SOP)

<a id="r20-sop-0"></a>
#### r20-sop-0: Single operand (SOP), one parcel (`len = 00`)

![Layout r20-sop-0](../figures/r20-sop-0.svg)

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-1"></a>
#### r20-sop-1: Single operand (SOP), two parcels (`len = 01`)

![Layout r20-sop-1](../figures/r20-sop-1.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-1-2"></a>
#### r20-sop-1-2: Single operand (SOP), two parcels (`len = 01`)

![Layout r20-sop-1-2](../figures/r20-sop-1-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-1-3"></a>
#### r20-sop-1-3: Single operand (SOP), two parcels (`len = 01`)

![Layout r20-sop-1-3](../figures/r20-sop-1-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-1-4"></a>
#### r20-sop-1-4: Single operand (SOP), two parcels (`len = 01`)

![Layout r20-sop-1-4](../figures/r20-sop-1-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-2"></a>
#### r20-sop-2: Single operand (SOP), three parcels (`len = 10`)

![Layout r20-sop-2](../figures/r20-sop-2.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-2-2"></a>
#### r20-sop-2-2: Single operand (SOP), three parcels (`len = 10`)

![Layout r20-sop-2-2](../figures/r20-sop-2-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-2-3"></a>
#### r20-sop-2-3: Single operand (SOP), three parcels (`len = 10`)

![Layout r20-sop-2-3](../figures/r20-sop-2-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

<a id="r20-sop-2-4"></a>
#### r20-sop-2-4: Single operand (SOP), three parcels (`len = 10`)

![Layout r20-sop-2-4](../figures/r20-sop-2-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `CLR` | `010011 (0x13)` | `0000 (0x0)` |
| `COM` | `010011 (0x13)` | `0001 (0x1)` |
| `INC` | `010011 (0x13)` | `0010 (0x2)` |
| `DEC` | `010011 (0x13)` | `0011 (0x3)` |
| `NEG` | `010011 (0x13)` | `0100 (0x4)` |
| `TST` | `010011 (0x13)` | `0101 (0x5)` |
| `ADC` | `010011 (0x13)` | `0110 (0x6)` |
| `SBC` | `010011 (0x13)` | `0111 (0x7)` |
| `ASL` | `010011 (0x13)` | `1000 (0x8)` |
| `ASR` | `010011 (0x13)` | `1001 (0x9)` |
| `PUSHM` | `010011 (0x13)` | `1010 (0xA)` |
| `POPM` | `010011 (0x13)` | `1011 (0xB)` |
| `JMP` | `010011 (0x13)` | `1100 (0xC)` |
| `CALL` | `010011 (0x13)` | `1101 (0xD)` |
| `PUSH` | `010011 (0x13)` | `1110 (0xE)` |
| `POP` | `010011 (0x13)` | `1111 (0xF)` |

### Indirect transfers (XFER)

<a id="r20-xfer-0"></a>
#### r20-xfer-0: Indirect transfers (XFER), one parcel (`len = 00`)

![Layout r20-xfer-0](../figures/r20-xfer-0.svg)

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-1"></a>
#### r20-xfer-1: Indirect transfers (XFER), two parcels (`len = 01`)

![Layout r20-xfer-1](../figures/r20-xfer-1.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-1-2"></a>
#### r20-xfer-1-2: Indirect transfers (XFER), two parcels (`len = 01`)

![Layout r20-xfer-1-2](../figures/r20-xfer-1-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-1-3"></a>
#### r20-xfer-1-3: Indirect transfers (XFER), two parcels (`len = 01`)

![Layout r20-xfer-1-3](../figures/r20-xfer-1-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-1-4"></a>
#### r20-xfer-1-4: Indirect transfers (XFER), two parcels (`len = 01`)

![Layout r20-xfer-1-4](../figures/r20-xfer-1-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-2"></a>
#### r20-xfer-2: Indirect transfers (XFER), three parcels (`len = 10`)

![Layout r20-xfer-2](../figures/r20-xfer-2.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `postinc` 0110, `predec` 0111.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-2-2"></a>
#### r20-xfer-2-2: Indirect transfers (XFER), three parcels (`len = 10`)

![Layout r20-xfer-2-2](../figures/r20-xfer-2-2.svg)

Addressing modes (`low`) that use this layout: `index` 0001.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-2-3"></a>
#### r20-xfer-2-3: Indirect transfers (XFER), three parcels (`len = 10`)

![Layout r20-xfer-2-3](../figures/r20-xfer-2-3.svg)

Addressing modes (`low`) that use this layout: `pcrel` 0010, `imm` 0100, `abs` 0101.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

<a id="r20-xfer-2-4"></a>
#### r20-xfer-2-4: Indirect transfers (XFER), three parcels (`len = 10`)

![Layout r20-xfer-2-4](../figures/r20-xfer-2-4.svg)

Addressing modes (`low`) that use this layout: `dp` 0011.

The `reg` field is the sub-opcode; the operand is `rm` with its mode, at any length.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `JMPI` | `010010 (0x12)` | `0000 (0x0)` |
| `CALLI` | `010010 (0x12)` | `0001 (0x1)` |
| `JTAG` | `010010 (0x12)` | `0010 (0x2)` |

### Bits and fields (BESC)

<a id="r20-besc-1"></a>
#### r20-besc-1: Bits and fields (BESC), two parcels (`len = 01`)

![Layout r20-besc-1](../figures/r20-besc-1.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLZ` | `001100 (0x0C)` | `00000000 (0x00)` |
| `CTZ` | `001100 (0x0C)` | `00000001 (0x01)` |
| `CLO` | `001100 (0x0C)` | `00000010 (0x02)` |
| `CTO` | `001100 (0x0C)` | `00000011 (0x03)` |
| `POPCNT` | `001100 (0x0C)` | `00000100 (0x04)` |
| `BSWAP` | `001100 (0x0C)` | `00000101 (0x05)` |
| `BSWAPW` | `001100 (0x0C)` | `00000110 (0x06)` |
| `BSWAPL` | `001100 (0x0C)` | `00000111 (0x07)` |
| `BITREV` | `001100 (0x0C)` | `00001000 (0x08)` |
| `ROR` | `001100 (0x0C)` | `00010000 (0x10)` |
| `DSHR` | `001100 (0x0C)` | `00100000 (0x20)` |
| `EXTB` | `001100 (0x0C)` | `00100001 (0x21)` |
| `EXTZB` | `001100 (0x0C)` | `00100010 (0x22)` |
| `INSB` | `001100 (0x0C)` | `00100011 (0x23)` |
| `XNORPOP` | `001100 (0x0C)` | `00110000 (0x30)` |
| `CLMULL` | `001100 (0x0C)` | `00110001 (0x31)` |
| `CLMULH` | `001100 (0x0C)` | `00110010 (0x32)` |
| `UTF8LEN` | `001100 (0x0C)` | `01000000 (0x40)` |
| `UTF8DEC` | `001100 (0x0C)` | `01000001 (0x41)` |
| `UTF8ENC` | `001100 (0x0C)` | `01000010 (0x42)` |

<a id="r20-besc-1-2"></a>
#### r20-besc-1-2: Bits and fields (BESC), two parcels (`len = 01`)

![Layout r20-besc-1-2](../figures/r20-besc-1-2.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `RORI` | `001100 (0x0C)` | `00010001 (0x11)` |
| `RORI32` | `001100 (0x0C)` | `00010010 (0x12)` |

<a id="r20-besc-2"></a>
#### r20-besc-2: Bits and fields (BESC), three parcels (`len = 10`)

![Layout r20-besc-2](../figures/r20-besc-2.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CLZ` | `001100 (0x0C)` | `00000000 (0x00)` |
| `CTZ` | `001100 (0x0C)` | `00000001 (0x01)` |
| `CLO` | `001100 (0x0C)` | `00000010 (0x02)` |
| `CTO` | `001100 (0x0C)` | `00000011 (0x03)` |
| `POPCNT` | `001100 (0x0C)` | `00000100 (0x04)` |
| `BSWAP` | `001100 (0x0C)` | `00000101 (0x05)` |
| `BSWAPW` | `001100 (0x0C)` | `00000110 (0x06)` |
| `BSWAPL` | `001100 (0x0C)` | `00000111 (0x07)` |
| `BITREV` | `001100 (0x0C)` | `00001000 (0x08)` |
| `ROR` | `001100 (0x0C)` | `00010000 (0x10)` |
| `XNORPOP` | `001100 (0x0C)` | `00110000 (0x30)` |
| `CLMULL` | `001100 (0x0C)` | `00110001 (0x31)` |
| `CLMULH` | `001100 (0x0C)` | `00110010 (0x32)` |
| `UTF8LEN` | `001100 (0x0C)` | `01000000 (0x40)` |
| `UTF8DEC` | `001100 (0x0C)` | `01000001 (0x41)` |
| `UTF8ENC` | `001100 (0x0C)` | `01000010 (0x42)` |

<a id="r20-besc-2-2"></a>
#### r20-besc-2-2: Bits and fields (BESC), three parcels (`len = 10`)

![Layout r20-besc-2-2](../figures/r20-besc-2-2.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `RORI` | `001100 (0x0C)` | `00010001 (0x11)` |
| `RORI32` | `001100 (0x0C)` | `00010010 (0x12)` |

<a id="r20-besc-2-3"></a>
#### r20-besc-2-3: Bits and fields (BESC), three parcels (`len = 10`)

![Layout r20-besc-2-3](../figures/r20-besc-2-3.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DSHR` | `001100 (0x0C)` | `00100000 (0x20)` |
| `EXTB` | `001100 (0x0C)` | `00100001 (0x21)` |
| `EXTZB` | `001100 (0x0C)` | `00100010 (0x22)` |
| `INSB` | `001100 (0x0C)` | `00100011 (0x23)` |

### Block memory (MBLK)

<a id="r20-mblk-1"></a>
#### r20-mblk-1: Block memory (MBLK), two parcels (`len = 01`)

![Layout r20-mblk-1](../figures/r20-mblk-1.svg)

`reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MCPY` | `001101 (0x0D)` | `00000000 (0x00)` |
| `MMOV` | `001101 (0x0D)` | `00000001 (0x01)` |
| `MSET` | `001101 (0x0D)` | `00000010 (0x02)` |
| `MCMP` | `001101 (0x0D)` | `00000011 (0x03)` |
| `MSCN` | `001101 (0x0D)` | `00000100 (0x04)` |
| `MSCNN` | `001101 (0x0D)` | `00000101 (0x05)` |
| `MVAL` | `001101 (0x0D)` | `00000110 (0x06)` |

<a id="r20-mblk-2"></a>
#### r20-mblk-2: Block memory (MBLK), three parcels (`len = 10`)

![Layout r20-mblk-2](../figures/r20-mblk-2.svg)

`reg` is the destination pointer, `low` the source pointer (or the value register), `Rn` the count register.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MCPY` | `001101 (0x0D)` | `00000000 (0x00)` |
| `MMOV` | `001101 (0x0D)` | `00000001 (0x01)` |
| `MSET` | `001101 (0x0D)` | `00000010 (0x02)` |
| `MCMP` | `001101 (0x0D)` | `00000011 (0x03)` |
| `MSCN` | `001101 (0x0D)` | `00000100 (0x04)` |
| `MSCNN` | `001101 (0x0D)` | `00000101 (0x05)` |
| `MVAL` | `001101 (0x0D)` | `00000110 (0x06)` |

### Arithmetic (AESC)

<a id="r20-aesc-1"></a>
#### r20-aesc-1: Arithmetic (AESC), two parcels (`len = 01`)

![Layout r20-aesc-1](../figures/r20-aesc-1.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DIV` | `001110 (0x0E)` | `00000000 (0x00)` |
| `DIVU` | `001110 (0x0E)` | `00000001 (0x01)` |
| `MOD` | `001110 (0x0E)` | `00000010 (0x02)` |
| `MODU` | `001110 (0x0E)` | `00000011 (0x03)` |
| `MULHU` | `001110 (0x0E)` | `00000100 (0x04)` |
| `ABS` | `001110 (0x0E)` | `00001000 (0x08)` |
| `MIN` | `001110 (0x0E)` | `00010000 (0x10)` |
| `MINU` | `001110 (0x0E)` | `00010001 (0x11)` |
| `MAX` | `001110 (0x0E)` | `00010010 (0x12)` |
| `MAXU` | `001110 (0x0E)` | `00010011 (0x13)` |
| `SET` | `001110 (0x0E)` | `00100000 (0x20)` |

<a id="r20-aesc-2"></a>
#### r20-aesc-2: Arithmetic (AESC), three parcels (`len = 10`)

![Layout r20-aesc-2](../figures/r20-aesc-2.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `DIV` | `001110 (0x0E)` | `00000000 (0x00)` |
| `DIVU` | `001110 (0x0E)` | `00000001 (0x01)` |
| `MOD` | `001110 (0x0E)` | `00000010 (0x02)` |
| `MODU` | `001110 (0x0E)` | `00000011 (0x03)` |
| `MULHU` | `001110 (0x0E)` | `00000100 (0x04)` |
| `ABS` | `001110 (0x0E)` | `00001000 (0x08)` |
| `MIN` | `001110 (0x0E)` | `00010000 (0x10)` |
| `MINU` | `001110 (0x0E)` | `00010001 (0x11)` |
| `MAX` | `001110 (0x0E)` | `00010010 (0x12)` |
| `MAXU` | `001110 (0x0E)` | `00010011 (0x13)` |
| `SET` | `001110 (0x0E)` | `00100000 (0x20)` |

### Floating point (FESC)

<a id="r20-fesc-1"></a>
#### r20-fesc-1: Floating point (FESC), two parcels (`len = 01`)

![Layout r20-fesc-1](../figures/r20-fesc-1.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV` | `010000 (0x10)` | `00000000 (0x00)` |
| `FSQRT` | `010000 (0x10)` | `00000001 (0x01)` |
| `FADD32` | `010000 (0x10)` | `00001000 (0x08)` |
| `FSUB32` | `010000 (0x10)` | `00001001 (0x09)` |
| `FMUL32` | `010000 (0x10)` | `00001010 (0x0A)` |
| `FDIV32` | `010000 (0x10)` | `00001011 (0x0B)` |
| `FSQRT32` | `010000 (0x10)` | `00001100 (0x0C)` |
| `FCMP32` | `010000 (0x10)` | `00001101 (0x0D)` |
| `FMADD` | `010000 (0x10)` | `00010000 (0x10)` |
| `FMSUB` | `010000 (0x10)` | `00010001 (0x11)` |
| `FNMADD` | `010000 (0x10)` | `00010010 (0x12)` |
| `FNMSUB` | `010000 (0x10)` | `00010011 (0x13)` |
| `FMADD32` | `010000 (0x10)` | `00011000 (0x18)` |
| `FMSUB32` | `010000 (0x10)` | `00011001 (0x19)` |
| `FNMADD32` | `010000 (0x10)` | `00011010 (0x1A)` |
| `FNMSUB32` | `010000 (0x10)` | `00011011 (0x1B)` |
| `FNEG` | `010000 (0x10)` | `00100000 (0x20)` |
| `FABS` | `010000 (0x10)` | `00100001 (0x21)` |
| `FCOPYSIGN` | `010000 (0x10)` | `00100010 (0x22)` |
| `FMIN` | `010000 (0x10)` | `00100011 (0x23)` |
| `FMAX` | `010000 (0x10)` | `00100100 (0x24)` |
| `FCLASS` | `010000 (0x10)` | `00101000 (0x28)` |
| `FCLASS32` | `010000 (0x10)` | `00101001 (0x29)` |
| `FRINT` | `010000 (0x10)` | `00110000 (0x30)` |
| `FRINTZ` | `010000 (0x10)` | `00110001 (0x31)` |
| `FRINTM` | `010000 (0x10)` | `00110010 (0x32)` |
| `FRINTP` | `010000 (0x10)` | `00110011 (0x33)` |
| `FRINTA` | `010000 (0x10)` | `00110100 (0x34)` |
| `FCVTDQ` | `010000 (0x10)` | `00111000 (0x38)` |
| `FCVTQD` | `010000 (0x10)` | `00111001 (0x39)` |
| `FCVTDS` | `010000 (0x10)` | `00111010 (0x3A)` |
| `FCVTSD` | `010000 (0x10)` | `00111011 (0x3B)` |
| `FCVTSL` | `010000 (0x10)` | `00111100 (0x3C)` |
| `FCVTLS` | `010000 (0x10)` | `00111101 (0x3D)` |
| `FCVTDQU` | `010000 (0x10)` | `00111110 (0x3E)` |
| `FCVTQUD` | `010000 (0x10)` | `00111111 (0x3F)` |
| `FSFLAGS` | `010000 (0x10)` | `01000000 (0x40)` |
| `FADD16` | `010000 (0x10)` | `01010000 (0x50)` |
| `FSUB16` | `010000 (0x10)` | `01010001 (0x51)` |
| `FMUL16` | `010000 (0x10)` | `01010010 (0x52)` |
| `FDIV16` | `010000 (0x10)` | `01010011 (0x53)` |
| `FSQRT16` | `010000 (0x10)` | `01010100 (0x54)` |
| `FCMP16` | `010000 (0x10)` | `01010101 (0x55)` |
| `FMADD16` | `010000 (0x10)` | `01011000 (0x58)` |
| `FMSUB16` | `010000 (0x10)` | `01011001 (0x59)` |
| `FNMADD16` | `010000 (0x10)` | `01011010 (0x5A)` |
| `FNMSUB16` | `010000 (0x10)` | `01011011 (0x5B)` |
| `FCLASS16` | `010000 (0x10)` | `01011100 (0x5C)` |
| `FCVTSH` | `010000 (0x10)` | `01100000 (0x60)` |
| `FCVTHS` | `010000 (0x10)` | `01100001 (0x61)` |
| `FCVTDH` | `010000 (0x10)` | `01100010 (0x62)` |
| `FCVTHD` | `010000 (0x10)` | `01100011 (0x63)` |
| `FCVTHL` | `010000 (0x10)` | `01100100 (0x64)` |
| `FCVTLH` | `010000 (0x10)` | `01100101 (0x65)` |

<a id="r20-fesc-2"></a>
#### r20-fesc-2: Floating point (FESC), three parcels (`len = 10`)

![Layout r20-fesc-2](../figures/r20-fesc-2.svg)

From `len = 01`. In this group `low` is a register, never a mode.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `FDIV` | `010000 (0x10)` | `00000000 (0x00)` |
| `FSQRT` | `010000 (0x10)` | `00000001 (0x01)` |
| `FADD32` | `010000 (0x10)` | `00001000 (0x08)` |
| `FSUB32` | `010000 (0x10)` | `00001001 (0x09)` |
| `FMUL32` | `010000 (0x10)` | `00001010 (0x0A)` |
| `FDIV32` | `010000 (0x10)` | `00001011 (0x0B)` |
| `FSQRT32` | `010000 (0x10)` | `00001100 (0x0C)` |
| `FCMP32` | `010000 (0x10)` | `00001101 (0x0D)` |
| `FMADD` | `010000 (0x10)` | `00010000 (0x10)` |
| `FMSUB` | `010000 (0x10)` | `00010001 (0x11)` |
| `FNMADD` | `010000 (0x10)` | `00010010 (0x12)` |
| `FNMSUB` | `010000 (0x10)` | `00010011 (0x13)` |
| `FMADD32` | `010000 (0x10)` | `00011000 (0x18)` |
| `FMSUB32` | `010000 (0x10)` | `00011001 (0x19)` |
| `FNMADD32` | `010000 (0x10)` | `00011010 (0x1A)` |
| `FNMSUB32` | `010000 (0x10)` | `00011011 (0x1B)` |
| `FNEG` | `010000 (0x10)` | `00100000 (0x20)` |
| `FABS` | `010000 (0x10)` | `00100001 (0x21)` |
| `FCOPYSIGN` | `010000 (0x10)` | `00100010 (0x22)` |
| `FMIN` | `010000 (0x10)` | `00100011 (0x23)` |
| `FMAX` | `010000 (0x10)` | `00100100 (0x24)` |
| `FCLASS` | `010000 (0x10)` | `00101000 (0x28)` |
| `FCLASS32` | `010000 (0x10)` | `00101001 (0x29)` |
| `FRINT` | `010000 (0x10)` | `00110000 (0x30)` |
| `FRINTZ` | `010000 (0x10)` | `00110001 (0x31)` |
| `FRINTM` | `010000 (0x10)` | `00110010 (0x32)` |
| `FRINTP` | `010000 (0x10)` | `00110011 (0x33)` |
| `FRINTA` | `010000 (0x10)` | `00110100 (0x34)` |
| `FCVTDQ` | `010000 (0x10)` | `00111000 (0x38)` |
| `FCVTQD` | `010000 (0x10)` | `00111001 (0x39)` |
| `FCVTDS` | `010000 (0x10)` | `00111010 (0x3A)` |
| `FCVTSD` | `010000 (0x10)` | `00111011 (0x3B)` |
| `FCVTSL` | `010000 (0x10)` | `00111100 (0x3C)` |
| `FCVTLS` | `010000 (0x10)` | `00111101 (0x3D)` |
| `FCVTDQU` | `010000 (0x10)` | `00111110 (0x3E)` |
| `FCVTQUD` | `010000 (0x10)` | `00111111 (0x3F)` |
| `FSFLAGS` | `010000 (0x10)` | `01000000 (0x40)` |
| `FADD16` | `010000 (0x10)` | `01010000 (0x50)` |
| `FSUB16` | `010000 (0x10)` | `01010001 (0x51)` |
| `FMUL16` | `010000 (0x10)` | `01010010 (0x52)` |
| `FDIV16` | `010000 (0x10)` | `01010011 (0x53)` |
| `FSQRT16` | `010000 (0x10)` | `01010100 (0x54)` |
| `FCMP16` | `010000 (0x10)` | `01010101 (0x55)` |
| `FMADD16` | `010000 (0x10)` | `01011000 (0x58)` |
| `FMSUB16` | `010000 (0x10)` | `01011001 (0x59)` |
| `FNMADD16` | `010000 (0x10)` | `01011010 (0x5A)` |
| `FNMSUB16` | `010000 (0x10)` | `01011011 (0x5B)` |
| `FCLASS16` | `010000 (0x10)` | `01011100 (0x5C)` |
| `FCVTSH` | `010000 (0x10)` | `01100000 (0x60)` |
| `FCVTHS` | `010000 (0x10)` | `01100001 (0x61)` |
| `FCVTDH` | `010000 (0x10)` | `01100010 (0x62)` |
| `FCVTHD` | `010000 (0x10)` | `01100011 (0x63)` |
| `FCVTHL` | `010000 (0x10)` | `01100100 (0x64)` |
| `FCVTLH` | `010000 (0x10)` | `01100101 (0x65)` |

### Atomics (ATOM)

<a id="r20-atom-1"></a>
#### r20-atom-1: Atomics (ATOM), two parcels (`len = 01`)

![Layout r20-atom-1](../figures/r20-atom-1.svg)

From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CAS` | `010001 (0x11)` | `00000000 (0x00)` |
| `CASDB` | `010001 (0x11)` | `00000001 (0x01)` |
| `SWAP` | `010001 (0x11)` | `00000010 (0x02)` |
| `SWAPDB` | `010001 (0x11)` | `00000011 (0x03)` |
| `XADD` | `010001 (0x11)` | `00000100 (0x04)` |
| `XADDDB` | `010001 (0x11)` | `00000101 (0x05)` |
| `XAND` | `010001 (0x11)` | `00000110 (0x06)` |
| `XANDDB` | `010001 (0x11)` | `00000111 (0x07)` |
| `XOR_` | `010001 (0x11)` | `00001000 (0x08)` |
| `XOR_DB` | `010001 (0x11)` | `00001001 (0x09)` |
| `XXOR` | `010001 (0x11)` | `00001010 (0x0A)` |
| `XXORDB` | `010001 (0x11)` | `00001011 (0x0B)` |
| `XMAX` | `010001 (0x11)` | `00001100 (0x0C)` |
| `XMAXDB` | `010001 (0x11)` | `00001101 (0x0D)` |
| `XMIN` | `010001 (0x11)` | `00001110 (0x0E)` |
| `XMINDB` | `010001 (0x11)` | `00001111 (0x0F)` |
| `XMAXU` | `010001 (0x11)` | `00010000 (0x10)` |
| `XMAXUDB` | `010001 (0x11)` | `00010001 (0x11)` |
| `XMINU` | `010001 (0x11)` | `00010010 (0x12)` |
| `XMINUDB` | `010001 (0x11)` | `00010011 (0x13)` |
| `LL` | `010001 (0x11)` | `00100000 (0x20)` |
| `SC` | `010001 (0x11)` | `00100001 (0x21)` |

<a id="r20-atom-2"></a>
#### r20-atom-2: Atomics (ATOM), three parcels (`len = 10`)

![Layout r20-atom-2](../figures/r20-atom-2.svg)

From `len = 01`. The placement of the operands is not specified.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `CAS` | `010001 (0x11)` | `00000000 (0x00)` |
| `CASDB` | `010001 (0x11)` | `00000001 (0x01)` |
| `SWAP` | `010001 (0x11)` | `00000010 (0x02)` |
| `SWAPDB` | `010001 (0x11)` | `00000011 (0x03)` |
| `XADD` | `010001 (0x11)` | `00000100 (0x04)` |
| `XADDDB` | `010001 (0x11)` | `00000101 (0x05)` |
| `XAND` | `010001 (0x11)` | `00000110 (0x06)` |
| `XANDDB` | `010001 (0x11)` | `00000111 (0x07)` |
| `XOR_` | `010001 (0x11)` | `00001000 (0x08)` |
| `XOR_DB` | `010001 (0x11)` | `00001001 (0x09)` |
| `XXOR` | `010001 (0x11)` | `00001010 (0x0A)` |
| `XXORDB` | `010001 (0x11)` | `00001011 (0x0B)` |
| `XMAX` | `010001 (0x11)` | `00001100 (0x0C)` |
| `XMAXDB` | `010001 (0x11)` | `00001101 (0x0D)` |
| `XMIN` | `010001 (0x11)` | `00001110 (0x0E)` |
| `XMINDB` | `010001 (0x11)` | `00001111 (0x0F)` |
| `XMAXU` | `010001 (0x11)` | `00010000 (0x10)` |
| `XMAXUDB` | `010001 (0x11)` | `00010001 (0x11)` |
| `XMINU` | `010001 (0x11)` | `00010010 (0x12)` |
| `XMINUDB` | `010001 (0x11)` | `00010011 (0x13)` |
| `LL` | `010001 (0x11)` | `00100000 (0x20)` |
| `SC` | `010001 (0x11)` | `00100001 (0x21)` |

### Memory escape (MESC)

<a id="r20-mesc-1"></a>
#### r20-mesc-1: Memory escape (MESC), two parcels (`len = 01`)

![Layout r20-mesc-1](../figures/r20-mesc-1.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `index` 0001, `pcrel` 0010, `dp` 0011, `imm` 0100, `abs` 0101, `postinc` 0110, `predec` 0111.

`low` of parcel 0 is an addressing mode; parcel 1 holds the sub-opcode, `rm` and the first 8 bits of the displacement.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUB` | `001111 (0x0F)` | `0000 (0x0)` |
| `MOVUW` | `001111 (0x0F)` | `0010 (0x2)` |
| `MOVUL` | `001111 (0x0F)` | `0100 (0x4)` |
| `MOVUQ` | `001111 (0x0F)` | `0110 (0x6)` |
| `ADDM` | `001111 (0x0F)` | `1000 (0x8)` |
| `SUBM` | `001111 (0x0F)` | `1001 (0x9)` |
| `BICM` | `001111 (0x0F)` | `1010 (0xA)` |
| `BISM` | `001111 (0x0F)` | `1011 (0xB)` |

<a id="r20-mesc-2"></a>
#### r20-mesc-2: Memory escape (MESC), three parcels (`len = 10`)

![Layout r20-mesc-2](../figures/r20-mesc-2.svg)

Addressing modes (`low`) that use this layout: `base` 0000, `index` 0001, `pcrel` 0010, `dp` 0011, `imm` 0100, `abs` 0101, `postinc` 0110, `predec` 0111.

`low` of parcel 0 is an addressing mode; parcel 1 holds the sub-opcode, `rm` and the first 8 bits of the displacement.

| Mnemonic | Opcode | Sub-opcode |
|---|---|---|
| `MOVUB` | `001111 (0x0F)` | `0000 (0x0)` |
| `MOVUW` | `001111 (0x0F)` | `0010 (0x2)` |
| `MOVUL` | `001111 (0x0F)` | `0100 (0x4)` |
| `MOVUQ` | `001111 (0x0F)` | `0110 (0x6)` |
| `ADDM` | `001111 (0x0F)` | `1000 (0x8)` |
| `SUBM` | `001111 (0x0F)` | `1001 (0x9)` |
| `BICM` | `001111 (0x0F)` | `1010 (0xA)` |
| `BISM` | `001111 (0x0F)` | `1011 (0xB)` |

### System, no operand

<a id="r20-sysn-0"></a>
#### r20-sysn-0: System, no operand, one parcel (`len = 00`)

![Layout r20-sysn-0](../figures/r20-sysn-0.svg)

The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `NOP` | `010100 (0x14)` | `0000 (0x0)` | `0000 (0x0)` |
| `RTI` | `010100 (0x14)` | `0000 (0x0)` | `0001 (0x1)` |
| `RTT` | `010100 (0x14)` | `0000 (0x0)` | `0010 (0x2)` |
| `RET` | `010100 (0x14)` | `0000 (0x0)` | `0011 (0x3)` |
| `HALT` | `010100 (0x14)` | `0000 (0x0)` | `0100 (0x4)` |
| `BPT` | `010100 (0x14)` | `0000 (0x0)` | `0101 (0x5)` |
| `FENCE` | `010100 (0x14)` | `0000 (0x0)` | `0110 (0x6)` |
| `WFE` | `010100 (0x14)` | `0000 (0x0)` | `0111 (0x7)` |
| `SEV` | `010100 (0x14)` | `0000 (0x0)` | `1000 (0x8)` |
| `LPAD` | `010100 (0x14)` | `0000 (0x0)` | `1001 (0x9)` |
| `TLBIA` | `010100 (0x14)` | `0000 (0x0)` | `1010 (0xA)` |
| `TLBSYNC` | `010100 (0x14)` | `0000 (0x0)` | `1011 (0xB)` |
| `ICINVA` | `010100 (0x14)` | `0000 (0x0)` | `1100 (0xC)` |

<a id="r20-sysn-1"></a>
#### r20-sysn-1: System, no operand, two parcels (`len = 01`)

![Layout r20-sysn-1](../figures/r20-sysn-1.svg)

The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `NOP` | `010100 (0x14)` | `0000 (0x0)` | `0000 (0x0)` |
| `RTI` | `010100 (0x14)` | `0000 (0x0)` | `0001 (0x1)` |
| `RTT` | `010100 (0x14)` | `0000 (0x0)` | `0010 (0x2)` |
| `RET` | `010100 (0x14)` | `0000 (0x0)` | `0011 (0x3)` |
| `HALT` | `010100 (0x14)` | `0000 (0x0)` | `0100 (0x4)` |
| `BPT` | `010100 (0x14)` | `0000 (0x0)` | `0101 (0x5)` |
| `FENCE` | `010100 (0x14)` | `0000 (0x0)` | `0110 (0x6)` |
| `WFE` | `010100 (0x14)` | `0000 (0x0)` | `0111 (0x7)` |
| `SEV` | `010100 (0x14)` | `0000 (0x0)` | `1000 (0x8)` |
| `LPAD` | `010100 (0x14)` | `0000 (0x0)` | `1001 (0x9)` |
| `TLBIA` | `010100 (0x14)` | `0000 (0x0)` | `1010 (0xA)` |
| `TLBSYNC` | `010100 (0x14)` | `0000 (0x0)` | `1011 (0xB)` |
| `ICINVA` | `010100 (0x14)` | `0000 (0x0)` | `1100 (0xC)` |

<a id="r20-sysn-2"></a>
#### r20-sysn-2: System, no operand, three parcels (`len = 10`)

![Layout r20-sysn-2](../figures/r20-sysn-2.svg)

The `reg` field is the class (0); class 0 takes a minor opcode from `low`.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `NOP` | `010100 (0x14)` | `0000 (0x0)` | `0000 (0x0)` |
| `RTI` | `010100 (0x14)` | `0000 (0x0)` | `0001 (0x1)` |
| `RTT` | `010100 (0x14)` | `0000 (0x0)` | `0010 (0x2)` |
| `RET` | `010100 (0x14)` | `0000 (0x0)` | `0011 (0x3)` |
| `HALT` | `010100 (0x14)` | `0000 (0x0)` | `0100 (0x4)` |
| `BPT` | `010100 (0x14)` | `0000 (0x0)` | `0101 (0x5)` |
| `FENCE` | `010100 (0x14)` | `0000 (0x0)` | `0110 (0x6)` |
| `WFE` | `010100 (0x14)` | `0000 (0x0)` | `0111 (0x7)` |
| `SEV` | `010100 (0x14)` | `0000 (0x0)` | `1000 (0x8)` |
| `LPAD` | `010100 (0x14)` | `0000 (0x0)` | `1001 (0x9)` |
| `TLBIA` | `010100 (0x14)` | `0000 (0x0)` | `1010 (0xA)` |
| `TLBSYNC` | `010100 (0x14)` | `0000 (0x0)` | `1011 (0xB)` |
| `ICINVA` | `010100 (0x14)` | `0000 (0x0)` | `1100 (0xC)` |

### System, SYSX

<a id="r20-sysx-0"></a>
#### r20-sysx-0: System, SYSX, one parcel (`len = 00`)

![Layout r20-sysx-0](../figures/r20-sysx-0.svg)

Class 0, minor 15: the sub-opcode is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `PUSHX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000000 (0x00)` |
| `POPX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000001 (0x01)` |
| `ISYNC` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000010 (0x02)` |
| `HINT` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000011 (0x03)` |

<a id="r20-sysx-1"></a>
#### r20-sysx-1: System, SYSX, two parcels (`len = 01`)

![Layout r20-sysx-1](../figures/r20-sysx-1.svg)

Class 0, minor 15: the sub-opcode is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` | Sub-opcode |
|---|---|---|---|---|
| `PUSHX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000000 (0x00)` |
| `POPX` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000001 (0x01)` |
| `ISYNC` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000010 (0x02)` |
| `HINT` | `010100 (0x14)` | `0000 (0x0)` | `1111 (0xF)` | `00000011 (0x03)` |

### System registers (MFSR, MTSR)

<a id="r20-sysreg-0"></a>
#### r20-sysreg-0: System registers (MFSR, MTSR), one parcel (`len = 00`)

![Layout r20-sysreg-0](../figures/r20-sysreg-0.svg)

Class 0: the system register number is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `MFSR` | `010100 (0x14)` | `0000 (0x0)` | `1101 (0xD)` |
| `MTSR` | `010100 (0x14)` | `0000 (0x0)` | `1110 (0xE)` |

<a id="r20-sysreg-1"></a>
#### r20-sysreg-1: System registers (MFSR, MTSR), two parcels (`len = 01`)

![Layout r20-sysreg-1](../figures/r20-sysreg-1.svg)

Class 0: the system register number is in parcel 1.

| Mnemonic | Opcode | `reg` | `low` |
|---|---|---|---|
| `MFSR` | `010100 (0x14)` | `0000 (0x0)` | `1101 (0xD)` |
| `MTSR` | `010100 (0x14)` | `0000 (0x0)` | `1110 (0xE)` |

### System

<a id="r20-sys-0"></a>
#### r20-sys-0: System, one parcel (`len = 00`)

![Layout r20-sys-0](../figures/r20-sys-0.svg)

The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTPS` | `010100 (0x14)` | `0001 (0x1)` |
| `MFPS` | `010100 (0x14)` | `0010 (0x2)` |
| `SPL` | `010100 (0x14)` | `0011 (0x3)` |
| `TRAP` | `010100 (0x14)` | `0100 (0x4)` |
| `TLBI` | `010100 (0x14)` | `0101 (0x5)` |
| `MTASID` | `010100 (0x14)` | `0110 (0x6)` |
| `MFASID` | `010100 (0x14)` | `0111 (0x7)` |
| `MTDP` | `010100 (0x14)` | `1000 (0x8)` |
| `MFDP` | `010100 (0x14)` | `1001 (0x9)` |
| `MTDMW` | `010100 (0x14)` | `1010 (0xA)` |
| `MFCPUID` | `010100 (0x14)` | `1011 (0xB)` |
| `ICINV` | `010100 (0x14)` | `1100 (0xC)` |
| `PROBER` | `010100 (0x14)` | `1101 (0xD)` |
| `PROBEW` | `010100 (0x14)` | `1110 (0xE)` |
| `TRAPL` | `010100 (0x14)` | `1111 (0xF)` |

<a id="r20-sys-1"></a>
#### r20-sys-1: System, two parcels (`len = 01`)

![Layout r20-sys-1](../figures/r20-sys-1.svg)

The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTPS` | `010100 (0x14)` | `0001 (0x1)` |
| `MFPS` | `010100 (0x14)` | `0010 (0x2)` |
| `SPL` | `010100 (0x14)` | `0011 (0x3)` |
| `TRAP` | `010100 (0x14)` | `0100 (0x4)` |
| `TLBI` | `010100 (0x14)` | `0101 (0x5)` |
| `MTASID` | `010100 (0x14)` | `0110 (0x6)` |
| `MFASID` | `010100 (0x14)` | `0111 (0x7)` |
| `MTDP` | `010100 (0x14)` | `1000 (0x8)` |
| `MFDP` | `010100 (0x14)` | `1001 (0x9)` |
| `MTDMW` | `010100 (0x14)` | `1010 (0xA)` |
| `MFCPUID` | `010100 (0x14)` | `1011 (0xB)` |
| `ICINV` | `010100 (0x14)` | `1100 (0xC)` |

<a id="r20-sys-1-2"></a>
#### r20-sys-1-2: System, two parcels (`len = 01`)

![Layout r20-sys-1-2](../figures/r20-sys-1-2.svg)

The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `PROBER` | `010100 (0x14)` | `1101 (0xD)` |
| `PROBEW` | `010100 (0x14)` | `1110 (0xE)` |

<a id="r20-sys-1-3"></a>
#### r20-sys-1-3: System, two parcels (`len = 01`)

![Layout r20-sys-1-3](../figures/r20-sys-1-3.svg)

The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `TRAPL` | `010100 (0x14)` | `1111 (0xF)` |

<a id="r20-sys-2"></a>
#### r20-sys-2: System, three parcels (`len = 10`)

![Layout r20-sys-2](../figures/r20-sys-2.svg)

The `reg` field is the class; the other classes take a register or a 4-bit immediate from `low`.

| Mnemonic | Opcode | `reg` |
|---|---|---|
| `MTPS` | `010100 (0x14)` | `0001 (0x1)` |
| `MFPS` | `010100 (0x14)` | `0010 (0x2)` |
| `SPL` | `010100 (0x14)` | `0011 (0x3)` |
| `TRAP` | `010100 (0x14)` | `0100 (0x4)` |
| `TLBI` | `010100 (0x14)` | `0101 (0x5)` |
| `MTASID` | `010100 (0x14)` | `0110 (0x6)` |
| `MFASID` | `010100 (0x14)` | `0111 (0x7)` |
| `MTDP` | `010100 (0x14)` | `1000 (0x8)` |
| `MFDP` | `010100 (0x14)` | `1001 (0x9)` |
| `MTDMW` | `010100 (0x14)` | `1010 (0xA)` |
| `MFCPUID` | `010100 (0x14)` | `1011 (0xB)` |
| `ICINV` | `010100 (0x14)` | `1100 (0xC)` |
| `PROBER` | `010100 (0x14)` | `1101 (0xD)` |
| `PROBEW` | `010100 (0x14)` | `1110 (0xE)` |
| `TRAPL` | `010100 (0x14)` | `1111 (0xF)` |

### Page 2

<a id="r20-page2"></a>
#### r20-page2: Page 2: a one-parcel instruction with its own opcode map

![Layout r20-page2](../figures/r20-page2.svg)

## The index of the mnemonics

For every mnemonic, the charts in which it is a sub-opcode or the whole leaf.

* <a id="mn-abs"></a>`ABS`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-adc"></a>`ADC`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-add"></a>`ADD`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-addm"></a>`ADDM`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-and"></a>`AND`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-asl"></a>`ASL`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-asr"></a>`ASR`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-bcc"></a>`BCC`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bcs"></a>`BCS`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-beq"></a>`BEQ`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bge"></a>`BGE`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bgt"></a>`BGT`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bhi"></a>`BHI`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bic"></a>`BIC`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-bicm"></a>`BICM`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-bis"></a>`BIS`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-bism"></a>`BISM`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-bit"></a>`BIT`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-bitrev"></a>`BITREV`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-ble"></a>`BLE`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-blos"></a>`BLOS`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-blt"></a>`BLT`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bmi"></a>`BMI`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bne"></a>`BNE`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bntag"></a>`BNTAG`: [r20-tag-1](#r20-tag-1), [r20-tag-2](#r20-tag-2)
* <a id="mn-bpl"></a>`BPL`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bpt"></a>`BPT`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-br"></a>`BR`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bswap"></a>`BSWAP`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-bswapl"></a>`BSWAPL`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-bswapw"></a>`BSWAPW`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-btag"></a>`BTAG`: [r20-tag-1](#r20-tag-1), [r20-tag-2](#r20-tag-2)
* <a id="mn-bvc"></a>`BVC`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-bvs"></a>`BVS`: [r20-br-0](#r20-br-0), [r20-br-1](#r20-br-1), [r20-br-2](#r20-br-2)
* <a id="mn-call"></a>`CALL`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-calli"></a>`CALLI`: [r20-xfer-0](#r20-xfer-0), [r20-xfer-1](#r20-xfer-1), [r20-xfer-1-2](#r20-xfer-1-2), [r20-xfer-1-3](#r20-xfer-1-3), [r20-xfer-1-4](#r20-xfer-1-4), [r20-xfer-2](#r20-xfer-2), [r20-xfer-2-2](#r20-xfer-2-2), [r20-xfer-2-3](#r20-xfer-2-3), [r20-xfer-2-4](#r20-xfer-2-4)
* <a id="mn-cas"></a>`CAS`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-casdb"></a>`CASDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-cbcc"></a>`CBCC`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbcs"></a>`CBCS`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbeq"></a>`CBEQ`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbge"></a>`CBGE`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbgt"></a>`CBGT`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbhi"></a>`CBHI`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cble"></a>`CBLE`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cblos"></a>`CBLOS`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cblt"></a>`CBLT`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbmi"></a>`CBMI`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbne"></a>`CBNE`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbpl"></a>`CBPL`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbvc"></a>`CBVC`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-cbvs"></a>`CBVS`: [r20-cb-1](#r20-cb-1), [r20-cb-1-2](#r20-cb-1-2), [r20-cb-2](#r20-cb-2), [r20-cb-2-2](#r20-cb-2-2), [r20-cb-2-3](#r20-cb-2-3)
* <a id="mn-clmulh"></a>`CLMULH`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-clmull"></a>`CLMULL`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-clo"></a>`CLO`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-clr"></a>`CLR`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-clz"></a>`CLZ`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-cmp"></a>`CMP`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-com"></a>`COM`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-cto"></a>`CTO`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-ctz"></a>`CTZ`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-dec"></a>`DEC`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-div"></a>`DIV`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-divu"></a>`DIVU`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-dshr"></a>`DSHR`: [r20-besc-1](#r20-besc-1), [r20-besc-2-3](#r20-besc-2-3)
* <a id="mn-extb"></a>`EXTB`: [r20-besc-1](#r20-besc-1), [r20-besc-2-3](#r20-besc-2-3)
* <a id="mn-extzb"></a>`EXTZB`: [r20-besc-1](#r20-besc-1), [r20-besc-2-3](#r20-besc-2-3)
* <a id="mn-fabs"></a>`FABS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fadd"></a>`FADD`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-fadd16"></a>`FADD16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fadd32"></a>`FADD32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fclass"></a>`FCLASS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fclass16"></a>`FCLASS16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fclass32"></a>`FCLASS32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcmp"></a>`FCMP`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-fcmp16"></a>`FCMP16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcmp32"></a>`FCMP32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcopysign"></a>`FCOPYSIGN`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtdh"></a>`FCVTDH`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtdq"></a>`FCVTDQ`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtdqu"></a>`FCVTDQU`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtds"></a>`FCVTDS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvthd"></a>`FCVTHD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvthl"></a>`FCVTHL`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvths"></a>`FCVTHS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtlh"></a>`FCVTLH`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtls"></a>`FCVTLS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtqd"></a>`FCVTQD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtqud"></a>`FCVTQUD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtsd"></a>`FCVTSD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtsh"></a>`FCVTSH`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fcvtsl"></a>`FCVTSL`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fdiv"></a>`FDIV`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fdiv16"></a>`FDIV16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fdiv32"></a>`FDIV32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fence"></a>`FENCE`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-fmadd"></a>`FMADD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmadd16"></a>`FMADD16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmadd32"></a>`FMADD32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmax"></a>`FMAX`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmin"></a>`FMIN`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmsub"></a>`FMSUB`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmsub16"></a>`FMSUB16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmsub32"></a>`FMSUB32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmul"></a>`FMUL`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-fmul16"></a>`FMUL16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fmul32"></a>`FMUL32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fneg"></a>`FNEG`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmadd"></a>`FNMADD`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmadd16"></a>`FNMADD16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmadd32"></a>`FNMADD32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmsub"></a>`FNMSUB`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmsub16"></a>`FNMSUB16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fnmsub32"></a>`FNMSUB32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-frint"></a>`FRINT`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-frinta"></a>`FRINTA`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-frintm"></a>`FRINTM`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-frintp"></a>`FRINTP`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-frintz"></a>`FRINTZ`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsflags"></a>`FSFLAGS`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsqrt"></a>`FSQRT`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsqrt16"></a>`FSQRT16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsqrt32"></a>`FSQRT32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsub"></a>`FSUB`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-fsub16"></a>`FSUB16`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-fsub32"></a>`FSUB32`: [r20-fesc-1](#r20-fesc-1), [r20-fesc-2](#r20-fesc-2)
* <a id="mn-halt"></a>`HALT`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-hint"></a>`HINT`: [r20-sysx-0](#r20-sysx-0), [r20-sysx-1](#r20-sysx-1)
* <a id="mn-icinv"></a>`ICINV`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-icinva"></a>`ICINVA`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-inc"></a>`INC`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-insb"></a>`INSB`: [r20-besc-1](#r20-besc-1), [r20-besc-2-3](#r20-besc-2-3)
* <a id="mn-isync"></a>`ISYNC`: [r20-sysx-0](#r20-sysx-0), [r20-sysx-1](#r20-sysx-1)
* <a id="mn-jmp"></a>`JMP`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-jmpi"></a>`JMPI`: [r20-xfer-0](#r20-xfer-0), [r20-xfer-1](#r20-xfer-1), [r20-xfer-1-2](#r20-xfer-1-2), [r20-xfer-1-3](#r20-xfer-1-3), [r20-xfer-1-4](#r20-xfer-1-4), [r20-xfer-2](#r20-xfer-2), [r20-xfer-2-2](#r20-xfer-2-2), [r20-xfer-2-3](#r20-xfer-2-3), [r20-xfer-2-4](#r20-xfer-2-4)
* <a id="mn-jtag"></a>`JTAG`: [r20-xfer-0](#r20-xfer-0), [r20-xfer-1](#r20-xfer-1), [r20-xfer-1-2](#r20-xfer-1-2), [r20-xfer-1-3](#r20-xfer-1-3), [r20-xfer-1-4](#r20-xfer-1-4), [r20-xfer-2](#r20-xfer-2), [r20-xfer-2-2](#r20-xfer-2-2), [r20-xfer-2-3](#r20-xfer-2-3), [r20-xfer-2-4](#r20-xfer-2-4)
* <a id="mn-lea"></a>`LEA`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-ll"></a>`LL`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-lpad"></a>`LPAD`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-max"></a>`MAX`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-maxu"></a>`MAXU`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-mcmp"></a>`MCMP`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mcpy"></a>`MCPY`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mfasid"></a>`MFASID`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mfcpuid"></a>`MFCPUID`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mfdp"></a>`MFDP`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mfps"></a>`MFPS`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mfsr"></a>`MFSR`: [r20-sysreg-0](#r20-sysreg-0), [r20-sysreg-1](#r20-sysreg-1)
* <a id="mn-min"></a>`MIN`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-minu"></a>`MINU`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-mmov"></a>`MMOV`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mod"></a>`MOD`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-modu"></a>`MODU`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-movb"></a>`MOVB`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movl"></a>`MOVL`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movq"></a>`MOVQ`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movub"></a>`MOVUB`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-movul"></a>`MOVUL`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-movuq"></a>`MOVUQ`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-movuw"></a>`MOVUW`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-movw"></a>`MOVW`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movzb"></a>`MOVZB`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movzl"></a>`MOVZL`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-movzw"></a>`MOVZW`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-mscn"></a>`MSCN`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mscnn"></a>`MSCNN`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mset"></a>`MSET`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-mtasid"></a>`MTASID`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mtdmw"></a>`MTDMW`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mtdp"></a>`MTDP`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mtps"></a>`MTPS`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-mtsr"></a>`MTSR`: [r20-sysreg-0](#r20-sysreg-0), [r20-sysreg-1](#r20-sysreg-1)
* <a id="mn-mul"></a>`MUL`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-mulh"></a>`MULH`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-mulhu"></a>`MULHU`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-mval"></a>`MVAL`: [r20-mblk-1](#r20-mblk-1), [r20-mblk-2](#r20-mblk-2)
* <a id="mn-neg"></a>`NEG`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-nop"></a>`NOP`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-pop"></a>`POP`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-popcnt"></a>`POPCNT`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-popm"></a>`POPM`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-popx"></a>`POPX`: [r20-sysx-0](#r20-sysx-0), [r20-sysx-1](#r20-sysx-1)
* <a id="mn-prober"></a>`PROBER`: [r20-sys-0](#r20-sys-0), [r20-sys-1-2](#r20-sys-1-2), [r20-sys-2](#r20-sys-2)
* <a id="mn-probew"></a>`PROBEW`: [r20-sys-0](#r20-sys-0), [r20-sys-1-2](#r20-sys-1-2), [r20-sys-2](#r20-sys-2)
* <a id="mn-push"></a>`PUSH`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-pushm"></a>`PUSHM`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-pushx"></a>`PUSHX`: [r20-sysx-0](#r20-sysx-0), [r20-sysx-1](#r20-sysx-1)
* <a id="mn-ret"></a>`RET`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-ror"></a>`ROR`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-rori"></a>`RORI`: [r20-besc-1-2](#r20-besc-1-2), [r20-besc-2-2](#r20-besc-2-2)
* <a id="mn-rori32"></a>`RORI32`: [r20-besc-1-2](#r20-besc-1-2), [r20-besc-2-2](#r20-besc-2-2)
* <a id="mn-rti"></a>`RTI`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-rtt"></a>`RTT`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-sar"></a>`SAR`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-sbc"></a>`SBC`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-sc"></a>`SC`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-set"></a>`SET`: [r20-aesc-1](#r20-aesc-1), [r20-aesc-2](#r20-aesc-2)
* <a id="mn-sev"></a>`SEV`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-shl"></a>`SHL`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-shr"></a>`SHR`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-sob"></a>`SOB`: [r20-sob-1](#r20-sob-1), [r20-sob-2](#r20-sob-2)
* <a id="mn-spl"></a>`SPL`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-sub"></a>`SUB`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-subm"></a>`SUBM`: [r20-mesc-1](#r20-mesc-1), [r20-mesc-2](#r20-mesc-2)
* <a id="mn-swap"></a>`SWAP`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-swapdb"></a>`SWAPDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-tlbi"></a>`TLBI`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-tlbia"></a>`TLBIA`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-tlbsync"></a>`TLBSYNC`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-trap"></a>`TRAP`: [r20-sys-0](#r20-sys-0), [r20-sys-1](#r20-sys-1), [r20-sys-2](#r20-sys-2)
* <a id="mn-trapl"></a>`TRAPL`: [r20-sys-0](#r20-sys-0), [r20-sys-1-3](#r20-sys-1-3), [r20-sys-2](#r20-sys-2)
* <a id="mn-tst"></a>`TST`: [r20-sop-0](#r20-sop-0), [r20-sop-1](#r20-sop-1), [r20-sop-1-2](#r20-sop-1-2), [r20-sop-1-3](#r20-sop-1-3), [r20-sop-1-4](#r20-sop-1-4), [r20-sop-2](#r20-sop-2), [r20-sop-2-2](#r20-sop-2-2), [r20-sop-2-3](#r20-sop-2-3), [r20-sop-2-4](#r20-sop-2-4)
* <a id="mn-utf8dec"></a>`UTF8DEC`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-utf8enc"></a>`UTF8ENC`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-utf8len"></a>`UTF8LEN`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-wfe"></a>`WFE`: [r20-sysn-0](#r20-sysn-0), [r20-sysn-1](#r20-sysn-1), [r20-sysn-2](#r20-sysn-2)
* <a id="mn-xadd"></a>`XADD`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xadddb"></a>`XADDDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xand"></a>`XAND`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xanddb"></a>`XANDDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmax"></a>`XMAX`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmaxdb"></a>`XMAXDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmaxu"></a>`XMAXU`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmaxudb"></a>`XMAXUDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmin"></a>`XMIN`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xmindb"></a>`XMINDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xminu"></a>`XMINU`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xminudb"></a>`XMINUDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xnorpop"></a>`XNORPOP`: [r20-besc-1](#r20-besc-1), [r20-besc-2](#r20-besc-2)
* <a id="mn-xor"></a>`XOR`: [r20-mem-0](#r20-mem-0), [r20-mem-1](#r20-mem-1), [r20-mem-1-2](#r20-mem-1-2), [r20-mem-1-3](#r20-mem-1-3), [r20-mem-1-4](#r20-mem-1-4), [r20-mem-2](#r20-mem-2), [r20-mem-2-2](#r20-mem-2-2), [r20-mem-2-3](#r20-mem-2-3), [r20-mem-2-4](#r20-mem-2-4)
* <a id="mn-xor-"></a>`XOR_`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xor-db"></a>`XOR_DB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xxor"></a>`XXOR`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)
* <a id="mn-xxordb"></a>`XXORDB`: [r20-atom-1](#r20-atom-1), [r20-atom-2](#r20-atom-2)

*Generated by `tools/mkmanual.py`; do not edit.*
