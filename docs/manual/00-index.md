# The pdp64 manuals

[← pdp64 index](../../README.md)

**The pdp64 is a family of three CPUs, and each has its own manual, because they are different CPUs.** They share the architecture (the registers' roles, the memory model, the exception mechanism, the page tables, the devices, the bus, the calling convention) and they differ in how an instruction is encoded and in what the register file holds.

| CPU | Registers | Encoding | Instructions | Manual |
|---|---|---|---|---|
| **pdp64/r20** | 16 (`r0` to `r15`) | the original: parcel 0 is `len opcode reg low`, instructions of 2, 4 or 6 bytes | the 106 instruction entries of the original set (270 words with the aliases) | [the pdp64/r20 manual](pdp64-r20/00-index.md) |
| **pdp64/16** | 16 (`r0` to `r15`) | prefix-coded: the length and the instruction are decoded together from a prefix of 3 to 16 bits of the first parcel | the original set and 70 more words (the fused pairs, the selects, the checked arithmetic, `trapcc`, the deferred and user-qualified moves, AES and SHA) | [the pdp64/16 manual](pdp64-16/00-index.md) |
| **pdp64/32** | 32 (`r0` to `r31`) | prefix-coded, with 5-bit register fields in the one-parcel forms | the same instructions as pdp64/16 | [the pdp64/32 manual](pdp64-32/00-index.md) |

Each manual is complete: the chapters, the instruction entries with the bit-layout chart of every opcode, the reference tables and the appendices. The text common to the three is written once, in [`docs/manual-src/`](../manual-src/README.md); the manuals are generated from it by `tools/mkmanual.py` and checked by `tools/check-all.sh`. Each manual is also a book, `book/pdp64-r20.pdf`, `book/pdp64-16.pdf` and `book/pdp64-32.pdf`.
