# The C64 devices as the author's chats decided them

[← pdp64 index](../README.md)

**Read it in its time:** the chat predates the 39-bit address space and the 64-bit ISA; the machine was then a PDP-11 emulation with very conservative extensions (the author, 2026-10-24). Its decisions answer that machine's questions.

**Status: chat-era material, extracted 2026-10-24 from `c64stuff.txt` (an export of the author's chats). Nothing here is decided for the repository.** It is the record of what the author said and accepted in the chat that produced the "11/64" device specification (chat of 2026-08-29, "Retro CPU mashup with C64 graphics and modern I/O", `c64stuff.txt` lines 5597-6028). That chat's seven documents (`pdp-11-64-architecture.md`, `-addendum-realtime`, `-rev2` to `-rev7`) never entered this repository, which was built from the later chat (2026-08-30, ISA r8 to r20; `docs/orig/`). Until now `README.md`, `handoff.md` and `manual/03-graphics.md` section 3.2 (now 3.11) called the register-level C64 devices "a stub awaiting the author's documents"; this file is the part of those documents that survives in the chat text. Where it disagrees with the manual, the disagreement is listed in `decisions-pending.md` Part E and nothing here overrides the manual.

Two things are kept apart throughout:

* **The author said** (quoted, with the line in `c64stuff.txt`).
* **Proposed by the assistant and accepted** (the author asked for the specification to be updated, or built on it, without objecting). Weaker than the first. Marked *(accepted)*.

The tables of register offsets, the opcode lists and the numeric budgets of revisions 1 to 7 are **not** in the chat text (only the assistant's summaries are), so they are not reconstructed here.

Contents

1. [What the author asked for](#1-what-the-author-asked-for)
2. [Rules the author stated](#2-rules-the-author-stated)
3. [Accepted design, by revision](#3-accepted-design-by-revision)
4. [The 8502 compatibility island](#4-the-8502-compatibility-island)
5. [The display](#5-the-display)
6. [The c64x terminal chat (2026-06-18)](#6-the-c64x-terminal-chat-2026-06-18)
7. [Later changes by the ISA chat](#7-later-changes-by-the-isa-chat)

---

## 1. What the author asked for

* **The brief** (line 5603): "design a mashup; pdp-11 and m6502 with all the c64 graphics and audio goodies. use pdp-11 as the base, fold in the good parts of c64. assume mmu and fp units, and our earlier design for an ethernet card with onboard tcp/ip stack that uses 8 memory addresses as registers (less if needed) ... modern fpga so insane high clock specs, modern usb keyboard, mouse, and nvme hard drive. usb hard drive too ... could we revamp the blit to be c64 adjacent. and that sid chip, my my."
* **Realtime** (line 5627): "what could be done to fold in qnx/qunix design decisions to the v7 source so there is deterministic and reliable realtime guarantees? assume v7 source code as the base, then minimally intrusive design changes."
* **What "mashup" means** (line 5704): "not necessarily two chips operating simultaneously, but taking the best isa/architecture and improving it with the good stuff of the other one." The 6502 was later put back as an optional island (section 4).
* **Endianness** (line 5652): "we go full little endian, none of this middle endian stuff, that gets fixed right now." (This is the author's decision; `CHANGES-SINCE-R20.md` section 2.2 records little-endian as a gap-fill, which it was not. See errata 72.)
* **Clock** (line 5652): "200-300MHz is fine; still much faster than pdp-11 no?"
* **Floating point** (line 5652): "assume a new refreshed redesigned fp unit, probably compatible with modern ieee floating point representation."
* **Devices on a bus with their own memory** (line 5729): "totally ok with different functions living on different devices with memory space, connected by dma bus transfers."
* **Display** (line 5936): "i prefer to drive the hdmi at 50 fps when running legacy code, but in general we should be able to drive the hdmi however we want; not limited to 16 colors, not limited in font size or rows and columns. etc"
* **Island access** (line 5884): "if we're implementing the 8502 in fpga we can make all registers readable from outside. writeable too. just hold the rdy pin."
* **PAL/NTSC** (line 5892): "since the soc will have hdmi, pal/ntsc isn't too relevant except for backwards compat."

## 2. Rules the author stated

| Rule | Where | Source |
|---|---|---|
| Compatibility is by conversion instructions, never by mode bits (kills `PSX.LE`, `PSX.IEEE`, `FPS.FD/FL/FT`). | stated by the assistant, then used by the author as a principle | line 5668 (softened later: errata 42) |
| One quantity per register, wide enough to hold it. | accepted | line 5813 |
| Every register readable; nothing clears on read. | accepted | line 5813 |
| Multi-register updates are atomic at a named raster line or vblank (shadow and commit). | accepted | line 5813 |
| Compatibility is always an alias or a descriptor field, never a global mode. | accepted | line 5813 |
| Anything with more than a few instances gets an index and a window, never a flat array. | accepted | line 6010 |
| Write shape matches read shape; one source of truth for parser and spec (the c64x 9p interface). | author | lines in section 6 |

## 3. Accepted design, by revision

Each item is the assistant's statement at the quoted line, which the author then built on.

**Revision 1 (line 5605-5616).**
* The C64 I/O block `$D000-$DFFF` sits inside the PDP-11 virtual page `$C000-$DFFF` (APR6). Pointing `PAR6` at the device page lets a program see VIC at `$D000`, colour RAM at `$D800`, CIA at `$DC00` at the literal addresses; the lower half of the page holds the extended register bank. The C64's banking poke is one `MOV` to a PAR, per process and MMU-protected.
* Prefix word `0076xx` (the dead CIS slot) carries size, two extra mode bits per operand and an aux field: 32- and 64-bit forms and eight new modes without changing an existing encoding. (Superseded by the 64-bit ISA, section 7.)
* Zero page becomes a 64 KB single-cycle tightly coupled memory.
* The blitter's primitive is a three-operand `draw` (compositing), not `bitblt`; the image descriptor is shaped like a Plan 9 `Memimage`; layers are display-list entries resolved at scanout, so sprites and windows are one concept.
* **KE64**, the network card, in eight registers: programmed I/O through `NDAT` (about thirty lines of assembly for a TCP client; used for netboot), or descriptor rings close to a DEQNA. Four registers is the floor. Per-core windows in the eight-core configuration.

**Revision 2 (lines 5652-5701).**
* IEEE-compatible FP unit; unprefixed `17xxxx` stays FP11, prefixed is IEEE; `AC0-AC5` are `F0-F5` holding raw bits.
* Map sets (four shadow copies of the page-register files, selected by one store to `MAPSEL`) and a common region (`MMCOM`), from the C128's 8722.

**Revision 3 (lines 5704-5727).**
* All device registers fit in 8 KB; every large structure is memory reached through a base register or index window.
* About 340 KB on-chip per core; roughly 1 MB for eight cores.
* 65 new instructions, none changing an existing encoding.
* The bus: 18 to 40 address bits, 16 to 64 data bits, bursts, about 2 GB/s. `DATIP` then `DATO` stays a locked read-modify-write; device-supplied vectors stay. DMA priority moves from slot position to a register. The display is a bus master and steals no cycles; badline emulation is an option.

**Revision 4 (lines 5772-5789).**
* Three memory classes: (A) private local memory with no DMA for state nobody else reads (SID, NIC FIFOs, HID); (B) shared DDR with pointer passing for inherently shared structures (framebuffer, text plane, buffer cache); (C) peer-to-peer DMA that bypasses DDR (KE64 to text plane, KE64 to blitter, storage to framebuffer).
* The framebuffer has **no** DMA channel; asking for one is a documented design error.
* 2 KB maximum burst. Strict priority between classes, round-robin only within a class (an erratum to revision 1: with round-robin the worst wait is (N-1) x burst).
* DMA bandwidth is a schedulable resource in the eight-way machine: channels bound to partitions, per-frame credit counters, mandatory IOMMU.
* REU window at `$DF00`: the 8726's six registers widened to 40-bit addresses.

**Revision 5 (lines 5805-5819).** The register conventions of section 2, the bitmap `layout` field in the image descriptor (so the compositor swizzles in hardware), and three deliberately preserved C64 warts: badlines, the 6581 ADSR bug, the volume-click channel.

**Revision 6 (lines 5894-5931).**
* Alias rule: a write to a C64 alias always behaves as `SHADOWEN = 0` and updates both banks, so a later `COMMIT` is idempotent.
* Word access to a byte-only alias traps (vector 4).
* A 40-bit register is three words in a 16-bit I/O page; the write to the third word delivers the whole value.
* Colour RAM is real 1000 x 4-bit storage, one-way patched into the cell foreground.
* `SPRX` signed 16-bit against the VIC's 9-bit wrap: a `WRAP9` descriptor flag. `C64PTR` makes the sprite pointer an indirection read each frame; there is no aliasing with `screen+$03F8`.
* `TEXTMODE` enumerates the display modes including the illegal ones; light pen added; 8.8 fixed-point scroll.
* Nine new vectors with levels and formats; display at BR6.
* `format` orthogonal to `layout` (indexed 8/4/1, RGB565, RGBA).

**Revision 7 (lines 6002-6024).**
* `LIVESEL`/`LIVEDAT` (an index and a data port) replace the `+$0800` live-window offset, which collided with other banks.
* `VSEL` plus a window for the 32-voice file.
* `SHADOWEN` is twelve bits, one per commit group.
* The island runs on `VICPROF` PHI2 (section 4).
* Pointer reads snapshot on `+0`, writes deliver on the highest word.
* `CPUERR` (`777766`) gains a wrong-width cause bit; vector 4 is kept.
* `ROWS`, `COLS`, `CELLW`, `CELLH` are 16-bit registers; `FRAMEPOL` defaults to mode-match (a PAL profile drives 1080p50).

**Realtime addendum (lines 5641-5647), accepted.** The 100x clock makes everything small but nothing bounded. The retrofit to V7 (about 800 lines added, under 100 changed, two new files, every V7 binary still runs): priority inheritance on `ILOCK` and `B_BUSY` (the highest-value change); declared preemption points; `SLOCK` to opt out of swapping (no demand paging is an asset); constant-time context switch. For the eight-partition machine: flip on vsync unconditionally with an overrun interrupt instead of a barrier; a store to a closed gate traps rather than stalls.

## 4. The 8502 compatibility island

Accepted at lines 5830-5840 and 5894-5923 (the idea came from a document the author asked the assistant to evaluate), and refined at 5976-6016.

* Held in reset at power-on. By default the PDP-11 drives every VIC/SID/CIA register itself.
* A soft 8502 (not a socketed 6510), with `IPORT` for the `$00/$01` processor port. In fabric, A, X, Y, S, P and PC are readable at any cycle; `RDY` hold is needed only to guarantee an instruction boundary before a write. Examine, deposit, single-step and hardware breakpoints (the author: "just hold the rdy pin").
* Two windows onto one register file: the island sees 1982, the host sees the extended registers.
* When `ICSR.RUN` is set the core runs on the `VICPROF` PHI2 (0.985248 or 1.022727 MHz), including badline and sprite-fetch steals; `ICYC` counts PHI2 cycles; `ICSR.FAST` is an option that breaks cycle exactness.
* `IOWN`, a 12-bit mask, defaults to the voice, filter and output groups while the island runs; a host write to an owned group traps unless `RDY` is held.
* Doorbell at vector 314. Commodore ROMs are not shipped. `/dev/vic` and `/dev/sid`, with an `ioctl` to release the island.
* The register is called `ICSR` (the name `HCR` belongs to a different design).

## 5. The display

* Not limited to 16 colours, 40 x 25, an 8 x 8 cell or 320 x 200; no obligation to 50 or 60 Hz (author, line 5936).
* The cell is a 32-bit foreground and a 32-bit background (the c64x model, which makes the 9p path zero-translation); indexed and 565 formats exist beside RGBA.
* The raster contract is virtual: the VIC beam is a counter, not the HDMI beam, so PAL code written for 312 lines of 63 cycles runs on a 1080p panel. `FRAMEPOL` chooses between 1080p50 (exact) and 60 Hz with a repeated frame in six. The author prefers 50 Hz when running legacy code.
* **The 48-bit pixel of `manual/` appendix I, 3.8.2 (3.1.2 before errata 105, 3.10.2 between errata 105 and 114, moved out of the chapter by errata 121) does not appear in these chats.** It is a later decision of the author's: RGBA, 12 bits per channel (errata 73). The 32-bit cell above is the earlier design.

## 6. The c64x terminal chat (2026-06-18)

Lines 4816-5260. The author's own terminal, "like the old C64": each cell individually addressable, peek and poke instead of escape sequences.

* Per cell: a 32-bit foreground colour, a 32-bit background colour, a UTF-8 character, and about 8 bits of attributes (line 4822 onward); "the number of cells take up so little memory, the 64 bits devoted to color is trivial."
* A newLISP-style cell is a pointer to its data; a fixed array of cells; the 9p tree is "JUST a representation of underlying newlisp reality". A "more data" area follows the glyph data, with a dense list of indexes (-1 for none).
* Sparse, not dense; write shape matches read shape; JSON and a binary record interface; the record specification ships as a file in the tree, one source of truth for parser and spec.
* Existing ncurses and tty applications must work with no relinking; thin shims are acceptable; native applications use the terminal fully.
* The Multics chat of 2026-06-19 (lines 5261-5308) adds: devices as memory-mapped regions, peek and poke, a flat 64-bit address space, `mmap` as the primary I/O.

## 7. Later changes by the ISA chat

The later chat (lines 6029-7140) changed the base the above sits on. Recorded so the two are not mixed up.

| Revision-1 to -7 design | Later |
|---|---|
| 16-bit PDP-11 with the `0076xx` prefix | a 64-bit ISA with 16-bit parcels (author: "skip 32 bit, straight to 64bit") |
| Map sets and `MMCOM` | ASID and a global bit (assistant's translation, line 6124) |
| 64 KB TCM, `DPR` | `DP` register and direct-page mode |
| Three-operand `draw` blitter | `BLT64`, a bitblt engine with raster ops (r13, line 6546; the author did not discuss it) |
| Zynq UltraScale+, devices first with an emulated CPU | DE10-Nano first, CPU first (the ISA chat's FPGA plan) |
| 200-300 MHz | 50-80 MHz on the Cyclone V, 180-250 MHz on UltraScale+ (the later chat calls the 250 MHz figure optimistic); settled: the target is 200-300 MHz and the estimates stay as estimates (errata 99) |

## 8. A historical link between Commodore and DEC (found 2026-11-07)

**Prediction (author).** There is a link between the C64's makers and DEC.

**Confirmation.** Ira Velinsky, "Commodore's amazing industrial designer" (https://www.commodore.ca/commodore-history/ira-velinsky-commodores-amazing-industrial-designer/, read 2026-11-07). The article says that he "sharpened his teeth at Digital Equipment Corporation", where he "challenged the company's beige box status quo", and that "His work at DEC caught the attention of Commodore's upper management". It credits him with the DEC Rainbow 100 (1981) and, at Commodore, with a modified C64 "breadbox" case, the CBM-II, the PET SK series, the Ultimax, an early 1541 case, the Commodore 116, the Plus/4, the 1531 Datassette and the Commodore 900 (a UNIX workstation). He followed Jack Tramiel to Atari in 1984 and died in late 2001. The article gives no years for his time at DEC and does not credit him with the PET, the VIC-20 or the C128. It does not say how his DEC work reached Commodore's management, and it claims no influence of DEC designs on Commodore's.

**Hypothesis (author) (P).** Personnel passed between DEC and Commodore, and the design similarities between the C64 and the PDP-11 are too many to be chance. The same designer making machines for both companies is the common link.

**Evidence still wanted.**
* The author's list of the C64/PDP-11 similarities, in his words, each to be marked as sourced or as his observation. The repository so far records resemblances that are the author's own design choices (the C64 I/O block inside the PDP-11 APR6 page, the 8502 island, `DP` as the descendant of 6502 zero page) and PDP-11 features the pdp64 inherits (autoincrement, devices as memory locations, no I/O instructions); neither kind is evidence of a historical link by itself.
* Further names, in either direction, of people who moved between the two companies.

### 8.1 Candidate similarities between the C64 and the PDP-11, for the author's annotation

Compiled 2026-11-07 from the repository's own documents. Each is a candidate, not a finding: the *Source* column says where the repository records it, and the *Kind* column says whether it is a resemblance the repository records as already existing (**shared**), a feature the pdp64 takes from one side (**inherited**) or something the author chose to join (**chosen**). The author marks each *real* or *not*; none enters the manual until he does.

| # | Candidate | Kind | Source |
|---|---|---|---|
| 1 | Devices are a few memory locations and a driver is an ordinary program; no I/O instructions | shared (PDP-11 by design; the C64's devices are memory-mapped registers too) | manual 1.2.6; Multics chat, `c64stuff.txt` lines 5261-5308 ("devices as memory-mapped regions, peek and poke") |
| 2 | Peek and poke as the programmer's model of the machine | shared (C64 BASIC; PDP-11 console deposit and examine) | `c64stuff.txt` lines 4816-5260 (the c64x terminal "like the old C64"), lines 5261-5308 |
| 3 | A small page of memory near the base of the address space that is cheap to reach (6502 zero page; PDP-11 short addressing of low memory and the I/O page) | candidate | r20 ISA text, section on `DP` (line 206) and the 6502 passage (line 1182) |
| 4 | The C64 I/O block `$D000-$DFFF` falls inside the PDP-11 virtual page `$C000-$DFFF` (APR6) | chosen | `docs/c64-devices-from-chat.md`, section 3 (revision 1) |
| 5 | The program counter and stack pointer as ordinary registers, a small register file, autoincrement and autodecrement for `*p++` and `*--p` | inherited from the PDP-11; the 6502's indexed and indirect modes serve the same loops | manual 1.2.5 |
| 6 | The 6502's decode as a PLA with no microcode ROM, and the T-11's small logic budget, as the model for a minimal implementation | shared (small-gate-count design of the 1970s) | r20 ISA text, lines 1236 and 1367 |
| 7 | One designer, Velinsky, for DEC and for Commodore | **sourced** (section 8) | the article |

Rows 1 to 6 are candidates the author has not yet confirmed; the author's own list, in his words, replaces or extends them.
