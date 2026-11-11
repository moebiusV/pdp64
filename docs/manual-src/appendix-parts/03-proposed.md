### 3.8 The pdp64 terminal: the blitter (moved from chapter 3)

**3.8.2** (the graphics core, moved from chapter 3; the number is that of the statement in the chapter before the move, and is not the 3.8.2 that this fragment cites for the pixel format) One core is dedicated to the graphics device, the Blit's model of a terminal with a processor of its own (errata 76, the author's recommendation; the core classes are in chapter 7, 7.11). *(P)* Decided on 2026-11-04 and shrunk by the decision of 2026-11-10 (errata 132): what remains of dedicated roles is open ([J.7.5](appendix-j-open.md#j75)).

**3.8.4** (moved from chapter 3) The blitter, the Blit's bit-block-transfer operation as a device, copies and combines rectangles of pixels with raster operations: registers for the source and destination base addresses, the strides, the width and height, a raster operation (the sixteen binary operations of source against destination and the common ternary ones), a mask or transparent colour, and a control register with direction, go, busy and interrupt on done. The device chat chose a three-operand `draw` instead (`decisions-pending.md` E3). The register list is the assistant's sketch from the ISA chat; the author has not discussed it. *(P)*

**3.8.5** (moved from chapter 3) Each of the three is a device in a slot: it is enumerated by the bus, mapped into its own 4 KB page, and found by its identification register like any other (chapters 2 and 5). The device chat put the C64 devices in one 8 KB window per process (`decisions-pending.md` E5). The slot and the page rest on the eight-register convention that errata 95 withdrew for the standard devices. *(P)*

**3.8.6** (moved from chapter 3) The framebuffer stays plain memory, so that software can draw without the blitter; the blitter is an assist that can be bypassed, not the only way to draw (the Blit authors' advice in 1985 was "transparent, so it can be bypassed"). *(P)*

**3.8.7** (moved from chapter 3) Four raster operations are required of the blitter: store, OR, clear and exclusive-OR (these four sufficed on the Blit, and exclusive-OR dominated its use); the other twelve binary operations and the ternary ones are optional. The requirement is the assistant's, from the Blit papers. *(P)*

### 3.9 The terminal as the author describes it (moved from chapter 3)

The terminal and its glyph map are decided in principle (3.9.1 in the body). What follows is the assistant's elaboration of the cell and the slot.

**What the author's earlier terminal chat adds** (2026-06-18, `docs/c64-devices-from-chat.md` section 6; a separate project, not a pdp64 decision): a cell holds a 32-bit foreground colour, a 32-bit background colour, a UTF-8 character and about eight bits of attributes (bold, italic, underline, blink); "the number of cells take up so little memory, the 64 bits devoted to color is trivial"; "each cell holds its actual data, not a reference to the data"; sprites are a separate plane that composites over the cells; existing tty programs must run through a shim and native programs use the terminal fully, "peek and poke is the internal interface". That design fits the cell array of the figure below and differs from the author's new words in one place: **the chat-era cell holds the character code itself, while the glyph map of the new words implies a slot** (3.14, pair 3, candidate (a) against (b)).

![A cell array and a glyph slot table](figures/gfx-cells-glyphs.svg)


As an arithmetic example, with the chat-era cell (about 13 bytes: 4 + 4 + 4 for a character + 1 for attributes) and a 1920 by 1080 screen of 8 by 16 pixel cells, there are 240 columns and 67 rows, 16,080 cells and about 209 KB of cells; with slots of 16 by 32 coverage bytes (512 bytes) and 4,096 slots, the glyph map is 2 MB. Both are small against a 12.4 MB frame at 48 bits (3.11.2), which is the author's observation of 2026-06-18: the cells are small, and text is cheap to store. These are examples, not decisions.

### 3.10 A peek/poke program for the terminal (moved from chapter 3)

This is what the author's description would let a program do. **No register of the terminal is specified** (3.11), so the capitalised names are placeholders and any number is an example.

```
# placeholders: SCREEN is the base of the cell array, COLS its width in cells,
#               GLYPHS the base of the glyph map, GLYPH_SIZE the size of one slot

put_glyph(row, col, slot, fg, bg):                 # one cell: four stores
    cell = SCREEN + (row * COLS + col) * CELL_SIZE
    poke32(cell + GLYPH, slot)                     # which glyph (or the character code, 3.9)
    poke32(cell + FG, fg)                          # colours, modern depth: the pixel format of 3.8.2
    poke32(cell + BG, bg)
    poke8 (cell + ATTR, 0)

define_glyph(slot, font, codepoint):               # a glyph the program has just thought of
    bitmap = ttf_rasterise(font, codepoint, CELL_W, CELL_H)   # software: the TrueType engine
    copy(GLYPHS + slot * GLYPH_SIZE, bitmap, GLYPH_SIZE)      # an ordinary memory copy

put_glyph(0, 0, slot_of('A'), RED, BLACK)          # an A, red on black, top left
define_glyph(200, my_font, 0x03BB)                 # a lambda goes into slot 200
put_glyph(0, 1, 200, WHITE, BLACK)                 # and is used by naming slot 200
```

Graphics beside text, in the C64 manner, are another array and one more register set:

```
# the graphics plane: a framebuffer of FB_W by FB_H pixels; this sketch uses 32-bit pixels, as the standard device does
# (the 48-bit pixel of 3.8.2 would be 6 bytes: a different multiplier and three 16-bit stores)
put_pixel(x, y, colour):
    poke32(FB_BASE + y * FB_STRIDE + x * 4, colour)         # FB_STRIDE counts bytes, as in 3.5
# sprites, if the design has them (3.9.4: not decided):
poke(SPRITE_N + X, 100); poke(SPRITE_N + Y, 80); poke(SPRITE_N + SHAPE, shape_slot)
```

Each line is one store, so the program is as small as the C64's was. Everything is memory, so `memcpy` fills a glyph slot as it fills any buffer. Compared with the list of 3.14 there is no mode setting, no format conversion, no flush (the memory type of 3.11.1 takes its place), no atlas to pack, no shader and no command buffer. The terminal does no three-dimensional graphics; for that the standard device, virtio-gpu, remains (3.12, 3.13).

### 3.12 How the terminal drives HDMI and the other ports (moved from chapter 3)

**3.12.2** (moved from chapter 3) The video device's output side is therefore a pixel stream with horizontal and vertical sync, a clock and a data-enable, which is what every such transmitter accepts; the device's registers set the mode (width, height, blanking, pixel clock, the pixel format), the base address of the framebuffer and the display on and off. *(P)*

(3.10.2, that other standard outputs are the same shape, is in the body. That each port is one more slot or one more output of the video device is the assistant's.)

**3.12.4** (moved from chapter 3) The sound device's output is likewise a standard digital audio stream (I2S or the HDMI audio channel) into a converter or the transmitter. The processor never sees the HDMI packets, but whoever sets the mode must also program the audio clock relation: the transmitter needs N (and CTS, or a hardware CTS calculation) for each pixel clock and sample rate (an ADV7511 driver computes both; general knowledge, *unverified*). *(P)*

### 3.13 The framebuffer (moved from chapter 3)



### 3.14 virtio-gpu (moved from chapter 3)

**3.14.3** (moved from chapter 3) The framebuffer of virtio-gpu is the backing memory that the driver allocates; on the pdp64 it is ordinary memory mapped uncached (3.11.1), and the transfer command is the hand-off that tells the device to read it (the five steps of 2.5.3). *(P)*

### 3.15 A standard graphics card (moved from chapter 3)

**3.15.3** (moved from chapter 3) On the other side PCI Express is a standard enumerated bus, which suits the bus-as-a-device design (each function a slot, as each USB device is), and OpenBSD carries graphics drivers for several vendors' cards ported from Linux (*unverified*). *(P)*

### 3.16 What made graphics programming annoying: the pdp64 side (moved from chapter 3)

The goal (3.14.1) and the measure (3.14.2) are the author's and are in the body. The sketches of the pdp64's side below are the assistant's candidates for the means.

**Pair 1: getting a picture on the screen at all** (the sketch of the pdp64 side).

The pdp64 could offer **a device that already shows something**:

```
# the pdp64 way, open (a sketch)
# the device powers up with a sane default mode, in the monitor's preferred mode, with a canonical pixel format:
fb = peek(DISPLAY_BASE)            # where the picture is, always mapped
w  = peek(DISPLAY_WIDTH); h = peek(DISPLAY_HEIGHT)
poke(fb + (y * w + x) * 4, 0xFFFFFFFF)     # a white pixel: done
```

Options, with trade-offs. (a) The device **reports its mode** (a register holds the width, height and refresh rate of the mode chosen at start-up from the monitor's data; virtio-gpu's `GET_DISPLAY_INFO` already returns the width and height of each output in a `virtio_gpu_resp_display_info`); nothing to set. *Cost:* the device reads the EDID itself (a small I2C engine, which 3.10.1 already puts at the transmitter chip) and applies a policy; a program that wants another mode still has the registers. (b) A **fixed canonical pixel format** with the device converting at scanout (the repository's 48-bit RGBA pixel, errata 73, would be that format on the native device; virtio-gpu offers only 32-bit formats with eight bits per channel: `VIRTIO_GPU_FORMAT_B8G8R8A8_UNORM` and its siblings, in `virtio_gpu.h`, so the 48-bit pixel does not exist on the standard device; 3.23 lists the inconsistency). *Cost:* a conversion stage in the scanout, and memory a program wastes if it wants fewer bits. (c) **Stride equal to width** unless the program asks for padding, and the framebuffer window **always mapped**: the program has no `mmap`, no bank register, no `map_physical`; the window is in its address space from the start, a decision of the page tables and the bus (2.3.3 and 3.13.4). *Cost:* a fixed place in the address space, and a rule for what a program does that wants two framebuffers.

**Pair 2: the cache and the flush** (the open part).

A write-combining memory type for the framebuffer is a candidate improvement that the four memory types of 2.3.3 do not name; the cache rule itself is decided *(D)* and the speed is open *(P)*.

**Pair 3: drawing text** (the sketch of the pdp64 side).

The pdp64's terminal would do it as the C64 did, with one store:

```
# the pdp64 way, open (a sketch; names are placeholders)
poke(CELL(row, col).glyph, SLOT_OF('A'))     # or: poke(CELL(row, col).char, 'A')
poke(CELL(row, col).fg, RED)
# a new glyph: one library call fills a slot from the TrueType engine
font_render_into_slot(font, 'λ', slot)       # rasterises the outline and writes the bitmap into the slot
```

The author's glyph slots do the work of the atlas, and one library call replaces the first half of the boilerplate (3.9). Two candidates: (a) the cell holds the **character code**, and the device or a table maps the code to a slot, so the program never names slots (the author's c64x terminal of 2026-06-18, `c64stuff.txt`, line 5015: "each cell holds its actual data, not a reference to the data"); or (b) the cell holds the **slot number** directly, which is the simplest hardware and makes the program responsible for assigning slots. The choice is open (3.23): (a) is easier for the program and costs a lookup table in the scanout; (b) is nearly free and puts a small allocator in a library.

#### The pain points with the sugar

The table of 3.14 with its two further columns: the sugar that would remove each pain point, and where it appears in the sketches of 3.21 (S1 layers, S2 layers plus blitter, S3 command queue, S4 plain virtio-gpu with a library).

| Pain point | Typical boilerplate (illustrative) | The sugar that would remove it | Where (3.21) |
|---|---|---|---|
| Mode setting and discovering what the display supports (EDID, modes) | 15 lines (VESA) to 40 (DRM) | the device reads the monitor and starts in its preferred mode; a register reports it | S1 S2 S3 native; S4: `GET_DISPLAY_INFO` gives the size, a library the rest |
| Pixel formats | one format code to get right, and conversion code when it is not | one canonical format, the device converts at scanout | S1 S2 S3; S4 has 32-bit formats only |
| Stride and pitch | one multiply in every pixel address | stride equal to width unless asked; the address of pixel (x, y) is a register-reported formula | S1 S2 S3 |
| Endianness and colour order (RGB or BGR, alpha first or last) | a swap or a table, in every program | one defined order, little-endian (decided for the machine, errata 72); the colour field order named once | all |
| Bank switching and mapping the framebuffer | 5 to 20 lines | a window always mapped, no banks | all (3.13.4 is the rule for the type) |
| Double buffering and tearing | 10 to 30 lines, plus a frame loop | a latching base register, a fence, per-layer flip, versioned buffers (3.15) | S1 S2 per layer; S3 queue; S4 flush |
| Synchronising with the display | polling or a vblank interrupt handler | raster interrupt and a fence (3.15); decided: vblank interrupt at a fixed line (3.8.9) | all |
| Cache coherence between CPU writes and the device | 3 lines per update, forgotten once per project | decided: uncached memory type, no flush exists (2.5.2, 3.11.1); open: write-combining for speed | all |
| Device initialisation and context creation | 50 to 200 lines (Vulkan), 25 (virtio-gpu) | the device works at power-up; a single `enable` bit, a default | S1 S2 S3; S4 via a library |
| Buffer and memory management (allocate, map, upload, barriers, fences) | 20 to 100 lines | all video memory is a plain array in a window (S1 S2); no upload, nothing to map; or the device allocates (S3) | S1 S2 plain; S3 managed |
| Shader compilation and pipeline state | 50 to 300 lines | no shaders at all in S1 S2; a few fixed programs in S3, chosen by a field | S1 S2 none; S3 fixed |
| Drawing text (glyph atlases, kerning, layout) | 100 to 300 lines | a one-store put-character; glyph slots filled by a library call (3.9) | all native; S4 in a library |
| Clipping and windows | 10 to 30 lines per drawing call | a clip rectangle register per layer; a window is a layer | S2 S3 |
| Sprites and cursors | 20 lines to save, draw and restore | hardware sprites and a hardware cursor, two registers each | S1 S2 S3; S4 has the cursor queue only |
| Colour spaces and gamma | a table and a conversion, or wrong colours | one defined space (linear or sRGB, to be decided) with the device applying the transfer curve | open: S1 S2 S3 |
| Resolution changes and hot-plug | 20 to 60 lines of event handling | the bus reports a plug as an event (decided in chapter 2, 2.4); the device re-reads the monitor and signals "mode changed" | all |
| Fonts and scaling (HiDPI: screens with several pixels to a logical dot) | a scale factor threaded through every program | cells and glyph sizes defined in physical units by the device; the TrueType engine renders for the real pixel size | S1 S2 S3 |
| Input of palettes | 256 writes through ports (VGA) | a palette is an array in memory, loaded by `copy`; or none (true colour) | optional |
| Sound and video sync | a timestamp and a resampler | one clock for both devices (the audio clock relation of 3.12.4, decided as a duty of the mode setting) and a frame counter that audio can read | all |

Every item costs gates or flexibility, and the sugar column is a list of things to decide, not a recommendation. The repository has already decided the coherence rule *(D)*, the vertical-blank latch *(D)*, the uncached framebuffer *(D)* and little-endian *(D)*; every other cell in the sugar column is a candidate.

### 3.17 Anti-tearing sugar (moved from chapter 3)

The sugar is wanted (3.15.1 in the body, the author's). "So that the common program needs no more than a store" is the assistant's aim. The candidates, with what each costs, are proposals:

* **A scanout base register that latches at the vertical blank** (a page flip: the register holds the address of the picture to show and takes the new value only in the blank), with a completion **interrupt** or a **fence** (a counter that the device advances when the flip has happened, which the program can read or wait on, so it knows that the old picture is free). *Gives:* no tearing, no polling of the raster; the program writes one register and goes on. *Costs:* two pictures of memory for the program that uses it, and a rule for what the register shows if it is written twice in one frame (the first is dropped, or the second waits). *Already in 3.8.9, except the fence.*
* **Per-layer latching**, in a design with layers (3.21, sketches 1 and 2): each layer has its own base register and flips independently, so a cursor or a sprite layer can move every frame while the text layer flips only when its text changes. *Gives:* the cheapest case for text, a moving cursor with no redraw. *Costs:* one set of registers per layer.
* **An atomic commit of several registers**: several registers are staged and applied together at the blank (this is what `ARM` of 3.8.9 is for the single set; Linux calls the same idea "atomic modesetting" and offers `DRM_MODE_ATOMIC_TEST_ONLY` to ask "would this work?" and `DRM_MODE_ATOMIC_NONBLOCK` to ask for it without waiting, both in `drm_mode.h` on this machine). *Gives:* a change of mode, picture and cursor that cannot be seen half-done. *Costs:* the shadow copies of the registers, which a small device pays in flip-flops; an optional test-before-commit is more.
* **A raster-position register and a raster interrupt** (the C64 way): the program can know the row being read and be interrupted at a chosen row. *Gives:* mid-frame changes (the C64's trick of a different colour or sprite position per band) and a way to time drawing behind the beam. *Costs:* one register and an interrupt source; encourages programs that are tied to the display's timing.
* **Variable refresh** (the monitor waits for the frame instead of reading at a fixed rate: so a frame that is late is not a missed blank but a short wait; the standards are called adaptive sync, FreeSync, G-Sync and, for HDMI, VRR, variable refresh rate; unverified general knowledge). *Gives:* a late frame costs only its own delay, not a halving of the rate. *Costs:* the output must support it (the HDMI transmitter chip of 3.10.1 and the monitor), and the device's mode registers must say so.
* **Damage rectangles** (the program says which part of the picture changed and only that part is sent on): this is what virtio-gpu's `TRANSFER_TO_HOST_2D` and `RESOURCE_FLUSH` take as a `virtio_gpu_rect` (3.12). *Gives:* less memory traffic when little changes (a terminal). *Costs:* the program must track what it changed.
* **A hardware cursor and sprites**: objects that the scanout overlays at a position without touching the picture under them, so moving one never needs a redraw and never tears. *Gives:* the cursor, and in a game its moving objects, for the price of two registers each. *Costs:* gates in the scanout path and a limit on how many. (virtio-gpu has a cursor in its protocol: a separate cursor queue, `UPDATE_CURSOR` and `MOVE_CURSOR`, `virtio_gpu.h`.)
* **Versioned or copy-on-write buffers**: the device keeps the picture the scanout is reading and the program writes to a fresh version that replaces it atomically when the program says it is done, so the program can never see or show a half-drawn frame and never has to name two buffers. *Gives:* the sugar nearest to "nothing to do": a program draws and says `commit`. *Costs:* the memory and copying are the device's; a page-granular copy-on-write needs the memory-management machinery of chapter 6 or a device-side equivalent; a whole-frame version is twice the memory with a rule of who allocates it.
* **A fence or sequence counter**: a register that the device increments when each commit has been applied, which the program can read (poll) or wait for on an interrupt, to know when a buffer is free. *Gives:* synchronisation with no guess. *Costs:* a counter and a rule for wraparound.

And the same loop, in the style the pdp64 could offer, written with three of the candidates (a latching base register, a fence, and the interrupt) in the form that the program meets:

```
# 3. the flip at the blank, with the sugar: no polling of the raster, no waiting for the flip to be safe
poke(SCANOUT_BASE, front)
loop:
    draw_scene(back)
    poke(SCANOUT_BASE, back); poke(ARM, 1)    # staged now, latched by the device at the next blank (3.8.9)
    wait_until(peek(FLIP_COUNT) >= expected)  # a fence: the old picture is free (a candidate, not defined)
    swap(front, back)
```

Section 3.21 says which sketch gives which of these cheaply: the layered sketches give per-layer latching and a hardware cursor almost for free, the command-queue sketch gives the fence and the atomic commit, and the virtio-gpu route gives damage rectangles and fences and nothing about the raster. `FLIP_COUNT` and `ARM` above are placeholders; the repository defines `ARM` only as a name in 3.8.9.

### 3.18 A c64 mode: a small computer on the die that acts as the terminal (moved from chapter 3)

The c64 mode is the author's (3.16.1 and 3.16.2 in the body). This section is the assistant's explanation of how it could work, for the two readers, and states the questions it leaves open.

**What the Blit did.** The Blit (3.3) was a terminal with a computer of its own, and the host sent it **programs** instead of escape codes to interpret. The records in `docs/kernel-pain-points.md` (section 14I, from the Blit papers) say that the terminal received downloaded code over its serial line, that `mpxterm`, the terminal's program, "is 1627 lines of C" plus "204 lines of assembler" and multiplexed several host programs over the one line, and that the authors held that "an intelligent terminal is not an idiot savant, it is one that can be educated". A **terminal with its own small computer** is therefore a display, keyboard and mouse driven by a processor on the terminal's side of the cable, running a program the host loaded; the host sends it messages and the program draws. How the download worked (the protocol, the program format) is not in the records and is *unverified*. The VT52 and VT100 were the opposite: a fixed circuit obeying a fixed set of codes (3.2).

**A small core with the C64's chips is a terminal on a chip.** Take a small computer, give it the C64 family's circuits (the **VIC**, the video chip; the **SID**, the sound chip), **screen memory**, **colour RAM**, **glyph memory** (3.9) and a window towards the host, and let the host load its program. The program is the terminal's firmware: it receives bytes or messages from the host (by a mailbox), puts characters into screen memory, plays a sound, moves a sprite. The host sees a device that takes characters, as it saw a teletype, and the cleverness sits in a program the host can replace, as in the Blit.

**What "loaded by PCI Express DMA" means, mechanically.** The host puts the program image (the terminal's code and initial data) in its own memory and tells the device's **DMA engine** (the part that copies memory without the processor's help, chapter 2) the image's address, its length and the address in the small core's memory where it goes. The engine reads host memory over the PCI Express link (the bus-master read of 2.5) and writes the bytes into the core's memory. The core has been held in **reset** (a line that keeps a processor from running until it is released) since power-on, so it never executes incomplete memory; when the copy is done the host releases the reset and the core starts at its fixed start address. With placeholder names (no register of any such device exists):

```
load_terminal(image, length):                     # on the host, as a driver would
    poke(CORE_CTRL, HOLD_RESET)                   # the core is stopped
    poke(DMA_SRC,  physical_address_of(image))    # where the image is, in host memory
    poke(DMA_DST,  CORE_LOAD_ADDRESS)             # where it must go, in the core's address space
    poke(DMA_LEN,  length)
    poke(DMA_GO,   1)
    wait_until(peek(DMA_DONE) == 1)               # or an interrupt
    poke(CORE_CTRL, RELEASE_RESET)                # the core starts executing the loaded code
    # the host now talks to it through the mailbox:
    mailbox_send(PUT_TEXT, row, col, "hello")     # a message the loaded program understands
```

![A small core as the terminal: the loaded program and its address space](figures/gfx-core-map.svg)

The core's address space is the C64's (3.4) with a mailbox added. Everything the loaded program needs is in one flat space, as in the 1982 machine: its own code, screen and colour memory, glyph slots, the video and sound registers, and a window the host also sees. Video goes to the display connector and audio to its audio channel (3.10); audio over HDMI brings the audio clock relation of 3.12.4 with it, which the core's program must honour or the transmitter's own calculation must supply.

The questions that the author's words leave open, and the options for the core, are in J.3.11 (the statement 3.18.3, moved from chapter 3, is that list).

#### The compositor question

The author asked, 2026-11-10: "not sure what that would look like. is there virtio-compositor?"

**What a compositor is, at more length.** A **compositor** (defined in 3.16.2) combines the pictures of several windows or sources into the one picture sent to the display, which is then scanned out as in 3.15. In a desktop window system each program draws into its own picture (its **surface**) and the compositor places the surfaces, one over another, into the frame the scanout reads. The PC's windowing systems did this in software (3.5); in the layered sketches of 3.21 the scanout hardware does it, as the C64's chip did with sprites. The PDP-11 has no antecedent; its terminal was a single stream.

**Why "takes over" is the simple case.** If the c128 owns the output outright when enabled, there is nothing to compose: the machine has one scanout and one audio path, and the only question is who drives them. The multiplexer is a single enable bit (path (a) below). The compositor case differs in one way: the core is one client among others, so its picture and sound must be handed over in a form that the host's compositor, or the display controller's layers, can place.

![Five data paths for a c64-mode core sharing the display](figures/gfx-compositor-paths.svg)

**What exists, checked.** No virtio device is called a compositor: no entry of `virtio_ids.h` on this machine names one. The display-related types are GPU (16), input (18), sound (25), video encoder and decoder (30, 31), DMA buffer (37) and audio policy (39). The nearest parts in `virtio_gpu.h` are up to 16 scanouts (`VIRTIO_GPU_MAX_SCANOUTS`); `SET_SCANOUT_BLOB`, which sets a scanout from a blob resource (a memory object shared with the host without copying); a **cursor queue** separate from the control queue (`UPDATE_CURSOR`, `MOVE_CURSOR`); and capability sets (`VIRTIO_GPU_CAPSET_VIRGL`, `VIRGL2`, `GFXSTREAM_VULKAN`, `VENUS`, `CROSS_DOMAIN`, `DRM`) selected with `context_init`, so that several rendering contexts, each with its own ordering (the "timelines" of the header comment), share the device. QEMU's `docs/system/devices/virtio/virtio-gpu.rst` describes `virtio-gpu-rutabaga`, which provides "gfxstream rendering and Wayland display passthrough", with a `cross-domain` capset for Linux guests and experimental `x-gfxstream-composer` for Android guests; it says no more about what the cross-domain path carries. That the crosvm project uses the same mechanism to show a guest's windows as windows of the host's Wayland compositor (Wayland is the Linux display protocol in which clients hand surfaces to a compositor) is general knowledge and *unverified*. **virtio-snd** and **virtio-input** exist for audio and for keyboard and mouse. Paths (b) and (c) can therefore be built from parts that exist, and path (e) is a new device type; how a type gets its number is *unverified* here.


The five compositor paths, with their gains and costs, are in J.3.12.

The author's path (c), 3.16.3 in the body, makes the core a client like any other, the way rio treats every window (3.18: a window is a buffer and a rectangle), and its parts exist (a virtio-gpu resource or blob as the surface, 3.12). The details under it are in J.3.12; the audio form of the same choice is in 3.17.

**How the switch avoids tearing and pops.** Enabling or disabling the mode changes who feeds the scanout and the audio path. A change in mid-frame tears the picture (3.15), and a sudden change of the waveform's value is heard as a pop. The remedy has the shape of 3.15: hand over at a **vertical blank**, as the latch of 3.8.9 does for registers (the enable bit is one more shadowed register that `ARM` latches), and **mute with a short ramp** (a fade of a few milliseconds down before and up after, not a cut). In path (a) the enable bit is the shadowed register and the mute belongs to the audio path; in (b) to (e) the compositor does the hand-over and the core only stops or starts its stream. The audio clock relation of 3.12.4 must stay unchanged across the switch, or the transmitter loses its lock and the sound drops.

*Commentary.* **Chain.** The PDP-11 had only the fixed terminals of 3.2. The Blit loaded its terminal program from the host. The C128 put several complete computers in one box (general knowledge, *unverified*), and the MiSTer framework runs C64 and C128 cores in programmable logic. The pdp64 proposal puts a small core on the die and loads it by DMA. **Trade-offs.** A computer of its own makes the terminal programmable and independent of the host's drawing, and makes it a second machine to load, secure and keep consistent with the first. **Impact.** *Kernel:* a driver for the loader and the mailbox. *Compiler:* none. *Hardware:* a core, memory, DMA and the C64 family's circuits, or nothing in option (d).

### 3.19 The audio of the c128 core (moved from chapter 3)

The options for the audio form of the c64-mode core are in J.3.13.

![The audio path beside the video path](figures/gfx-audio-path.svg)

### 3.20 Windows: the goal (moved from chapter 3)

The author, 2026-11-10: "it should mention blit terminal was inspiration for the rio and NeWS windowing systems, and we'd like to bring over what we can of that simplicity also."

The goal (3.18.1) is in the body; the means are in J.3.14.

### 3.21 A design still being worked out: what a mashup of GPU, video memory, C64 and Blit could look like (moved from chapter 3)

The author, 2026-11-10: "conclude the graphics chapter: we're still figuring it out, what would a mashup of gpu, vram, c64 and blit look like." **Nothing in this section is decided.** Every statement is tagged *(P)* or *(S)*; the sketches are shapes of ideas put side by side so that the questions at the end can be answered, and the repository recommends none. The chain behind them: the PDP-11 terminal was a character stream (3.1), the Blit and the C64 put memory-mapped bitmaps, text, sprites and sound behind a processor or a few chips (3.3, 3.4), the PC split them (3.5), and the GPU turned drawing into queued commands and shaders (3.6); the sketches mix those inheritances.

**Two terms first.** **VRAM** (video memory) is memory that belongs to the display device: it sits on the device, behind a window on the bus, and the scanout reads it without crossing the bus; the processor reaches it through the window (slowly: every access is a bus transaction). The alternative is **system memory** that the device reads by DMA as a bus master, as the video device of 3.11.2 does; the framebuffer is then ordinary memory and the scanout competes with the processor for it. A GPU card has VRAM; the first board of the pdp64 has none to speak of (the block RAM is 5.5 megabits and a frame is 8.3 MB, 3.11.2), so on it every layer lives in system memory, and "VRAM" in the sketches below means "memory the device owns the use of", whichever kind it is. **Compositing** is combining several pictures into the one that is shown; the C64's sprites over text over a background were compositing in hardware, as the scanout read them out.

The device in these sketches is not specified beyond the 48-bit pixel and sample formats (errata 73 and 74). The properties the author has asked for, which each sketch is measured against: **(T)** simple peek/poke text and graphics at once; **(C)** modern colour depth and screen size; **(G)** glyph slots filled by a TrueType engine; **(S)** sprites, colour and sound in the C64's spirit; **(B)** the Blit's bit-blit and windows; **(U)** the GPU's command queue, parallel lanes and shaders. And the other two wishes of the day: anti-tearing sugar (3.15) and the boilerplate goal (3.14).

![Layers composed at scanout](figures/gfx-layers.svg)

#### Sketch 1: layered scanout, no command queue

**3.21.1** (moved from chapter 3) Three **layers** (a text-cell layer, a pixel layer and a sprite layer) are plain arrays in video memory that the processor pokes; the display hardware composes them as it reads them out, one pixel at a time, and there is no command queue. *(P)*

*What the programmer sees.* Three arrays, each at a fixed place, each with a small set of registers (base, size, stride, enable). The text array is the cell array of 3.9, with its glyph slots in another array; the pixel array is a framebuffer; the sprite layer is a table of entries (x, y, shape, colour, enable). A program pokes whichever it wants, in any order. *What is in video memory:* the cells, the glyph slots, the pixels, the sprite table and the sprite shapes. *At scanout:* for each pixel the hardware asks the layers from the top down (sprites, then text, then pixels), looks the cell up to its glyph, takes the glyph's coverage and the colours, and gives the first layer that is not transparent; the sprite layer needs to know only a few entries per row. The composing is done in a **line buffer** (a small memory that holds one row), as 3.11.2 already provides for. *Costs:* a compositor of the order of the 1,500 lookup tables the repository estimates for the blitter, plus a line buffer per layer (an estimate of mine, unmeasured); scanout traffic is the pixel layer's 498 MB/s at 1920 by 1080, 4 bytes, 60 Hz (746 MB/s at 6 bytes), plus about 13 MB/s for the cells and the glyph reads (arithmetic from the examples of 3.9). *Gives up:* anything beyond what the layers can say: no scaling or rotation, no effect that is not in the compositor; every change a program wants to make to the pixel layer is the processor writing pixels. *Properties kept:* T yes (this is the C64 and the Blit's memory-mapped screen); C yes; G yes (the text layer's glyphs); S yes (sprites, and colour per cell; sound is a separate device, 3.8.3); B no (no blitter, windows are the program's job); U no. *Text and graphics split:* healed, the C64's way: a program has text and pixels at once in one frame, with no mode switch. *A game:* sprites and a scrolling text or pixel layer, moved with a few pokes a frame; the C64 game, with a modern screen. *A terminal emulator:* pokes cells (a scroll is a few stores, or, with a base register for the layer, one store); the glyph slots are filled by the TrueType engine. *Sugar:* per-layer flip and a hardware cursor for free (3.15); the fence is the vertical-blank counter. *With virtio across the board:* needs a virtio device type of its own (reading 1 of 3.9); the layers are a device's contents, not the virtio-gpu protocol.

#### Sketch 2: the same, plus a small blitter and a glyph atlas

**3.21.2** (moved from chapter 3) Sketch 1 plus a **blitter**, a few registers that copy and combine rectangles inside video memory (the Blit's RasterOp, the Amiga's blitter; the register sketch of 3.8.4), and a glyph atlas that the TrueType engine fills and the text layer indexes. *(P)*

*What the programmer sees.* Sketch 1, and a handful of blitter registers: source, destination, strides, width, height, raster operation, go. The atlas is the glyph map seen as one picture (3.7): a glyph is drawn from it by the blitter into the pixel layer when a program wants a glyph on the pixel layer at an arbitrary position, and the text layer's cells point at it directly. *In video memory:* sketch 1's contents and the atlas. *At scanout:* as sketch 1. The blitter runs beside it, in the blanking time or contending for the memory. *Costs:* the blitter and its arbitration with scanout; the repository's own estimate is about 1,500 lookup tables and a line buffer, "nearly all address arithmetic" (3.8 commentary), and a bus-master port on video memory. *Gives up:* the same as sketch 1, except that drawing, scrolling and window moves in the pixel layer no longer cost the processor the pixels. *Properties kept:* T, C, G, S as sketch 1; **B yes** (bit-blit with the raster operations of 3.8.7, and windows as layers or as rectangles in the pixel layer); U no. *Split:* healed as sketch 1, and the pixel layer gains the Blit's operations, so that text on it (a window of a program that draws its own glyphs) is cheap. *A game:* sprites for the actors and the blitter for the background tiles. *A terminal emulator:* the text layer as in sketch 1; the blitter scrolls and moves windows drawn on the pixel layer. *Sugar:* as sketch 1, plus a blit that starts at the vertical blank (the "start-at-vblank" of `architecture-recommendations.md` R-9), which stops a copy from tearing. *With virtio:* as sketch 1, the blitter a feature of the device; it would be a feature bit and a queue if its commands are descriptors rather than registers (the chat chose a three-operand `draw` command, `decisions-pending.md` E3).

```
# sketch 2: scroll the pixel layer up by one text line, then draw a glyph from the atlas (placeholders)
poke(BLT_SRC, FB + LINE_H * STRIDE);  poke(BLT_DST, FB)
poke(BLT_STRIDE, STRIDE);  poke(BLT_W, W);  poke(BLT_H, H - LINE_H)
poke(BLT_OP, STORE);  poke(BLT_GO, 1);  wait_until(peek(BLT_BUSY) == 0)
```

#### Sketch 3: a command-queue device with a peek/poke window

**3.21.3** (moved from chapter 3) A device whose main interface is a **ring of commands** in the manner of virtio-gpu, with a tiny shader-like fixed program for drawing glyphs and sprites and video memory managed by the device, and a peek/poke compatibility window on top for the programs that want to poke cells and pixels. *(P)*

![A command queue with a peek/poke window](figures/gfx-cmdqueue.svg)

*What the programmer sees.* Mostly commands: "put this text at this cell", "move this sprite", "fill this rectangle", "present"; and, as a convenience, the window: cells and pixels as plain memory that mirrors the device's. The device allocates its own video memory, so a program does not choose addresses. *In video memory:* what the device decides; the program sees handles. *At scanout:* the device renders the commands into whatever it scans out, at its own pace, and flips at the blank by itself (the sugar is free: a commit is a command). *Costs:* a command processor (a queue engine, as the virtio devices of chapter 2 already are), a drawing engine of fixed programs (the small piece of the GPU that the terminal needs: a textured quad with a glyph and two colours, a sprite), a memory manager for video memory and a consistency rule between the window and the queue; more gates than sketches 1 and 2 by a clear margin (a judgement of mine, unmeasured), and more software in the driver. *Gives up:* the plainness of sketch 1; the program must know the device's model, and two ways to reach one cell must be reconciled. *Properties kept:* T only through the window (and only as well as the window is made); C yes; G yes (the engine reads glyph slots); S yes; B no blit, but "fill" and "copy" commands do its job; **U yes**, a command queue and parallel work, but a *fixed* program, not the general shaders of 3.6. *Split:* healed by the engine, which draws text and pixels from one queue. *A game:* a command per sprite or per tile, one "present" per frame, with little processor work. *A terminal emulator:* one command per changed run of cells; the glyph atlas as in 3.7, but made by the device. *Sugar:* the fence and atomic commit are the natural form (each command completes in order; a commit is a command); versioned buffers are the device's business. *With virtio:* the natural fit, a device with queues as in 2.7, and the closest in spirit to virtio-gpu, of which it could be a profile (reading 2 of 3.9).

#### Sketch 4: virtio-gpu 2D, the sugar in a library

**3.21.4** (moved from chapter 3) The standard virtio-gpu 2D route of 3.12, with the C64 and Blit conveniences done in software by a library (cells, glyphs, sprites and cursor, blits, flips), and no special hardware. *(P)*

*What the programmer sees.* A library that offers the peek/poke look: a cell array in memory, `put_char`, sprites as library objects, and a `present` call that does the transfer and the flush for the damaged rectangles. *In video memory:* the host's resources; on the pdp64 the program's memory is the backing (3.14.3). *At scanout:* the host reads its resource when it likes; the library cannot flip at a blank because virtio-gpu has none (3.12); tearing is the host's concern and, on an emulator, usually invisible. *Costs:* nothing in gates; the processor draws everything and a flush copies; bus traffic is the damage rectangles. The glyph slots are a library table, filled from the TrueType engine on the processor. *Gives up:* everything hardware: the hardware cursor is the cursor queue only, there are no sprites except the cursor, no blits, no layers; the C64's "the chip draws it while you do other things" is the library's loop. *Properties kept:* T only through the library (the program pokes memory the library owns, and the library presents it); C only to 32 bits (3.14.4); G yes, in software; S no (the cursor excepted); B in software; U no. *Split:* healed in the library's picture, but each screen is still one pixel framebuffer. *A game:* draws into a back buffer and flushes it, in the PC way of 3.5 (slow, but running now). *A terminal emulator:* the library draws glyphs from a cache and flushes the damaged rows. *Sugar:* damage rectangles and the fence only (3.15, 3.12). *With virtio:* it is the standard (errata 79, 95); sketches 1 to 3 would be added to it as another device or as a profile.

#### Sketch 5: a c64-mode core as the terminal (a variant)

**3.21.5** (moved from chapter 3) A small core with the C64 family's chips, into which the host loads the terminal program by DMA (3.16), as a variant or addition to any of the sketches above: it is the terminal, and the other sketches say what the display behind it does. *(P)*

*What the programmer sees.* The host programmer sees a device that takes messages (the mailbox); the programmer of the small core sees the C64: peek, poke, a screen at a fixed place, colour RAM, glyph slots, sprites and the SID, which is the author's "as simple and pleasurable as the c64 was" at its most literal. *In video memory:* the core's screen memory, colour RAM, glyph slots, sprite shapes. *At scanout:* the VIC (or its extension) composes text, bitmap and sprites as sketch 1 does; the flip is a register of the core's own. *Costs:* a core, its memory, a DMA loader and the chips (3.16, question 7); a second program to write, load and keep secure. *Gives up:* a single, standard programming model on the host's side; the host cannot poke a cell, only send a message. *Properties kept:* T yes, for the core's programmer; C if the chips are widened as the native devices were (3.8); G yes; S yes, with sound; B only if the chip family has a blitter; U no. *Split:* healed, in the core. *A game:* a C64 game, or one written for the core. *A terminal emulator:* the core *is* the terminal; the host sends text. *Sugar:* the VIC's latches and raster interrupt, which the core's program uses; nothing is hidden from it. *With virtio:* the open tension of 3.16, question 6.

#### The four main sketches side by side (sketch 5 is a variant of any of them)

| | S1 layers | S2 layers + blitter | S3 command queue + window | S4 virtio-gpu + library |
|---|---|---|---|---|
| What the program does | pokes arrays | pokes arrays, starts blits | writes commands (or pokes the window) | calls a library, which sends the commands of 3.12 |
| Who composes | display hardware, at scanout | display hardware, at scanout | the device's engine | the host, or the program |
| Where glyphs live | slot array in video memory | atlas in video memory | the device's cache of slots | the library's table, in the program's memory |
| Sprites | hardware layer | hardware layer | engine primitive | no (cursor only) |
| Blitter | no | yes | fill/copy commands | in software |
| Commands or pokes | pokes | pokes and a few registers | commands, pokes as a window | commands under a library |
| Anti-tearing sugar | per-layer latch, cursor, raster | the same plus blit at blank | commit, fence, atomic | damage and fence only |
| Cost in gates (my estimate, unmeasured) | small: a compositor and line buffers | small to medium: add a blitter | larger: a queue engine, a drawing engine, a memory manager | none |
| Bus traffic | scanout, plus the pokes | the same, less processor traffic for blits | scanout, plus commands (small) | scanout is the host's; the program writes every pixel |
| Fits virtio everywhere (errata 95) | needs its own device type | needs its own device type | a profile of virtio-gpu, or its own | is virtio-gpu |
| Properties T C G S B U | T C G S, no B U | T C G S B, no U | C G S U; T by the window; B by commands | T by library; C only 32-bit; G in software |
