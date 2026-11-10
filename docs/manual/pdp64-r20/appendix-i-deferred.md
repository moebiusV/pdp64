# Appendix I. Deferred

[← manual index](00-index.md)

**This appendix holds what the author has decided to put off: the answer is "later", and the work waits.** The body of the manual describes the architecture as it is to be and does not mention these things. Each section is one chapter's share, headed with the chapter's number and title. A statement that moved here from the body keeps its number as a label (`**2.3.3** (moved from chapter 2)`), so that a citation of that number still leads to a place. What is proposed but not decided is in [appendix H](appendix-h-proposed.md); the questions the architecture must still answer are in [appendix J](appendix-j-open.md).

<!-- parts:deferred -->
## I.3 Chapter 3: Graphics: the terminal and its devices

The author deferred (errata 78, 2026-11-03) a native video device, a native sound path and a bit-block-transfer assist of the pdp64's own, and then dropped the register model on which they were defined (errata 95, 2026-11-09: "virtio across the board"). The standard video and audio devices are virtio-gpu (2D) and virtio-snd (errata 79). The decisions below stand as properties of the deferred devices: the 48-bit pixel (errata 73) and the 48-bit sound sample (errata 74). What to do with the devices is an open item (J.3.1). The statements keep their numbers and tags; wording that assumes the abolished register model is the wording of the time.

### 3.8 The pdp64 terminal: the native devices (moved from chapter 3)

**3.8.2** (moved from chapter 3) A native video device is the Commodore 64's video chip (the VIC-II) extended: a framebuffer in the address space with 48-bit pixels, scanned out through a line buffer. A pixel is RGBA with 12 bits per channel (errata 73, the author's decision of 2026-10-24); the pixel format is what is decided. The register formats and the other pixel formats are unspecified. *(D)*

**3.8.3** (moved from chapter 3) A native sound path is the C64's sound chip (the SID) extended: voices with filters, and also a general sound path that is not limited to the SID's voices; audio samples are 48 bits (errata 74, the author's decision of 2026-10-24); the sample width is what is decided. The register formats and the layout of a 48-bit sample are unspecified. *(D)*

**3.8.9** (moved from chapter 3) Every register of the native video device that takes effect at a frame boundary is shadowed: one write to its `ARM` register latches them all together at the start of the next vertical blank, and a status bit says whether the arm was taken in this frame or missed it. A sticky underrun bit and an underrun counter report a scan-out that ran dry. The vertical-blank interrupt occurs at a fixed line of the frame, whose number a register holds. The sound path's audio clock relation (3.12.4) is part of the same mode setting. *(D)* (Errata 71.)

*Commentary (moved from chapter 3).* **Chain.** The PDP-11 reached its terminal through a serial register pair (3.1). The Blit (1980s) put the bitmap in the address space and had a framebuffer in the address space and did the bit-block-transfer in software ("no pixel-moving hardware", Pike, Locanthi and Reiser, 1985); hardware blitters came later, on the Amiga and other machines of the 1980s (general knowledge, *unverified*). The Blit received downloaded code, characters and editing messages over a serial line and drew every pixel itself. The C64 (1982) put video and sound in chips whose registers a program pokes and whose screen memory the video chip reads by itself. No source read says that it preceded the X11 protocol; the lineage the sources confirm runs from the Blit's `mux` through 8½ to `rio` (`docs/kernel-pain-points.md`, section 14I). The pdp64 needs no display protocol between host and terminal, because the display is a set of devices on the bus; the nearest thing is the descriptor ring of chapter 5. The native design takes the framebuffer and the operation from the Blit, adds a hardware blitter, and takes the video and sound chips from the C64. Plan 9 moved its window system into files (`/dev/bitblt`, later `/dev/draw`), a stream of small commands written to a device; that has the shape of a descriptor-ring entry (the comparison is an inference, not a source's statement).

**Trade-offs.** The blitter covers scrolling a terminal, moving a window, drawing a glyph, filling a rectangle and exclusive-oring a cursor; it does no three-dimensional graphics. `MCPY` is no substitute: it is one-dimensional and occupies the processor, where a blit has a stride and a raster operation and runs concurrently. The 48-bit pixel (four 12-bit channels, errata 73) probably exceeds what a display connector carries (unverified), so the display device converts to the connector's depth on the way out; likewise the 48-bit audio sample exceeds what a converter takes, so the sound device keeps the precision for mixing and filtering and reduces it at the output.

**Improvements.** The C64's video and sound registers were scattered and irregular; the pdp64 versions use the uniform register face, so one driver skeleton serves them (errata 95 removed that face for the standard devices, 3.9). **Benefits.** The blitter is about 1,500 lookup tables and a line buffer, nearly all address arithmetic (`docs/pdp64-fpga-plan.md`, line 316). **Modern comparables.** Display controllers in embedded systems commonly pair a scan-out engine with a blitter, and sound chips sit behind an I2S interface (general knowledge, *unverified*). **Impact.** *Kernel:* a framebuffer, a sound and a blit driver are each a mapped page and a few register writes; the uncached framebuffer needs no cache maintenance. *Compiler:* none. *Hardware:* a scan-out engine, a line buffer, an address-arithmetic unit for the blitter and a mixer for the sound device, each independent of the processor.

### 3.11 The stub: the C64 and Blit documentation (moved from chapter 3)

**3.11.1** (moved from chapter 3) The register-level definitions of the terminal's video, sound and blitter devices (register names, offsets, bit fields, the 48-bit pixel and sample formats, the sprite, raster-interrupt and voice models inherited from the C64, and the bit-block-transfer operations and windowing model inherited from the Blit) are a stub: only the blitter registers listed in 3.8.4 are listed, and that list is the assistant's sketch, which the author has not discussed. The author's earlier device chat decided much of the rest (register conventions, the 8502 island, the display rules); it is extracted in `docs/c64-devices-from-chat.md` and awaits adoption (`decisions-pending.md` E1 to E11). *(S)*

**3.11.2** (moved from chapter 3) What is fixed: the devices exist, they follow the eight-register convention in the terminal's slots (errata 95 later withdrew that convention for the standard devices), and the interrupt, `FENCE` and uncached-framebuffer rules of section 3.11 apply. *(S)*

*Commentary.* This section is the placeholder for the C64- and Blit-derived specification. The Blit side can draw on the papers recorded in section 14I of `docs/kernel-pain-points.md`: the four primitives `bitblt`, `texture`, `segment` and `point`, the `Bitmap`, `Rectangle`, `Point` and `Texture` types, half-open rectangles, and overlapping windows with obscured parts kept off screen. **Impact.** *Kernel:* none until defined. *Compiler:* none. *Hardware:* the block RAM budget (3.11.3) is settled before the video device is built.

### 3.17 Scanout: what the native video device decides (moved from chapter 3)

**What the repository already decides.** The video device (3.8) shadows every register that takes effect at a frame boundary: one write to `ARM` latches them all at the start of the next vertical blank, a status bit says whether the arm was taken or missed, a sticky underrun bit reports a scan-out that ran dry, and the vertical-blank interrupt occurs at a fixed line (3.8.9, errata 71, from `kernel-pain-points.md`). A base address in that register set therefore flips at the blank without the program arranging anything. The author's device chat of 2026-08 said the same ("multi-register updates are atomic at a named raster line or vblank", `docs/c64-devices-from-chat.md` section 2) and, for the eight-way machine, the assistant's proposal that the author accepted: "Flip on vsync unconditionally with an overrun interrupt instead of a barrier" (`c64stuff.txt` line 5647; the capitalisation is mine). No text decides anything beyond one shadowed register set: independent layers, damage, variable rate, fences, or a default that needs no program setup.

**3.17.2** (moved from chapter 3) The mechanism that is decided is the shadowed registers and the one `ARM` write of 3.8.9; everything else in this section is a candidate. *(D)*

## I.6 Chapter 6: The kernel: modes, exceptions and memory management

**6.9.2** (moved from chapter 6, the direct-mapping windows) The author decided that the format of the direct-mapping windows is deferred (errata 44, from the principle of errata 42): `DMW0` and `DMW1` (system registers 4 and 5) stay stored-only registers in System v1 (errata 36), and their format is defined when a kernel needs a window, not before. The body keeps the decided half: the registers are stored and have no effect on translation. What follows is the sketch that the text carried, and it is not decided.

A **direct-mapping window** (DMW: a range of virtual addresses that the hardware maps to a range of physical addresses by one addition, with no page table and no translation-buffer entry) lets the kernel reach all of physical memory (to write a page it has just allocated, a DMA descriptor or a page table) and the memory of devices, where walking tables is slow and uses buffer entries. The instruction-set text sketches two windows, `DMW0` and `DMW1`, each with a virtual base, a size and a memory type, kernel only, translating as `PA = VA − VirtualBase + PhysicalBase`. It gives three reasons: the kernel stops taking translation misses on its own text and data; physical memory is reachable without mapping it; and early boot becomes simple (`docs/pdp64-isa.md` section 8.3). The idea is LoongArch's `DMW` registers, a tidier descendant of MIPS's fixed `KSEG0` region (whose behaviour on the real machine is *unverified* here). The author's remark (2026-11-09) was "good thing we already had dmw in the design!": the kernel need not walk anything to reach petabytes of physical memory or a deep table.

The architecture document says that the machine comes up with `DMW0` covering physical memory. Errata 44 supersedes that sentence for System v1: `MMUCTL` is zero at reset and every address is physical.

*Lineage (moved from 6.9).* **Between:** MIPS had the fixed `KSEG0` region (*unverified*); LoongArch added the `DMW` registers (the author's referent). **pdp64:** MIPS's fixed region generalised to two windows; a kernel that wants more regions than two windows maps them with large pages. The cost is one comparator pair and one adder per window.

*Impact (moved from 6.9).* The kernel stops taking translation misses on its own text and data, physical memory and a petabyte-scale device are reachable with no page table, and the first page table is easy to build, because the windows reach the memory it is built in. *Kernel:* physical memory is reachable by addition; the windows serve the copy of a page, a DMA buffer, a page-table page and early boot. *Hardware:* one comparator pair and one adder per window.

The wide page-table entry (entry J.6.2) and the fetch after the write that enables translation (entry J.6.6) are two questions that a window would answer, and the deferral therefore bears on them.

## I.9 Chapter 9: The instruction set

**9.20 commentary** (moved from chapter 9) The direct-mapping windows that LoongArch uses to avoid translation-buffer misses on kernel text are deferred: `DMW0` and `DMW1` are stored and have no effect on translation, and their format is defined when a kernel needs a window (6.9.2, and the deferred matter of chapter 6 in appendix I).

## I.A Appendix A: Improvements beyond the PDP-11

**A.4.2** (moved from appendix A) Return-address authentication is deferred (errata 84, item 7). *(D)*

**A.5.2** (moved from appendix A) Bounds for the valid-pointer tag are deferred (errata 86, study item 3): the tag per register and per 8-byte word is kept and the bounds of a capability are not part of it.

### A.8 Two-byte forms of the user-memory guard instructions (moved from appendix A)

**A.8.1** `STUA` and `CLUA` could have one-parcel page-2 forms, saving four bytes per user-copy routine.

*Commentary.* **Trade-offs.** It uses two of the 19 reserved page-2 slots, which is not worth it until a kernel exists to count the copy routines. **Benefits.** Smaller and faster user copies. **Verdict.** Hold the slots and decide when the kernel exists. **Impact.** *Kernel:* Each user copy routine is four bytes smaller. *Compiler:* None. *Hardware:* Two reserved page-2 slots used.
<!-- /parts:deferred -->
