<a id="j31"></a>
### J.3.1 The deferred native devices

**Issue.** The first design of the graphics and sound hardware was a family of devices of the pdp64's own: a video device derived from the Commodore 64's video chip, with 48-bit pixels (12 bits for each of red, green, blue and alpha; errata 73); a sound device derived from the C64's sound chip, with voices and a general sound path of 48-bit samples (errata 74); and a blitter (an engine that copies and combines rectangles of pixels, in the manner of the Blit terminal), all three controlled through a small fixed set of registers. They were deferred (errata 78) and the register model on which they were defined was then abolished (errata 95: "virtio across the board"). The standard interfaces are now virtio-gpu (2D) and virtio-snd. What is unanswered is what the architecture should say about the native devices now: keep them as a marked future part, drop them, redefine them over virtio, or something else. Whatever the answer, the scan-out hardware (the circuit that reads the frame from memory and feeds the display) still has to be built, and the standard video device does not remove it, since virtio-gpu is a protocol, not a scan-out engine.

**Why it matters.** Each native device is one more driver for the OpenBSD port, which is exactly what errata 78 wanted to avoid. Nothing in the instruction set depends on them; the 48-bit pixel and sample matter only to software that renders or mixes for them. The author's wishes (the Blit's model, the C64's graphics and sound, 48-bit samples) have no home until this is answered. The same author also wants the standard audio and video interface to be the one that every operating system already supports.

**Options.**

1. *Keep as a marked future part.* Keep the native-device material in the deferred appendix (appendix I, chapter 3), with every statement and tag, rewrite the wording that assumes the abolished register model, and state that nothing in the standard depends on it. For: preserves the author's work and the 48-bit decisions at the least cost; the author said "planned for the future", not "dropped". Against: a body of statements that nobody implements; wording written for the old model becomes false and must be caveated; the old text may be read as current.
2. *Remove it.* Delete the material and keep the decisions only in the record; the graphics chapter then says virtio-gpu, virtio-snd, the display output and the framebuffer. For: nothing dead is specified; one source of contradiction fewer. Against: loses the Blit and C64 design record from the manual; contradicts "planned for the future"; the 48-bit pixel decision loses its home.
3. *Redefine as virtio.* Treat virtio-gpu and virtio-snd as the whole interface and carry the extras as feature bits or formats on those devices (a 48-bit pixel format, a 48-bit sample format), implemented in every model. For: one transport driver serves everything; a format is a negotiation, not a device. Against: stock hosts and drivers would reject a 48-bit format (virtio-gpu's 2D formats are, as far as is known, 8 bits for each channel, and virtio-snd's stop at 32- and 64-bit integers and floats; the lists are to be checked), so a fork is needed; none of the sprites, raster interrupts or voices survives.
4. *An optional PCI Express card outside the standard.* Publish the video, sound and blitter designs as an optional card with its own driver, defined from scratch with configuration space and message-signalled interrupts; the standard stays virtio. For: keeps the designs as real hardware someone may build, in the manner of the optional C128 of errata 77; available at any time, since any PCI Express device may be attached. Against: a full register specification must finally be written; the first boards have no PCI Express block; drivers exist only if someone writes them.
5. *Keep the Blit model as software.* Drop the three devices as hardware; keep the Blit's ideas (the framebuffer in the address space, the four primitives of bit-block transfer, texture, segment and point, half-open rectangles, layers) as a library run by a core the kernel assigns, drawing into a virtio-gpu 2D resource and flushing rectangles. For: the Blit itself had no pixel-moving hardware and did everything in software; reuses cores that exist; no new device (no core is dedicated to graphics, errata 133). Against: one core is slow at 1920 by 1080 at 48 bits (12.4 MB a frame) unless it is wide or has vector instructions; the C64 and sound personalities vanish.
6. *A pdp64 blit and sprite extension as its own virtio device type,* or as a feature of virtio-gpu, whose queue carries blit commands (source, destination, strides, rectangle, raster operation) and C64-style sprite and raster-interrupt services, so that the idea of registers plus DMA becomes a command queue. For: the virtio way to carry what registers carried; keeps the author's blit and sprite design on the standard transport. Against: no stock host implements a new device, so the device model, the hardware and the driver must all be written, which is the "bunch of device drivers" of errata 78; a new device number in the shared virtio registry needs care.

**Precedents.** The repository keeps the alternatives of errata 94 as a documented comparison and keeps the C128 as an optional device outside the standard *(verified: errata 94, 77)*. The Blit terminal (a Motorola 68000 at 8 MHz that drew every pixel itself) *(verified: chapter 3 commentary)*; Plan 9's draw device and libdraw keep the same primitives in software *(unverified: general knowledge)*. VGA-compatible PCI cards that expose a legacy register set beside a native one *(unverified: general knowledge)*; the Amiga's fixed custom chips *(unverified)*. virtio-gpu carries all its commands as structures in a control queue; whether its 2D set has a resource-to-resource blit is not known *(unverified: to check)*. NVMe and xHCI also command through queues in memory *(verified: chapter 5)*. OpenBSD has a driver for virtio-gpu *(verified from a fetched directory listing)*; whether it has one for virtio-snd is open *(errata 79)*.

**The author's referents.** The Blit ("i like the blit model", "we are basing the design not only on the c64, but also on the blit terminal"); "all the c64 graphics and audio goodies" and "48 bit sound as well, not just the sid"; "our 12 register nic and sound card and graphics card are planned for the future"; "a standard audio/video interface so there is no bullshit with supporting a bunch of device drivers, although as a pcie bus any device MAY be attached"; the C128 as "just another device on the bus; not part of the pdp64 standard"; "modern 48 bit audio and 48 bit pixels"; HDMI "like sata and usb, is standard kit".

**The assistant's leaning.** Option 1 now, with Option 5 as the intended direction: the material is kept in the deferred appendix, and the live part of the chapter is the display output (HDMI through a transmitter chip fed a pixel stream), the framebuffer and its memory type, now about virtio-gpu and virtio-snd. Removal would contradict the author's words; Options 3 and 6 need a format or device that no stock host provides; Option 4 stays available later. It would change if the author says that the 48-bit pixel and sample are required in the first iteration (Option 3 or 6), that he will not build them (Option 2), or if a measurement shows that virtio-gpu scan-out cannot reach 1080p on the first board (a native device for the FPGA alone, Option 4).

**Where the body refers to it.** Nowhere: the matter is deferred (appendix I, chapter 3: the sections 3.8 and 3.11 moved from the body), and the body does not mention the devices.

<a id="j32"></a>
### J.3.2 The form of the terminal device and its name

**Issue.** On 2026-11-10 the author described "our virtio-console device" as "an attempt to bring the nice properties of the blit terminal and c64 for doing simple and easy peek poke style display of text and also doing graphics, but with modern color depths and screen sizes" (errata 105). That there is such a device, with peek and poke text and graphics and glyph slots, is decided (3.9.1); what is open is its form and its name. No document defines a device of that name: not its identification, its queues or its registers. The real virtio-console is a serial text device (device type 3; a configuration structure of `cols`, `rows`, `max_nr_ports` and `emerg_wr`; the feature bits `SIZE`, `MULTIPORT` and `EMERG_WRITE`; control messages for ports; one receive and one transmit queue for each port). Its data are byte streams, with no cells, colours, glyphs or pixels, like the teletype of 3.1. The device the author describes has cells, colours, glyph slots and graphics, which neither the real virtio-console nor virtio-gpu 2D has. The standard video device is virtio-gpu in 2D mode (errata 79, 95).

**Why it matters.** The kernel needs one driver for the text display and one for graphics, and the author wants no more drivers than the standard demands (errata 78). Until the form is chosen, the terminal cannot be specified, the boot console cannot be named and the glyph-slot question (J.3.4) has no device to belong to.

**Options.**

1. *A new virtio device type of the pdp64's own,* with the cell array and the glyph slots as the device's memory. For: one device that matches the author's words; virtio's transport, queues and discovery are reused. Against: no stock host implements it, so the device model, the hardware and the driver must all be written; a number in the shared virtio registry needs care.
2. *virtio-gpu extended by a text layer and glyph slots.* For: one display device, not two; the host's existing virtio-gpu driver still works for the parts it knows. Against: the extension is a fork of a shared specification; stock hosts ignore the new commands, so text would fall back to pixels.
3. *The real virtio-console as the text stream for existing tty programs (3.2), beside a separate display device.* For: nothing to invent; every existing tty program works; it is the form the boot console already assumes. Against: it is a stream, so it gives none of the peek and poke the author wants; two devices must be coordinated.
4. *The native device family, renamed* (the deferred devices of J.3.1). For: the closest match to the author's description; the C64 and Blit designs are kept. Against: errata 95 abolished the register model they used; each one is one more driver.
5. *A library over virtio-gpu* that offers the peek and poke look in the program's own memory (the fourth sketch of J.3.3), as a first realisation of the device. For: no new hardware or driver; runs now. Against: not yet the "device" the author names; the chip does not draw text while the program does other things.

**Precedents.** The Linux header `virtio_console.h` and the device-type list in `virtio_ids.h` (types 3 for console, 16 for GPU, 18 for input, 25 for sound) *(verified: the headers on this machine)*. The repository mentions virtio-console only as a candidate console for the boot ROM and kernel (5.7.1). Plan 9's draw device, a stream of small commands written to a file *(unverified: general knowledge)*.

**The author's referents.** The Blit terminal and the C64; "peek poke style"; "glyph maps ... a ttf engine generate glyphs and they will go into their memory slots"; the author's earlier terminal chat of 2026-06-18, a separate project in which a cell holds colours, a character and attributes and existing tty programs run through a shim.

**The assistant's leaning.** Option 3 for the console stream and Option 5 as the first display, with Option 1 or 2 as the device the author describes.

**Where the body refers to it.** Section 3.9.1.

<a id="j33"></a>
### J.3.3 The mashup: how the display composes text, pixels and sprites

**Issue.** The author asked on 2026-11-10 "what would a mashup of gpu, vram, c64 and blit look like" (errata 105). Five shapes were drawn, all proposed (appendix H, 3.21): (S1) layers composed at scanout, with no command queue; (S2) the same plus a small blitter and a glyph atlas; (S3) a device whose main interface is a ring of commands, with a peek and poke window; (S4) virtio-gpu 2D with the conveniences in a library; (S5) a small core with the C64's chips, as a variant of any of them. **VRAM** is memory the display device owns, behind a window on the bus; on the first board there is none to speak of (the block RAM is 5.5 megabits and a frame is 8.3 MB), so every layer lives in system memory. The properties the author asked for: (T) simple peek and poke text and graphics at once; (C) modern colour depth and screen size; (G) glyph slots filled by a TrueType engine; (S) sprites, colour and sound in the C64's spirit; (B) the Blit's bit-blit and windows; (U) the GPU's command queue, parallel lanes and shaders.

**Why it matters.** It decides whether the display needs hardware beyond the standard virtio-gpu, how many drivers the kernel carries, and how much of the author's "as simple and pleasurable as the c64 was" is delivered by the machine and how much by a library.

**Options.**

1. *S1, layered scanout.* A text layer, a pixel layer and a sprite layer in memory, composed by the display hardware as it reads them out. For: keeps T, C, G and S; the C64's model with a modern screen; per-layer flip and a cursor come free. Against: no blitter, no scaling or rotation; needs a device type of its own; scanout traffic is the pixel layer's 498 MB/s at 1920 by 1080 (4 bytes, 60 Hz), plus the cells.
2. *S2, S1 plus a blitter and an atlas.* For: adds B; scrolling and window moves cost the processor no pixels; the blitter is about 1,500 lookup tables (`docs/pdp64-fpga-plan.md`). Against: a bus-master port on video memory and its arbitration with scanout; its own device type.
3. *S3, a command-queue device with a peek and poke window.* For: the natural virtio shape (queues of 2.7); fence and atomic commit are the form of a commit; U in a fixed form. Against: more gates and a memory manager; two ways to reach one cell must be reconciled; T only through the window.
4. *S4, virtio-gpu 2D with a library.* For: it is the standard (errata 79, 95); no gates. Against: no sprites, no blits, no layers; C only to 32 bits; the processor draws every pixel; the host reads the resource when it likes.
5. *S5, a small core with the C64's chips as the terminal.* For: the author's phrase at its most literal; the host sends messages only. Against: a second program to write, load and secure; see J.3.11.
6. *A combination,* for example S4 now and S2 or S3 as a second device later. For: nothing is wasted while the author decides. Against: two display models to keep consistent.

**Precedents.** The C64's text, bitmap and sprite compositing at scanout *(unverified: general knowledge)*; the Amiga's blitter *(unverified)*; the Blit, which did every pixel in software on a 68000 *(verified: the Blit papers as recorded in `docs/kernel-pain-points.md` section 14I)*; a GPU's fixed-function scanout planes *(unverified)*; virtio-gpu 2D as the first iteration *(verified: errata 79)*.

**The author's referents.** The Blit, the C64, "gpu, vram, c64 and blit"; "graphics programming should be as simple and pleasurable as the c64 was".

**The assistant's leaning.** S4 is what the standard already is. Of the hardware shapes S2 matches his words most closely, and S1 is S2 without the blitter, which can be added later because it only reads and writes video memory; S3 is nearer if he wants commands rather than pokes as the main interface.

**The questions to answer in order to choose.** Who composes the layers (the hardware, the device's engine, or software); where glyphs live; whether sprites exist; whether there is a blitter, as registers or as commands; whether commands or pokes are the main interface; which virtio shape; VRAM or system memory; what pixel format (J.3.6).

**Where the body refers to it.** Section 3.9.1.

<a id="j34"></a>
### J.3.4 Glyph slots against character codes

**Issue.** The author decided a **glyph map** (3.9.1): a table of slots, each holding the picture of one glyph, filled by a TrueType engine (software that draws a glyph from the font's outline at the display's pixel size) and used by every cell that names it. What is open, the details, is what a cell holds, a **character code** that a table maps to a slot, or the **slot number** itself; the layout of a slot (width, height, pixel format, whether a slot may span several cells for a wide glyph); and the number of slots. The author's earlier terminal chat held that "each cell holds its actual data, not a reference to the data", which suggests the code. As arithmetic only: a 1920 by 1080 screen of 8 by 16 pixel cells is 240 by 67 cells, 16,080 cells; with a cell of about 13 bytes that is 209 KB, and 4,096 slots of 16 by 32 coverage bytes are 2 MB, small against a 12.4 MB frame at 48 bits or 8.3 MB at 32.

**Why it matters.** The choice sets the program's work (naming slots against naming characters), whether the scanout needs a lookup table, and how Unicode, wide glyphs and fallback fonts are handled.

**Options.**

1. *The cell holds the character code;* a table maps code to slot. For: easy for the program, which never names slots; matches the chat-era cell. Against: a lookup table in the scanout; a policy for codes that have no slot.
2. *The cell holds the slot number.* For: nearly free in hardware. Against: the program or a library must allocate slots and keep a map from characters to slots.
3. *Both:* a cell has a flag that says which. For: ASCII by code and special glyphs by slot. Against: two paths in the scanout and the library.
4. *A glyph atlas, as one picture,* from which the cells or a blitter copy (the glyph map seen as the atlas of the GPU text path of 3.7). For: the same model as the GPU's; the blitter can draw a glyph anywhere. Against: needs the blitter of J.3.3 for the pixel layer.
5. *No slots:* the library draws glyphs into the pixel layer, as on virtio-gpu (S4). For: no hardware. Against: gives up the hardware text layer.

**Precedents.** The C64's character ROM of 8 bytes a glyph, replaceable by RAM *(verified: chapter 3, unverified numbers)*; VGA text mode's font in the adapter's memory *(unverified)*; the GPU glyph atlas of Alacritty, kitty and WezTerm *(unverified)*.

**The author's referents.** "with glyph maps we can even have a ttf engine generate glyphs and they will go into their memory slots for use"; "each cell holds its actual data, not a reference to the data" (the chat of 2026-06-18, `c64stuff.txt` line 5015).

**The assistant's leaning.** Option 1 for the program's sake, if the display is hardware; if it is the library of S4 the question disappears.

**Where the body refers to it.** Section 3.9.1.

<a id="j35"></a>
### J.3.5 Sprites and the hardware cursor

**Issue.** A **sprite** is a small picture the display hardware overlays at a position the program gives, without touching the screen memory beneath. The C64 had eight. The Blit drew its cursor in software, in exclusive-OR, at 60 Hz. The author's description of 2026-11-10 does not mention sprites; the earlier terminal chat put them on a separate plane. virtio-gpu has a cursor in its protocol (the cursor queue, `UPDATE_CURSOR`, `MOVE_CURSOR`), and no sprites.

**Why it matters.** A moving cursor or game object either costs a redraw of the picture beneath it, which tears, or costs gates and a limit on the number.

**Options.**

1. *None:* the program draws the cursor in software. For: no hardware. Against: save, draw and restore, about 20 lines a program; may tear.
2. *The virtio-gpu cursor queue only.* For: standard; nothing to build. Against: one cursor; no sprites; the host decides the timing.
3. *A hardware cursor, two registers.* For: cheap; never tears. Against: a native device.
4. *A sprite layer of several entries.* For: the C64's model; games and moving objects without redraw. Against: gates in the scanout path; a limit on the number.
5. *Sprites as library objects over the cursor queue or a layer.* For: a program sees sprites. Against: not hardware; the speed is the library's.

**Precedents.** The C64's eight sprites *(unverified: general knowledge)*; the Blit's software cursor *(verified: `kernel-pain-points.md` 14I)*; the virtio-gpu cursor queue *(verified: `virtio_gpu.h`)*.

**The author's referents.** The C64 ("the c64 did games, so it had sound and color and sprites as well"); the Blit.

**Where the body refers to it.** Section 3.9.1.

<a id="j36"></a>
### J.3.6 The 48-bit pixel against the formats of virtio-gpu

**Issue.** The author decided a 48-bit pixel, RGBA with 12 bits for each channel (errata 73), and a 48-bit sound sample (errata 74), as properties of devices that are deferred (appendix I). The standard video device, virtio-gpu 2D, has eight 32-bit formats with 8 bits for each channel (`B8G8R8A8_UNORM`, `B8G8R8X8_UNORM`, `A8R8G8B8_UNORM`, `X8R8G8B8_UNORM`, `R8G8B8A8_UNORM`, `X8B8G8R8_UNORM`, `A8B8G8R8_UNORM`, `R8G8B8X8_UNORM`), and virtio-snd's formats stop at 32-bit integers and 64-bit floats. A 48-bit pixel probably exceeds what a display connector carries (unverified), so the device that scans out would convert on the way out.

**Why it matters.** Software that renders at 48 bits has no standard device to show it on; the author's wish for 48-bit pixels and samples has no home until this is answered.

**Options.**

1. *The 48-bit formats belong only to a deferred native device.* The standard device is 32 bits. For: nothing is forked. Against: the decision of errata 73 has no standard effect.
2. *A pdp64 format added to virtio-gpu* (a 48-bit, or a 64-bit with 16 bits a channel, resource format) and likewise for virtio-snd. For: one transport; a format is a negotiation. Against: stock hosts and drivers reject it, so a fork is needed; the format lists are to be checked.
3. *Render at 48 bits in software, convert to 32 for the flush.* For: no change to the device; programs keep the precision. Against: twice the memory and a conversion on every frame.
4. *A 64-bit-per-pixel format,* 16 bits for each channel, as a power-of-two size. For: aligned; keeps all 12 bits. Against: not the author's 48; wastes 16 bits.
5. *The pixel width is a property of the scan-out hardware,* converted at the edge to what the transmitter takes. For: the standard protocol stays; the hardware keeps the precision. Against: the program cannot see it.

**Precedents.** virtio-gpu's formats, from the header *(verified: `virtio_gpu.h`)*; virtio-snd's formats *(verified: `virtio_snd.h`)*; 10- and 12-bit-per-channel deep colour over HDMI *(unverified: general knowledge)*.

**The author's referents.** "modern 48 bit audio and 48 bit pixels"; "the 48 bit is a new decision of mine, rgba format, 12 bits per color/channel"; "i want 48 bit sound as well, not just the sid".

**Where the body refers to it.** Section 3.12.1.

<a id="j37"></a>
### J.3.7 The virtio feature subset, hot-plug and the OpenBSD drivers

**Issue.** virtio-gpu has optional parts: the EDID feature (the display reports the modes it supports), the fence flag, the cursor queue, blob resources and the 3D features of the header. virtio-snd has controls such as volume and flags for shared memory, polling and period events. The pdp64 must say which of these every implementation provides. Whether OpenBSD has a virtio-snd driver is not known (errata 79: "if not, one is written"); it has one for virtio-gpu (a directory listing). The scope of hot-plug (a monitor or a device arriving while running) is also open (`decisions-pending.md` F23).

**Why it matters.** An application can use a feature only if every machine has it; the three models (QEMU, `sim64`, the FPGA) must agree.

**Options.**

1. *The minimum:* 2D, fence, display information, no cursor, no EDID. For: least to implement. Against: no cursor, no real mode list.
2. *Minimum plus the cursor queue and EDID.* For: a hardware-like cursor; a monitor's real modes. Against: more to implement.
3. *All of the 2D features, none of 3D or blob.* For: everything a 2D driver uses. Against: the blob feature for a core's surface (J.3.12) is excluded.
4. *Everything the header offers.* For: no later restriction. Against: 3D and capability sets have no use on a core with no shader hardware.
5. *Whatever the first driver (QEMU's) needs,* settled by experience. For: honest. Against: the architecture states no requirement.

**Precedents.** QEMU's `virtio-gpu.c` rejects out-of-range rectangles, and has a `refresh_rate` field *(verified: the QEMU sources)*; OpenBSD `viogpu` *(verified: a fetched listing)*.

**The author's referents.** "yeah, virtio is fine"; "the simplest to program while still being efficient".

**Where the body refers to it.** Section 3.12.1.

<a id="j38"></a>
### J.3.8 Anti-tearing conveniences

**Issue.** A **tear** is a seam in the picture when a program changes it while the scanout reads it. The author asked for "nice architectural sugar to avoid 'tearing' and all those other issues graphics programmers had to use double buffering to fix" (errata 105) and asked whether tearing is a concern with HDMI at all. It is not a property of HDMI: it happens in the display controller. A program that writes straight into the framebuffer with no operating system can still tear. Variable refresh (the monitor waits for the frame) reduces the need to flip at the blank but does not remove it. virtio-gpu defines no vertical blank and no page flip: a flush says "show this now". That the architecture offers such sugar is decided (3.15.1); which sugar, and whether a tear-free flip is worth hardware on a variable-refresh display, is the author's to say.

**Why it matters.** Every game and every compositor depends on how a flip is timed.

**Options.**

1. *A scanout base register that latches at the vertical blank,* with an interrupt or a fence. For: no tearing, no raster polling. Against: two pictures of memory; a rule for two writes in a frame.
2. *Per-layer latching.* For: a cursor moves every frame while text flips only when it changes. Against: one register set per layer; needs layers (J.3.3).
3. *Atomic commit of several registers at the blank* (Linux's "atomic modesetting"). For: a change of mode, picture and cursor cannot be seen half-done. Against: shadow copies cost flip-flops.
4. *A raster-position register and a raster interrupt.* For: the C64's mid-frame tricks. Against: ties programs to the display's timing.
5. *Versioned buffers:* the device keeps what is being read and the program writes a fresh version that replaces it atomically. For: nearest to "nothing to do". Against: memory and copying; page-granular copy-on-write needs the machinery of chapter 6.
6. *Damage rectangles and a fence only,* as virtio-gpu has. For: standard; nothing to build. Against: no timing at the blank; the host decides.

**Precedents.** The C64's raster register *(unverified)*; the VGA retrace *(unverified)*; Linux page-flip and atomic ioctls with `DRM_MODE_PAGE_FLIP_ASYNC` *(verified: `drm_mode.h`)*; "vblank evasion" in a Linux graphics driver *(verified: `kernel-pain-points.md` 0.6 #13)*; HDMI VRR and adaptive sync *(unverified)*.

**The author's referents.** "with modern hdmi is tearing even a concern?"; the C64's raster interrupt; "Flip on vsync unconditionally with an overrun interrupt instead of a barrier" (`c64stuff.txt` line 5647).

**The assistant's leaning.** Option 6 for the standard device, and Options 1 and 3 together if a native scanout engine is ever built.

**Where the body refers to it.** Section 3.15.1.

<a id="j39"></a>
### J.3.9 The graphics boilerplate sugar

**Issue.** The author's goal: "basically, anything that made graphics programming annoying or cumbersome or boiler platey, we want to sugar away to almost nothing" and "graphics programming should be as simple and pleasurable as the c64 was" (errata 105). They are goals, not designs. The candidates are in the rows of the table of 3.14: a device that powers up in a sane default mode, in the monitor's preferred mode, which a register reports; a fixed canonical pixel format; stride equal to width; a framebuffer window always mapped; one colour space with the transfer curve applied by the device; cell and glyph sizes in physical units for HiDPI; a palette as an array in memory, or none; and one clock for sound and video.

**Why it matters.** Each one costs gates or flexibility, and the standard virtio-gpu device keeps its own protocol (five commands to put a picture up).

**Options.**

1. *Nothing in the architecture;* a library over virtio-gpu sugars it. For: no hardware. Against: every system writes its own.
2. *A default mode and a mode-report register,* the device reads the monitor itself. For: nothing to set. Against: a small I2C engine and a policy.
3. *A canonical pixel format with conversion at scanout.* For: no format to get wrong. Against: a conversion stage; wasted memory for fewer bits.
4. *Stride equal to width and the framebuffer window always mapped.* For: no `mmap`, no bank register. Against: a fixed place in the address space; a rule for two framebuffers.
5. *One defined colour space (linear or sRGB).* For: no gamma code. Against: the choice is open.
6. *Physical units for cells and fonts.* For: HiDPI without a scale factor in every program. Against: the TrueType engine must know the screen.

**Precedents.** VESA mode lists; Linux DRM/KMS; Vulkan *(unverified for the line counts, which are illustrative)*; virtio-gpu's `GET_DISPLAY_INFO` *(verified)*.

**The author's referents.** The Abrash books ("800 page michael abrash books"); the C64.

**Where the body refers to it.** Section 3.14.2.

<a id="j310"></a>
### J.3.10 A write-combining memory type for the framebuffer

**Issue.** The framebuffer is mapped uncached (3.11.1). An uncached single write is slow, and a long run is no slower per byte. A **write-combining** memory type (writes are gathered and sent as one burst) would make processor drawing faster. The four memory types of 2.3.3 do not name it.

**Why it matters.** It decides how fast pixel-by-pixel drawing from the processor is, and whether a fifth memory type is added.

**Options.**

1. *Uncached only.* For: simple; no stale data. Against: slow single writes.
2. *Add a write-combining type to the page-table entry.* For: fast runs. Against: a fifth type; ordering rules for a `FENCE`.
3. *Let the display's buffer be device memory with its own merge rules.* For: the device controls it. Against: depends on the device.
4. *Draw into cached memory and copy by the device.* For: fast drawing. Against: the cache must be cleaned, which chapter 2 removes.

**Precedents.** Write-combining types on x86 and ARM *(unverified: general knowledge)*.

**The author's referents.** None.

**Where the body refers to it.** Section 3.11.3.

<a id="j311"></a>
### J.3.11 The C128 core and the c64 mode

**Issue.** The c64 mode is decided (3.16.1, 3.16.2); what follows are its details. The author, 2026-11-10: "we will have a c64 mode, where a c128 is built onto the die with sid etc, so a bit of code loaded into its address space by pcie dma will let it act as a terminal the way the blit and vt55 did"; "the mode is just enabling/disabling the c128 as a pcie device so it takes over the graphics and audio output" (errata 105). The C128 is an optional PCI Express device, not part of the standard (errata 77). Open: which core (the C128 had an 8502, a Z80, the VIC-IIe, the 8563 VDC and a SID, with a memory-management chip); whether "c64 mode" runs unmodified C64 software or only terminal firmware; how video memory is shared with the host and with virtio-gpu; how the core and the host talk (a mailbox, a virtio device, a window of memory); how the loaded image is authenticated and contained (the IOMMU of errata 75 and 85 answers this for devices that master the bus; whether the core's DMA goes through it, whether the image is signed and who holds the key); how it relates to the deferred native devices (errata 78) and to "virtio across the board" (errata 95); its cost in gates (a 6502-class core is a few thousand gates, unverified); and how its sound reaches HDMI audio.

**Why it matters.** It decides whether the die holds a second machine, and whether the terminal is a program the host can replace, as in the Blit.

**Options.**

1. *A hard core on the die,* a real 6502-family core with the chips. For: fastest and smallest per core. Against: permanent area; fixes the idea in silicon before the questions are answered.
2. *A soft core in the FPGA phase only.* For: no silicon cost; the MiSTer framework does it. Against: gone from a later chip unless made hard.
3. *Software emulation of the C64 on a pdp64 core.* For: no hardware; easy to change. Against: uses a core; loses the C64's exact timing.
4. *None: the terminal is a virtio device served by a host process.* For: the standard route of errata 95. Against: departs from the decision that the C128 is built onto the die (3.16.1); the terminal is no longer a computer of its own, which the author values in the Blit.
5. *A core of the pdp64's own instruction set with the C64's registers.* For: one instruction set. Against: no C64 software runs.

**Precedents.** The Blit loaded its terminal program from the host *(verified: `kernel-pain-points.md` 14I; the protocol is unverified)*; the C128 held several computers in one box and MiSTer runs C64 and C128 cores in programmable logic *(unverified: general knowledge)*; the earlier device chat's "8502 compatibility island" (`docs/c64-devices-from-chat.md` section 4, nothing decided).

**The author's referents.** The Blit and the VT-series terminals; "a bit of code loaded ... by pcie dma"; the C128.

**Where the body refers to it.** Section 3.16.1.

<a id="j312"></a>
### J.3.12 The compositor path

**Issue.** The author prefers path 3 below, the core drawing into a buffer that the host's compositor treats as a surface (3.16.3); the other paths show what it was preferred over, and the open part is the details of path 3. A **compositor** is the program or hardware that combines the pictures of several windows or sources into the one picture that is scanned out. The author wrote of the c128 that it "takes over the graphics and audio output... or sends them to a compositor. not sure what that would look like. is there virtio-compositor?", and later "c128 drawing into a buffer makes most sense" (errata 105, 106: a stated preference, not a decision). No virtio device is a compositor: `virtio_ids.h` lists GPU (16), input (18), sound (25), video encoder and decoder (30, 31), DMA buffer (37) and audio policy (39). The nearest parts are up to 16 scanouts, `SET_SCANOUT_BLOB`, a separate cursor queue and capability sets. Open under the preferred path: how the compositor learns that the buffer is the core's, who owns the copy or shared memory, and how the core's frame timing meets the compositor's; and how the switch avoids a tear and a pop (a hand-over at a vertical blank and a short mute ramp).

**Why it matters.** It decides whether the core is a screen of its own or a window of the host's.

**Options.**

1. *Exclusive takeover.* The core owns scanout 0 and the audio path. For: an enable bit and a mute. Against: the host shows nothing meanwhile.
2. *One more virtio-gpu scanout and virtio-snd stream.* For: nothing new; the shape of errata 95. Against: the core must speak the protocols.
3. *A surface for the host's compositor* (the author's preference). The core renders into a resource or blob. For: a window with the host's window management. Against: the compositor must know the surface is the core's; a copy or a shared blob.
4. *Layers at scanout.* For: no copy; per-layer latch. Against: needs the layered display of J.3.3.
5. *A new virtio device type for compositing.* For: one model for every client. Against: a specification to write and have accepted, and a driver for every host; it repeats what virtio-gpu says.

**Precedents.** QEMU's `virtio-gpu-rutabaga`, "gfxstream rendering and Wayland display passthrough" *(verified: `docs/system/devices/virtio/virtio-gpu.rst`)*; crosvm shows a guest's windows as windows of the host's Wayland compositor *(unverified: general knowledge)*.

**The author's referents.** "c128 drawing into a buffer makes most sense" (errata 106); rio's windows as buffers.

**Where the body refers to it.** Sections 3.16.2 and 3.16.3.

<a id="j313"></a>
### J.3.13 Audio mixing

**Issue.** A **mixer** combines the sound of several programs into the one stream a converter takes: it converts each stream to a common rate and format (resampling), applies a volume, sums and limits, balances latency against underrun and absorbs clock drift. virtio-snd defines one stream at a time, as one card, and says nothing about who mixes; QEMU mixes on the host. The pdp64 is a machine where the mixing may have no host. The author asked "what do those mixers do to combine multiple programs audio?" (errata 106). For the audio of a c64-mode core (J.3.11) the options parallel those for pixels: exclusive takeover; the core's voices as a virtio-snd stream that the host mixes (needs the 48-bit sample path of errata 74); a fixed-gain mix in the device; and a fade over a few milliseconds at hand-over so that no pop is heard.

**Why it matters.** It decides who resamples and whose clock rules, and whether two programs can play at once on the first board.

**Options.**

1. *The kernel mixes.* For: one place; programs see one stream. Against: kernel code and floating-point or fixed-point work in the kernel.
2. *A library mixes in the program* (as a sound server does). For: policy outside the kernel. Against: only one program may hold the device; a server is needed.
3. *The device mixes.* For: no CPU time. Against: gates for rate converters; a fixed policy.
4. *A mixing process with the device's clock driving it,* as PipeWire and PulseAudio do. For: a proven design. Against: a user-level server.
5. *One stream only,* no mixing at all. For: nothing to decide. Against: no two programs at once.

**Precedents.** PulseAudio, PipeWire, ALSA `dmix`, CoreAudio and WASAPI shared mode *(unverified: general knowledge; the programs `pulseaudio` and `libasound` are present on this machine)*; QEMU's mixing engine `audio/mixeng.c` *(verified: the QEMU sources)*; virtio-snd as one stream *(verified: `virtio_snd.h`)*; the SID mixes its voices inside itself *(unverified)*.

**The author's referents.** "what is the audio equivalent, what do those mixers do to combine multiple programs audio?"; the SID.

**Where the body refers to it.** Section 3.17.1.

<a id="j314"></a>
### J.3.14 Windows

**Issue.** The author: "it should mention blit terminal was inspiration for the rio and NeWS windowing systems, and we'd like to bring over what we can of that simplicity also" (errata 106). The Blit's `mux`, Plan 9's 8½ and rio, and NeWS are in 3.18. That the pdp64 brings over what it can of their simplicity is decided (3.18.1); which of their simplicities, and in what form, is open.

**Why it matters.** It decides what a program calls to put a window on the screen, and what the kernel provides.

**Options.**

1. *A window is a plain buffer and a rectangle.* For: drawing is writes to memory. Against: a buffer a window (memory); a rule for who may write whose.
2. *Drawing is writes to that buffer,* with no drawing protocol in the base system. For: no round trips. Against: every program draws for itself; a library must exist.
3. *The server composes the buffers* (a small program or the display hardware). For: one place for overlap, flip and tear. Against: a copy or a layer per window; trust.
4. *Downloadable server-side code,* as the Blit and NeWS had, here into the core of J.3.11. For: new abilities without changing the host. Against: a second program to secure; the Blit's "two halves" problem.
5. *No toolkit in the base system.* For: the size rio had. Against: every program has its own look.
6. *Windows as files, or as virtio queues.* For: the uniformity of rio and 8½. Against: a naming and permission model (chapter 6) or a queue per window.

**Precedents.** The Blit's `mux`; 8½ and rio *(verified: `kernel-pain-points.md` 14I)*; NeWS as an extensible window server *(verified as quoted from the UNIX-HATERS Handbook, `kernel-pain-points.md` 14G; that it was Sun's, in PostScript, by Gosling is unverified)*.

**The author's referents.** The Blit, rio and NeWS; "that simplicity".

**Where the body refers to it.** Section 3.18.1.
