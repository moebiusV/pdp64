# 3. Graphics: the terminal and its devices

[← manual index](00-index.md)

> **Iteration two.** The devices of this chapter (the video device with its 48-bit RGBA pixel, the sound device with 48-bit samples, the blitter, and the eight-register face) are planned for the future, with the author's 12-register network, sound and graphics cards (errata 75). The first iteration uses virtio-gpu and virtio-snd over PCI Express (errata 79 and 95); this chapter describes what follows them. Statements keep their tags; the decisions of errata 73 and 74 stand. Errata 105 and 106 record the author's requests for the chapter and what is still open in it.

**The pdp64's display is meant to bring back what the Blit terminal and the Commodore 64 had, text and graphics on the screen at once, set by simple stores to memory, at a modern colour depth and screen size; its output is HDMI or another standard graphics output; its form is not yet fixed, and the standard device of the first iteration is virtio-gpu.** The chapter is written for a reader who knows the PDP-11 and its teletype, or who is learning computing from the start, and who has met nothing invented after the 1970s. It follows the order in which the ideas arrived, because each one answers a complaint about the one before:

| Stage | What it contributed | Section |
|---|---|---|
| PDP-11 teletype (KL11) | a stream of characters, one line at a time | 3.1 |
| VT52, VT100 (the author's "vt55") | a screen the program can address by position, through escape codes | 3.2 |
| Blit (Bell Labs, 1980s) | a bitmap in the address space, the bit-block-transfer, a terminal that runs downloaded programs | 3.3 |
| Commodore 64 (1982) | text, bitmap, sprites and sound together, all set by pokes | 3.4 |
| VGA, SVGA, VESA | memory-mapped text and pixels again, but planes, banks and no sprites | 3.5 |
| GPU | vertices, shaders and command buffers; the text path of every terminal emulator | 3.6, 3.7 |
| pdp64 terminal | the Blit and the C64 at a modern depth, with glyph slots | 3.8 to 3.15 |

After the terminal come the problems that made graphics programming annoying (3.16), tearing (3.17), the author's idea of a C64-mode core (3.18), audio (3.19), windows and compositors (3.20) and the open mashup that ends the chapter (3.21). The PDP-11 had a teletype and nothing else of this chapter; where a later topic has no PDP-11 antecedent the text says so. Tags: *(D)* decided; *(P)* proposed; *(S)* stub (not specified). A fact that could not be checked on this machine is marked *unverified* and listed in 3.22.

*How to read this chapter.* A term is defined where it first appears, as the technical word and a plain restatement. In the boxes-and-arrows figures a box is a piece of memory and an arrow an address or index stored in it. Code blocks are pseudocode (C-like; `poke(address, value)` and `peek(address)` are an ordinary store and load, as in chapter 2) unless marked PDP-11 assembly. The numbered statements are the rules; the history and explanation are unnumbered prose, as in chapter 2.

## 3.1 The teletype: one line at a time

A PDP-11 in 1975 talked to a person through a **teletype** (a keyboard and a printer on one machine, joined to the computer by a serial line: characters go one after another along a single wire pair, each as a short burst of bits). The machine knew nothing about the page. A character went out and the printer put it to the right of the last one; a carriage-return character moved the print head back to the left margin and a line-feed character moved the paper up one line. Nothing could be erased, because the ink was on paper. This is **line-at-a-time output**: the program's only notion of position is "the end of what I have printed".

The hardware was a Unibus device like those of chapter 2: a few registers. The console of 2.11BSD is a KL11/DL11, declared in `sys/pdp/cons.h` as four words (receive status, receive buffer, transmit status, transmit buffer) at address 0177560 (`cnaddr` in `cons.c`); the transmitter-ready bit of the transmit status word is `DLXCSR_TRDY`, 0200 (both checked in the 2.11BSD tree on this machine, where the files are stored gzipped). Printing a line was a loop that waits for ready and stores a byte:

```
print_line(string):
    for each byte c in string:
        while (peek(XCSR) & TRDY) == 0:     # the printer is slow: ten characters a second or so (unverified)
            wait
        poke(XBUF, c)
    poke(XBUF, CR); poke(XBUF, LF)          # carriage return, line feed
```

and in PDP-11 assembly, with the console's register addresses (transmit status 0177564, transmit buffer 0177566, the third and fourth words of the structure; the loop is in the style of the `rk` driver of chapter 2, not copied from a driver):

```
        MOV  #msg, R0
1$:     MOVB (R0)+, R1        ; next character; R0 now points at the one after
        BEQ  3$               ; a zero byte ends the string
2$:     TSTB @#177564         ; XCSR: bit 7 is READY
        BPL  2$               ; plus: not ready, look again
        MOVB R1, @#177566     ; XBUF: this sends it
        BR   1$
3$:
```

Everything a program can say to such a device is a stream of characters. The Unix **tty** (short for teletype: the device file that a program reads and writes characters from and to) is therefore a stream, and the programs written for it, the shell, the editor `ed` and the compiler's messages, think in lines. The stream has no way to say "put this here", which matters as soon as the printer is replaced by a screen.

## 3.2 The glass teletype and its escape codes

A **video terminal** is a keyboard and a screen on the end of the same serial line. At first it imitated the teletype (the "glass teletype": characters appear at the bottom and the page scrolls up). Then it did what paper could not: move the cursor to any place and change what was there. The program asked for this with **escape sequences** (characters that the terminal obeys instead of displaying, introduced by the escape character, code 27, written ESC), so the stream carries both text and commands.

Two generations matter here. The DEC VT52 is the textbook example of the problem, and the author's chat of 2026-06-18 (`c64stuff.txt`, line 4888, the assistant's words) records its cursor-to-position code: ESC Y, then a row character and a column character, each with 32 added so that the numbers arrive as printable characters. In pseudocode:

```
goto(row, col):
    send(ESC); send('Y'); send(row + 32); send(col + 32)   # the VT52 form, as recorded in the chat
send_string("Hello")                                       # the text appears at the cursor
```

The later DEC VT100 and the ANSI standard that followed it use ESC, an opening square bracket, numbers and a letter: `ESC [ 12 ; 40 H` moves the cursor to row 12, column 40, and `ESC [ 31 m` makes what follows red (these two sequences are general knowledge, *unverified* here). The chat records only that "VT100/ANSI" and the "xterm-256color" subset are what ordinary programs speak (`c64stuff.txt`, lines 218 and 4875).

The author's request names a "vt55" between the teletype and the Blit. No text in the repository mentions a VT55; the records name the VT52 and the VT100, so the chapter describes those. (The DEC model of that number was a graphics terminal, which would fit the author's order; that is general knowledge and *unverified*.)

The escape-code terminal gave a **character-cell display** (a screen that is a grid of cells, 80 columns by 24 rows being the usual size, each holding one character) that a program could address by position. It gave no control over the shape of a character, no drawing, no mix of fonts, and it kept a slow serial line between the program and the screen, speaking escape codes that differed from one make to the next. Unix answered the variety with a database of terminal descriptions (**termcap**, then **terminfo**: a file saying, for each make of terminal, which bytes mean "move the cursor") and a library (**curses**: a program that works out the fewest bytes to send to turn the screen as it was into the screen as wanted). *The UNIX-HATERS Handbook* complains of this (chapter 6, "Original Sin", recorded in `docs/kernel-pain-points.md`, section 14G: "Unfortunately for us, Unix was designed in the days of teletypes"). Each change to a cell cost several bytes of command over a slow line; the Blit answered that.

## 3.3 The Blit: a bitmap, and the blit

The Bell Labs terminal called the **Blit** (Rob Pike, Bart Locanthi and John Reiser; the repository records their papers as *Blit 1983* and *Tradeoffs 1985* in `docs/kernel-pain-points.md`, section 14I) took the opposite course. Instead of obeying commands about a grid of characters it had a **bitmap display** (a screen in which every dot, every pixel, is one or more bits in memory, so a program draws anything by changing bits) and a Motorola 68000 processor at 8 MHz to do the drawing: "256K bytes of memory dual-ported between an 800×1024×1 bit display and a Motorola MC68000 microprocessor". The screen memory was in the processor's address space like any other memory, and a program changed the picture by storing into it.

A bitmap is a picture stored row after row (the figure in 3.5 shows it). The operation that makes it usable is the **bit-block-transfer**, written **bitblt** and said "bit blit": copy a rectangle of bits from one place to another, combining each source bit with the destination bit by a chosen rule, the **raster operation** (RasterOp: the bit-by-bit rule that gives the result, such as "replace", "OR" or "exclusive-OR"). A rule of two inputs has sixteen possible forms; the Blit authors found that four sufficed (store, OR, clear, XOR), and XOR dominated its use, because drawing a shape twice with it erases it again, so a cursor moves without a saved copy of what was beneath it. With bitblt a program scrolls a window (copy the rectangle up by one line of text), moves a window (copy it), draws a letter (copy the letter's rectangle from a stored font to the screen) and fills an area. In pseudocode in the style of the Blit's library:

```
bitblt(source_bitmap, source_rect, destination_bitmap, destination_point, operation)
bitblt(font, rect_of('A'), screen, (x, y), OR)       # draws an A with its top left at (x, y)
bitblt(screen, window_rect, screen, window_rect + (0, -line_height), STORE)   # scroll one line
```

The Blit was a small computer, not a protocol. Its authors give the reason: "To draw graphics in the windows, sending escape sequences is traditional but makes poor use of the processing power of the terminal"; an earlier terminal that interpreted escape sequences failed because "too much state information was maintained by the terminal and guessed at by the Unix program". The host sent it programs over an RS-232 serial line, and the authors name that line as the weak point: "The greatest problem, though, is certainly the low bandwidth." The pdp64 keeps two lessons from it: the framebuffer is in the address space, and the blit is an assist that can be bypassed (3.8.6).

On the author's account the Blit inspired rio (Plan 9) and NeWS (Sun's); the sources confirm the line from the Blit's `mux` through 8½ to rio. Section 3.20 says what they were and what the pdp64 could carry over.

The Blit also raises a question the pdp64 inherits. It drew its cursor in software, in XOR, redrawing it at 60 Hz (`kernel-pain-points.md`, section 14I); other machines had **sprites** (small pictures that the display hardware overlays on the screen at a position the program gives, without touching the screen memory beneath). The next machine had eight of them.

## 3.4 The Commodore 64: text, graphics, sprites and sound together

The Commodore 64 (1982) was a home computer with a 6510 processor (a 6502 with a few input and output lines added) and two custom chips, the **VIC-II** (video interface chip) and the **SID** (sound interface device); every figure in this section is general knowledge, *unverified* here. It was built for games, and a game needs a scrolling background, characters moving over it, colour, music and noise at once. The chips read their data from memory by themselves, and every control is a memory location that the programmer can **peek** (read a byte) or **poke** (write a byte): the names are the C64 BASIC commands for a load and a store, and the source of the author's phrase "peek poke style".

![The C64 address space](figures/gfx-c64-map.svg)

**Text mode.** The standard screen is 40 columns by 25 rows, 1000 cells. The picture is *two* arrays in memory: screen memory, 1000 bytes, normally at $0400 (the number of the glyph for each cell), and **colour RAM**, 1000 four-bit entries at $D800 (the colour of each cell, one of 16). The shape of each glyph is not in these arrays; it is in the **character ROM** (a read-only memory of 8 bytes a glyph, one byte a row of eight dots, 256 glyphs: 2 KB for one set), which the video chip reads, and which a program can also replace by pointing the chip at glyphs it has made in RAM. To put an A at the top left, in red, the BASIC programmer writes two pokes, and the video chip, which reads screen memory sixty times a second by itself, shows it (screen codes, colour numbers and addresses *unverified*):

```
poke(1024, 1)          # $0400: screen code 1 is the letter A
poke(55296, 2)         # $D800: colour 2 is red
poke(53280, 0)         # $D020: the border colour, black
poke(53281, 6)         # $D021: the background colour, blue
```

This is the "peek poke" model: the screen is memory, a cell is an address, and the chip does the display. There are no escape codes and no stream; a program that pokes address 1024 + 40 * row + column has put a character there, at any time, in any order.

**Bitmap mode.** The same chip could show a bitmap of 320 by 200 dots in memory, with colour attributes per 8 by 8 block, and **multicolour** modes that trade width for colour. These were modes of one chip, and a program could mix them, text in one band of the screen and graphics in another, by changing mode at a chosen line (the raster interrupt below).

**Sprites.** The VIC-II had eight **sprites**: movable objects of 24 by 21 dots, each described by 63 bytes of data in memory, a pointer byte (the last eight bytes of screen memory, $07F8 to $07FF, say which 64-byte block holds each sprite's shape) and a few registers (x position, y position, colour, enable, size, priority; collision registers that say which sprites touched). The chip draws the sprites over the background as the picture is read out; to move a sprite, the program changes two registers, and the picture underneath is never disturbed. A ship, a bullet and an enemy are each a sprite, and a game's movement is a handful of pokes per frame.

**The raster and the raster interrupt.** The VIC-II draws the screen by reading it in order, row by row, while an electron beam sweeps the tube (the **raster**; the whole sweep is a **frame**, 50 or 60 times a second depending on the television standard). A register holds the number of the line being drawn, and another can be set to a line number so that the chip interrupts the processor when the beam reaches it: the **raster interrupt**. Programs used it to change a register mid-screen, such as the background colour or a sprite position, and to make changes while the beam was elsewhere (3.17).

**Sound.** The SID is a three-voice synthesiser with filters, again with registers that the programmer pokes: a voice has a frequency, a waveform (triangle, sawtooth, pulse, noise), and an attack, decay, sustain and release envelope. A note is a handful of pokes. Sound came from the same few chips, controlled the same way: **one machine, one address space, a few chips whose registers are memory, and a program that sets them directly**.

The C64's limits are those of 1982: 16 colours, 40 columns, 8 by 8 cells, 8 sprites, three voices. The author asks for the same ease without them (3.8).

## 3.5 The PC years: VGA, SVGA, VESA

The IBM PC took a different road: its video adapters were separate cards with their own memory and registers, and the software model mixed memory with input/output ports (separate I/O instructions, which neither the PDP-11 nor the C64 had). The **VGA** (Video Graphics Array, IBM, 1987) became the baseline that later adapters imitated. Everything in this section about the PC adapters is general knowledge, *unverified* here.

**VGA text mode.** The text mode is the C64's idea with the colour folded into the cell: 80 columns by 25 rows, 2000 cells, in memory at 0xB8000, two bytes a cell: the character code and an **attribute byte** (four bits of foreground, three of background and one bit for blink, or for a bright background). The shapes come from a font in the adapter's own memory, which a program can replace. To put a red A at the top left:

```
poke(0xB8000, 'A')          # the character
poke(0xB8001, 0x04)         # attribute: black background, red foreground
```

![A VGA text-mode cell](figures/gfx-vga-cell.svg)

**VGA graphics.** The same card had graphics modes, and here the trouble began. Mode 13h (320 by 200, 256 colours, one byte a pixel, at 0xA0000) was the easy one: the framebuffer is a single array and a pixel is the byte at y * 320 + x. A byte names one of 256 palette entries, and the palette (a table of 256 colours that the program loads through I/O ports) is in the card. Modes with 16 colours and higher resolutions were **planar**: the four bits of a pixel's colour were stored in four separate **planes** (four arrays, the same pixel position in each), and a write reached whichever planes the registers selected. That was fast for some operations and a puzzle for the rest. The adapter's window onto its memory was 64 KB at 0xA0000, so any picture larger than 64 KB needed **bank switching** (the card has more memory than the window shows; a register chooses which 64 KB slice appears in the window, and the program must change the register whenever its drawing crosses a slice boundary).

**SVGA and VESA.** Every manufacturer's Super VGA added modes (800 by 600, 1024 by 768, more colours) and, since there was no standard, each used its own registers to switch to them and to select a bank. **VESA** (a standards body of display makers) wrote the **VBE** (VESA BIOS Extensions: calls into the adapter's ROM that list the modes, set one, and switch banks), and a later version let the card present its whole memory as one **linear framebuffer** at a high address, ending the banks. The result is a block of memory, a **width** and **height** in pixels, a number of bits per pixel, and a **stride** (also called pitch: the number of bytes from the start of one row to the start of the next, which can be more than the width times the bytes per pixel, because rows are padded to a convenient boundary).

![A framebuffer with a stride](figures/gfx-framebuffer.svg)

**What the programmer had to know.** A graphics programmer of the late 1980s and the 1990s carried all of this: the VGA registers, set through ports, that choose which planes a write reaches and how its bits combine with what is already there; the planar layout, with one pixel's colour spread over four arrays; **Mode X** (the games community's name for an unofficial VGA mode of 320 by 240 that used the planar memory for more than one screen of pixels and faster fills); the bank register of each Super VGA chip, which differed from chip to chip, with quirks that the VESA calls hid only in part; the palette, whose entries could be rewritten to cycle or fade colours without touching the picture; the **retrace**, because a change made at the wrong moment tore the picture; and hand-written assembly **inner loops** for the fill, the copy and the line, because a few cycles a pixel decided whether a game ran. The author's referent is the books of Michael Abrash on PC graphics programming: "still, is ok to mention the problems graphics coders faced, which is why we had 800 page michael abrash books" (errata 105). The titles, dates and page counts are *unverified*; no copy is on this machine and no record in the repository names a title. The depth of those books measures what the hardware pushed onto the programmer. The pdp64's aim (3.16) is that the program needs none of it.

**The uncomfortable split.** The PC now had two worlds. In **text mode** the hardware drew the characters, so text was fast, small (4000 bytes) and easy, and nothing else could be on the screen. In **graphics mode** a program could show anything but drew every dot: even a letter was the program's job (copy its rectangle from a font, the Blit's bitblt in software), and text became slow and ugly. Changing between the two meant switching modes, blanking the screen and losing the conveniences of the other world. The C64 had mixed text, bitmap and sprites in one frame; the PC made the programmer choose. Windowing systems, which need both together, chose graphics and drew everything.

**Why sprites vanished.** The VGA had no sprites, so games of its era drew every moving object into the framebuffer in software, while a second copy of the screen was being prepared (3.17). The processor was by then fast enough to move a screenful of dots in a frame time, the framebuffer was ordinary memory that any program could write, and windowing systems composed overlapping windows in software, which left no use for a hardware plane or sprite. The cost was real: moving a mouse cursor, a ship or a window meant writing and restoring pixels while the display was reading the same pixels (3.17).

## 3.6 The GPU: pipelines, vertices, shaders

In the 1990s a new kind of chip took the drawing from the processor: the **GPU** (graphics processing unit), first for three-dimensional games and now for every screen (general knowledge, *unverified* here, as is the rest of this section). Its design follows from what a three-dimensional scene is: a list of **vertices** (points in space with a position, and perhaps a colour, a direction the surface faces and a place in a picture), joined into **triangles** (three vertices: the one shape that is always flat, so any surface can be built from them), seen by a camera. To draw it, the machine must (a) work out where on the screen each vertex lands, (b) find which pixels each triangle covers (**rasterization**: turning a shape into the set of pixels it covers), and (c) decide each pixel's colour, which is usually where a **texture** (a picture stored in memory, which is looked up at a position given by the vertex, to paint a surface with, say, brick) comes in. The three steps are the **graphics pipeline**.

![The graphics pipeline](figures/gfx-pipeline.svg)

The early GPUs did each step in fixed hardware. The change that made the current GPU is that two of the steps became **programmable**: the programmer supplies a **shader** (a small program, in a special language, that the GPU runs; the name is historical, because shaders began as programs that computed the shading of a surface). A **vertex shader** runs once for every vertex and says where it goes; a **pixel shader** (also called a fragment shader) runs once for every pixel a triangle covers and says what colour it is. The rasterizer between them stays fixed, because it is the same arithmetic for every program.

**Why a GPU is fast.** A processor core runs one thread of arbitrary code as fast as it can, with a deep pipeline, large caches and logic to guess and reorder. A GPU is built for *the same small program run on a very large number of independent items*: a million pixels each need the same few dozen instructions. So it has thousands of simple **lanes** (units that each do arithmetic on one item), grouped so that 32 or 64 lanes (the size varies by maker) execute one instruction at the same time on different data (**SIMD**: single instruction, multiple data), and memory of very high **bandwidth** (bytes per second) feeds them. When one group waits for memory the hardware switches to another. Three more things matter in practice. The CPU does not touch pixels: it writes a **command buffer** (a list of commands in memory, such as "bind this texture, use these shaders, draw these 3,000 vertices as triangles") that the GPU reads and carries out by itself, like the descriptor rings of chapter 2. Work is **batched**: one command draws thousands of things, so its cost is paid once. And textures are stored in a layout that keeps neighbouring pixels close together, with the filtering done in hardware.

The GPU is poor at code with many decisions or with items that depend on each other, and the programmer must describe the whole job as a pipeline, write shaders and feed it in large batches. Section 3.16 shows how much graphics boilerplate comes from that model.

## 3.7 Why a terminal emulator uses the GPU, and why a font needs three dimensions

A **terminal emulator** (a program that shows a grid of text in a window of a graphical desktop and acts like the VT-series terminal of 3.2) has a small job: a grid of cells, each a glyph with a foreground and a background colour. Alacritty, kitty and WezTerm draw that grid on the GPU (general knowledge, *unverified* here; the author's chat names kitty). Why would a program that shows only text use machinery built for three-dimensional games?

**How a GPU draws text.** A screen of text is the same glyphs over and over. The program draws each glyph once, with a font rasteriser, into a **glyph atlas** (one texture holding every glyph the screen uses, side by side), then describes the screen as a list with one entry per cell: its position, the part of the atlas to show, and the two colours. The GPU draws each cell as a **quad** (a rectangle of two triangles) textured with that part of the atlas, and the pixel shader mixes foreground and background by the glyph's value at each pixel. The whole screen is **one draw call** (one command that draws a whole list).

![A glyph atlas and a screen grid of quads](figures/gfx-atlas.svg)

The processor never touches a pixel. It changes a cell in the list when the text changes, and scrolling a line is a change of one number (where the list starts) or a shift of the list, not a copy of two million pixels. The glyph is stored as coverage values, so the shader can place it at a fraction of a pixel and blend it: **antialiasing** (smoothing an edge by giving the pixels it crosses an in-between colour) and **subpixel positioning** (placing a glyph more finely than the pixel grid). The GPU does this from its own memory, and the processor stays free to run the program whose output is shown.

**Why a font needs the three-dimensional machinery.** There are two parts to the answer. First, a glyph in a TrueType font is not a bitmap but an **outline** (curves in a coordinate system independent of size), and turning it into pixels is **rasterization** again, the job the GPU's rasterizer does for triangles. A font rasteriser on the processor produces the atlas once; the GPU can also do the curves itself, by tessellating the outline into triangles, by testing in the pixel shader whether each pixel is inside the curve, or by storing a **signed distance field** (a texture in which each pixel holds its distance to the nearest edge of the glyph, positive outside and negative inside, so a pixel shader draws the glyph sharply at any size from a small texture; credited to a Valve paper of 2007, *unverified*). Each is the 3D pipeline used on a flat shape.

Second, the pipeline is three-dimensional only by convention. A current GPU has **no 2D mode**: the 2D accelerator of the 1990s, with its blits, line draws and rectangle fills, is gone from the hardware, and drivers draw a rectangle as two triangles with a shader (general knowledge, *unverified*). A flat picture is the case of the 3D machinery in which every z value is the same and the camera looks straight on. A flat-rectangle engine would be smaller and would do the terminal's job; it is not built because the GPU has to handle the harder case anyway. That is how the terminal ends up on the 3D chip, and why the pdp64, which need not have a 3D chip, must decide what to put in its place (3.21).

## 3.8 The pdp64 terminal: the C64's chips and the Blit's bitmap

The chain so far: the PDP-11 sent characters down a wire (3.1); the VT52 and VT100 let the program address a screen by position (3.2); the Blit put the bitmap in the address space and the C64 put text, sprites and sound behind pokes (3.3, 3.4); the PC split text from pixels (3.5); the GPU made drawing a pipeline of shaders (3.6). The pdp64 terminal takes the Blit's and the C64's side of that history. The graphics half of this section is a repository specification from before errata 78 and 95; the statements below keep their tags and 3.9 gives the author's newer description.

**3.8.1** The graphics terminal is based on two machines, not one: the **Commodore 64**, for its video and sound as chips with registers that a program writes, and the **Blit terminal** (Rob Pike's bit-mapped windowing terminal), for its framebuffer in the address space and the bit-block-transfer operation that moves rectangles of pixels. The pdp64 modernises and extends both. *(D)*

**3.8.2** The video device is the Commodore 64's video chip (the VIC-II) extended: a framebuffer in the address space with 48-bit pixels, scanned out through a line buffer. A pixel is RGBA with 12 bits per channel (errata 73, the author's decision of 2026-10-24); the pixel format is what is decided. The register formats and the other pixel formats are unspecified (3.11). *(D)*

**3.8.3** The sound device is the C64's sound chip (the SID) extended: voices with filters, and also a general sound path that is not limited to the SID's voices; audio samples are 48 bits (errata 74, the author's decision of 2026-10-24); the sample width is what is decided. The register formats and the layout of a 48-bit sample are unspecified (3.11). *(D)*

**3.8.4** The blitter, the Blit's bit-block-transfer operation as a device, copies and combines rectangles of pixels with raster operations: registers for the source and destination base addresses, the strides, the width and height, a raster operation (the sixteen binary operations of source against destination and the common ternary ones), a mask or transparent colour, and a control register with direction, go, busy and interrupt on done. The device chat chose a three-operand `draw` instead (`decisions-pending.md` E3). The register list is the assistant's sketch from the ISA chat; the author has not discussed it. *(P)*

**3.8.5** Each of the three is a device in a slot: it is enumerated by the bus, mapped into its own 4 KB page, and found by its identification register like any other (chapters 2 and 5). The device chat put the C64 devices in one 8 KB window per process (`decisions-pending.md` E5). The slot and the page rest on the eight-register convention that errata 95 withdrew for the standard devices. *(P)*

**3.8.6** The framebuffer stays plain memory, so that software can draw without the blitter; the blitter is an assist that can be bypassed, not the only way to draw (the Blit authors' advice in 1985 was "transparent, so it can be bypassed"). *(P)*

**3.8.7** Four raster operations are required of the blitter: store, OR, clear and exclusive-OR (these four sufficed on the Blit, and exclusive-OR dominated its use); the other twelve binary operations and the ternary ones are optional. The requirement is the assistant's, from the Blit papers. *(P)*

**3.8.8** Whether the video device has a hardware cursor or sprite is unspecified (the vertical-blank interrupt is 3.8.9); the Blit read the mouse position at the retrace interrupt and drew its cursor in software, in exclusive-OR. *(S)*

**3.8.9** Every register of the video device that takes effect at a frame boundary is shadowed: one write to its `ARM` register latches them all together at the start of the next vertical blank, and a status bit says whether the arm was taken in this frame or missed it. A sticky underrun bit and an underrun counter report a scan-out that ran dry. The vertical-blank interrupt occurs at a fixed line of the frame, whose number a register holds. The sound path's audio clock relation (3.12.4) is part of the same mode setting. *(D)*

*Commentary.* **Chain.** The PDP-11 reached its terminal through a serial register pair (3.1). The Blit (1980s) put the bitmap in the address space and had a framebuffer in the address space and did the bit-block-transfer in software ("no pixel-moving hardware", Pike, Locanthi and Reiser, 1985); hardware blitters came later, on the Amiga and other machines of the 1980s (general knowledge, *unverified*). The Blit received downloaded code, characters and editing messages over a serial line and drew every pixel itself. The C64 (1982) put video and sound in chips whose registers a program pokes and whose screen memory the video chip reads by itself. No source read says that it preceded the X11 protocol; the lineage the sources confirm runs from the Blit's `mux` through 8½ to `rio` (`docs/kernel-pain-points.md`, section 14I). The pdp64 needs no display protocol between host and terminal, because the display is a set of devices on the bus; the nearest thing is the descriptor ring of chapter 5. The pdp64 takes the framebuffer and the operation from the Blit, adds a hardware blitter, and takes the video and sound chips from the C64. Plan 9 moved its window system into files (`/dev/bitblt`, later `/dev/draw`), a stream of small commands written to a device; that has the shape of a descriptor-ring entry (the comparison is an inference, not a source's statement).

**Trade-offs.** The blitter covers scrolling a terminal, moving a window, drawing a glyph, filling a rectangle and exclusive-oring a cursor; it does no three-dimensional graphics. `MCPY` is no substitute: it is one-dimensional and occupies the processor, where a blit has a stride and a raster operation and runs concurrently. The 48-bit pixel (four 12-bit channels, errata 73) probably exceeds what a display connector carries (unverified), so the display device converts to the connector's depth on the way out; likewise the 48-bit audio sample exceeds what a converter takes, so the sound device keeps the precision for mixing and filtering and reduces it at the output.

**Improvements.** The C64's video and sound registers were scattered and irregular; the pdp64 versions use the uniform register face, so one driver skeleton serves them (errata 95 removed that face for the standard devices, 3.9). **Benefits.** The blitter is about 1,500 lookup tables and a line buffer, nearly all address arithmetic (`docs/pdp64-fpga-plan.md`, line 316). **Modern comparables.** Display controllers in embedded systems commonly pair a scan-out engine with a blitter, and sound chips sit behind an I2S interface (general knowledge, *unverified*). **Impact.** *Kernel:* a framebuffer, a sound and a blit driver are each a mapped page and a few register writes; the uncached framebuffer needs no cache maintenance. *Compiler:* none. *Hardware:* a scan-out engine, a line buffer, an address-arithmetic unit for the blitter and a mixer for the sound device, each independent of the processor.

## 3.9 The terminal as the author describes it: peek/poke text and graphics, and glyph slots

The author, 2026-11-10: "our virtio-console device is an attempt to bring the nice properties of the blit terminal and c64 for doing simple and easy peek poke style display of text and also doing graphics, but with modern color depths and screen sizes, and with glyph maps we can even have a ttf engine generate glyphs and they will go into their memory slots for use."

**3.9.1** The pdp64's terminal is meant to bring the properties of the Blit terminal and the C64 that the earlier sections describe: a display that a program drives by simple peeks and pokes, for text and for graphics together, at modern colour depths and screen sizes; and a **glyph map** (a table of slots, each a place in memory for the picture of one glyph) that a TrueType engine fills, so that the shapes of the characters are made by software and used by the display through their slots. *(P)*

**3.9.2** What the author calls "our virtio-console device" is not specified in this repository: no document defines a device of that name, its identification, its queues or its registers, and the form of the terminal device (a new virtio device, an extension of virtio-gpu, or the native C64-derived family of 3.8) is **open**. *(S)*

*Why the name does not settle the form.* Errata 78 (2026-11-03) deferred the native C64-derived video, sound and blitter devices, and errata 95 (2026-11-09) dropped their model: "forget the native 8 register devices. gone. virtio across the board." The standard video and audio devices are virtio-gpu in 2D mode and virtio-snd (errata 79). The real **virtio-console** is a serial text device. The Linux header `virtio_console.h` on this machine shows device type 3 (`VIRTIO_ID_CONSOLE`), a configuration structure of `cols`, `rows`, `max_nr_ports` and `emerg_wr`, the feature bits `SIZE`, `MULTIPORT` and `EMERG_WRITE`, and control messages for ports (`PORT_ADD`, `PORT_REMOVE`, `RESIZE`); its data are byte streams, one receive and one transmit queue for each port (the queue layout is from the virtio specification, not the header, *unverified*), with no cells, colours, glyphs or pixels. The repository mentions it only as a candidate console for the boot ROM and kernel (5.7.1), a text stream like the teletype of 3.1. The author's "virtio-console" therefore names a device with cells, colours, glyph slots and graphics, which neither the real virtio-console nor virtio-gpu 2D has and which the native devices were to have. Four readings are possible, and the chapter chooses none: (1) a new virtio device type of the pdp64's own, with the cell array and glyph slots as the device's memory; (2) virtio-gpu extended by a text layer and glyph slots; (3) virtio-console as the text *stream* for existing tty programs (3.2) beside a separate display device; (4) the native device family renamed. This is the first question of 3.23.

**What the author's earlier terminal chat adds** (2026-06-18, `docs/c64-devices-from-chat.md` section 6; a separate project, not a pdp64 decision): a cell holds a 32-bit foreground colour, a 32-bit background colour, a UTF-8 character and about eight bits of attributes (bold, italic, underline, blink); "the number of cells take up so little memory, the 64 bits devoted to color is trivial"; "each cell holds its actual data, not a reference to the data"; sprites are a separate plane that composites over the cells; existing tty programs must run through a shim and native programs use the terminal fully, "peek and poke is the internal interface". That design fits the cell array of the figure below and differs from the author's new words in one place: **the chat-era cell holds the character code itself, while the glyph map of the new words implies a slot** (3.16, pair 3, candidate (a) against (b)).

![A cell array and a glyph slot table](figures/gfx-cells-glyphs.svg)

**3.9.3** A glyph map is a table of **slots**; a slot holds the picture of one glyph (for example, a rectangle of coverage values, one byte for each pixel, which tells how much of the pixel the glyph covers, so that the display can antialias), and the screen is an array of cells each of which names a glyph (by slot, or by a character code that is looked up to a slot) and gives its colours and attributes. A TrueType engine, which is software, rasterises a glyph from the font's outline at the pixel size of the display and writes the result into a slot; a glyph is made once and used by every cell that names it. The layout of the slot (its width, height, pixel format, and whether a slot may hold several cells' width, for a wide glyph) and the number of slots are unspecified. *(S)*

As an arithmetic example, with the chat-era cell (about 13 bytes: 4 + 4 + 4 for a character + 1 for attributes) and a 1920 by 1080 screen of 8 by 16 pixel cells, there are 240 columns and 67 rows, 16,080 cells and about 209 KB of cells; with slots of 16 by 32 coverage bytes (512 bytes) and 4,096 slots, the glyph map is 2 MB. Both are small against a 12.4 MB frame at 48 bits (3.13.2), which is the author's observation of 2026-06-18: the cells are small, and text is cheap to store. These are examples, not decisions.

**3.9.4** Whether the terminal has sprites is not stated in the author's description of 2026-11-10; the C64 had them and the earlier terminal chat gave sprites a separate plane, and statement 3.8.8 leaves the pdp64's hardware cursor and sprites unspecified. *(S)*

## 3.10 A peek/poke program for the terminal

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

Each line is one store, so the program is as small as the C64's was. Everything is memory, so `memcpy` fills a glyph slot as it fills any buffer. Compared with the list of 3.16 there is no mode setting, no format conversion, no flush (the memory type of 3.13.1 takes its place), no atlas to pack, no shader and no command buffer. The terminal does no three-dimensional graphics; for that the standard device, virtio-gpu, remains (3.14, 3.15).

## 3.11 The stub: the C64 and Blit documentation

**3.11.1** The register-level definitions of the terminal's video, sound and blitter devices (register names, offsets, bit fields, the 48-bit pixel and sample formats, the sprite, raster-interrupt and voice models inherited from the C64, and the bit-block-transfer operations and windowing model inherited from the Blit) are a stub: only the blitter registers listed in 3.8.4 are listed, and that list is the assistant's sketch, which the author has not discussed. The author's earlier device chat decided much of the rest (register conventions, the 8502 island, the display rules); it is extracted in `docs/c64-devices-from-chat.md` and awaits adoption (`decisions-pending.md` E1 to E11). *(S)*

**3.11.2** What is fixed: the devices exist, they follow the eight-register convention in the terminal's slots (errata 95 later withdrew that convention for the standard devices), and the interrupt, `FENCE` and uncached-framebuffer rules of section 3.13 apply. *(S)*

*Commentary.* This section is the placeholder for the C64- and Blit-derived specification. The Blit side can draw on the papers recorded in section 14I of `docs/kernel-pain-points.md`: the four primitives `bitblt`, `texture`, `segment` and `point`, the `Bitmap`, `Rectangle`, `Point` and `Texture` types, half-open rectangles, and overlapping windows with obscured parts kept off screen. **Impact.** *Kernel:* none until defined. *Compiler:* none. *Hardware:* the block RAM budget (3.13.3) is settled before the video device is built.

## 3.12 How the terminal drives HDMI and the other ports

**3.12.1** The display connector is standard kit: HDMI (and DVI and DisplayPort) is a transmitter chip that takes pixels and sync signals in parallel and does the link protocol, the encoding and the electrical signalling itself; on the first board it is the DE10-Nano's ADV7513, set up once over an I2C-style control bus. *(D)*

**3.12.2** The video device's output side is therefore a pixel stream with horizontal and vertical sync, a clock and a data-enable, which is what every such transmitter accepts; the device's registers set the mode (width, height, blanking, pixel clock, the pixel format), the base address of the framebuffer and the display on and off. *(P)*

**3.12.3** Other ports are the same shape: a different transmitter (VGA digital-to-analogue converter, DisplayPort, an LVDS panel) takes the same pixel stream, so the pdp64's side does not change, and each port is one more slot or one more output of the video device. *(P)*

**3.12.4** The sound device's output is likewise a standard digital audio stream (I2S or the HDMI audio channel) into a converter or the transmitter. The processor never sees the HDMI packets, but whoever sets the mode must also program the audio clock relation: the transmitter needs N (and CTS, or a hardware CTS calculation) for each pixel clock and sample rate (an ADV7511 driver computes both; general knowledge, *unverified*). *(P)*

**3.12.5** The ports that carry data, SATA for storage and USB for peripherals, follow the same pattern: the protocol is in the chip or controller block, and the processor's side is a slot with the common registers and a ring (chapter 5). *(D)*

*Commentary.* **Chain.** The PDP-11's output was the serial line of 3.1, with no display connector. The MiSTer framework on the DE10-Nano already works this way: the retro cores produce a pixel stream, and the framework's scaler and the HDMI transmitter do the rest, which is why the plan buys HDMI there. **Trade-offs.** The transmitter's control bus needs one-time setup, which a boot routine does with a few register writes; the pixel clock must be generated to the mode, with a phase-locked loop on an FPGA and the same block in silicon. **Improvements.** Replacing the transmitter or the connector changes nothing above the video device, as a SATA controller behind its ring can be replaced without changing the disk driver. **Benefits.** No part of the operating system carries an HDMI, SATA or USB protocol stack. **Modern comparables.** Single-board ARM computers with a display controller and an HDMI transmitter (general knowledge, *unverified*). **Impact.** *Kernel:* a display driver sets a mode and a base address; hot-plug of a monitor is a bus event if the transmitter reports one. *Compiler:* none. *Hardware:* a pixel generator, a clock and an off-chip transmitter, with no protocol logic in the pdp64's own gates.

## 3.13 The framebuffer, the memory type and the memory budget

**3.13.1** The framebuffer is mapped with the uncached memory type, or the processor's writes sit in the data cache while the video device scans out stale memory; a `FENCE` separates writing a device's registers from setting its go bit. *(D)*

**3.13.2** On the first board the block RAM (about 5.5 megabits on the DE10-Nano) cannot hold a modern frame (a 1920 by 1080 frame at 32 bits is 8.3 MB, and at the 48-bit pixel of 3.8.2 it is 12.4 MB), so the framebuffer lives in main memory and the block RAM holds the scan-out line buffer of a few kilobytes. *(D)*

**3.13.3** The block RAM budget (caches, translation buffer, the blitter's scratch and the sound voices' state) is settled before the video device is built. *(D)*

**3.13.4** The framebuffer is ordinary memory and the devices' registers are device windows (section 2.3.6), so a page-table entry that maps the framebuffer as a device, or a register page as cached memory, is a mistake that the memory type of the page makes visible to the kernel. *(P)*

*Commentary.* **Chain.** The PDP-11 had no framebuffer; whether the 11/70's cache watched Unibus writes so that DMA looked coherent is *unverified* (2.5, commentary). The VAX Unibus adapter's buffered data paths needed purging (2.5), and ARM and MIPS systems with non-coherent DMA place cache maintenance in the kernel (*unverified*). The pdp64 chooses the memory type instead (2.5.2). **Trade-offs.** An uncached framebuffer makes a single pixel write slow and a long run of writes no slower per byte. That suits the blitter, which writes the bus directly, and punishes pixel-by-pixel drawing from the processor. **Modern comparables.** Write-combining memory types on x86 and ARM serve the same purpose (general knowledge, *unverified*). **Impact.** *Kernel:* the mapping rule is one memory-type value in the page-table entry. *Compiler:* none. *Hardware:* the scan-out reads main memory by bus mastering and competes with the processor for bandwidth.

## 3.14 virtio-gpu: the standard graphics device

The first iteration's display (errata 79: "virtio is fine"; virtio-gpu in its 2D mode) is a virtio device like the disk of chapter 2, so 2.7 applies: it is found by enumeration, its queues are rings of descriptors in memory, and the work is commands in a queue. The commands below are from the Linux header `virtio_gpu.h` and from QEMU's `hw/display/virtio-gpu.c`.

**The vocabulary.** A **resource** is a picture that the device owns, named by a number the driver chooses (`resource_id`), with a pixel format, a width and a height. Its **backing** is the driver's own memory that holds the pixels: a list of `{addr, length}` entries (`struct virtio_gpu_mem_entry`) naming the pages. A **scanout** is one output of the device (up to `VIRTIO_GPU_MAX_SCANOUTS`, 16, in the header); `SET_SCANOUT` says which resource, and which rectangle of it, an output shows. Two commands move and show the pixels: `TRANSFER_TO_HOST_2D` copies a rectangle of the backing memory into the device's picture, and `RESOURCE_FLUSH` tells the device that a rectangle changed and should be shown. The pixel formats are 32 bits with 8 bits a channel (eight in the header): `B8G8R8A8_UNORM`, `B8G8R8X8_UNORM`, `A8R8G8B8_UNORM`, `X8R8G8B8_UNORM`, `R8G8B8A8_UNORM`, `X8B8G8R8_UNORM`, `A8B8G8R8_UNORM`, `R8G8B8X8_UNORM` (values 1 to 4, 67, 68, 121 and 134; the names give the channel order, the *colour order* annoyance of 3.16). Every command starts with a `virtio_gpu_ctrl_hdr`: a type, flags, a 64-bit fence id, a context id and a ring index; the flag `VIRTIO_GPU_FLAG_FENCE` asks that the response carry the fence id once the work is done, which is the device's only completion-ordering tool. The rectangle is `struct virtio_gpu_rect`: x, y, width, height, four 32-bit numbers.

![The virtio-gpu command sequence](figures/gfx-virtio-seq.svg)

```
# the whole of a virtio-gpu 2D start-up and one update, as pseudocode over the queue of chapter 2.7
send(RESOURCE_CREATE_2D,     resource_id=1, format=X8R8G8B8, width=1024, height=768)
send(RESOURCE_ATTACH_BACKING, resource_id=1, entries=[{addr=PAGES, length=1024*768*4}])
send(SET_SCANOUT,            scanout_id=0, resource_id=1, rect={0,0,1024,768})

draw_into(PAGES)                                       # the driver writes pixels: ordinary stores
send(TRANSFER_TO_HOST_2D,    resource_id=1, rect={0,0,1024,768}, offset=0)
send(RESOURCE_FLUSH,         resource_id=1, rect={0,0,1024,768})
```

In QEMU's `virtio-gpu.c`, `transfer_to_host_2d` rejects a rectangle that is not inside the resource with `VIRTIO_GPU_RESP_ERR_INVALID_PARAMETER`, then copies it **row by row** from the backing into the resource using the resource's stride, or in one copy if the rectangle spans whole rows. `resource_flush` rejects a rectangle outside the resource the same way, then asks each scanout showing the resource to update the part of its display that the rectangle covers. The transfer is the **upload** and the flush is the **present**, and the program does both after drawing.

**What it does not define.** Neither the header nor the QEMU function mentions the vertical blank, a page flip, a refresh rate or tearing: the flush says "show this rectangle now" and the host decides when its display next reads it. The only timing handle is the fence of the header. QEMU's configuration has a `refresh_rate` field for each output (`include/hw/virtio/virtio-gpu.h`), and the device can report an EDID with the optional feature `VIRTIO_GPU_F_EDID`; the header does not say that either changes how a flush is timed. The standard device therefore gives a program a damage rectangle (the flush rectangle), a cursor (the cursor queue, `UPDATE_CURSOR` and `MOVE_CURSOR`), a fence and display information (`GET_DISPLAY_INFO`: size and enabled flag of each output), and no anti-tearing sugar (3.17) beyond that.

**3.14.1** The standard graphics device of the first iteration is virtio-gpu in 2D mode over the virtio PCI Express transport (errata 79); its commands are the five of the figure, plus the cursor queue and the display-information query. *(D)*

**3.14.2** The feature subset of virtio-gpu that the pdp64 requires (the EDID feature, the fence flag, the cursor queue, the blob and 3D features of the header, which are not used for 2D) is not specified. *(S)*

**3.14.3** The framebuffer of virtio-gpu is the backing memory that the driver allocates; on the pdp64 it is ordinary memory mapped uncached (3.13.1), and the transfer command is the hand-off that tells the device to read it (the five steps of 2.5.3). *(P)*

**3.14.4** The standard device has no 48-bit pixel and no text layer: the 48-bit pixel of 3.8.2 belongs to the native device that is deferred, and a text terminal over virtio-gpu is a program that draws glyphs into the backing memory with the processor (the way 3.5 ends) or with a library. *(S)*

*Commentary.* **Chain.** The PDP-11 has no antecedent: its devices had registers, not queues (2.1). QEMU offers virtio-gpu as a virtual machine's display (`hw/display`): the guest draws into its own memory and tells the host which rectangle to show. **Trade-offs.** It is the most standard route (one tested driver, the same in QEMU, `sim64` and the FPGA, as errata 79 says) and does everything in software: the processor writes every pixel and the host copies them, which is cheap for a terminal with little damage and costs a game what 3.5 described. **Improvements.** The sugar of 3.16 can be a library over it: set up the five commands, allocate the picture, draw text from a glyph cache and flush only the damage (sketch 4 of 3.21). **Benefits.** No special hardware, and the display of the first iteration works in the emulator now. **Modern comparables.** Linux's `virtio_gpu` driver, which sits on the DRM interface of 3.16. **Impact.** *Kernel:* a driver for the five commands, one queue of 2.7 and a cursor queue. *Compiler:* none. *Hardware:* none beyond the virtio device and the bus.

## 3.15 A standard graphics card

**3.15.1** A PCI Express graphics card is not excluded by the architecture: a bridge could present PCI Express functions as slots on the bus, enumerated like any other device. *(P)*

**3.15.2** Against a standard card: PCI Express configuration space, base-address mapping and message-signalled interrupts, a driver stack for a programming model that for some vendors must be reverse-engineered, the card's firmware and the initialisation a PC's firmware performs, and no hard PCI Express block on the first board (the Cyclone V and the Zynq 7020 are recorded as lacking one, *unverified* here; a Zynq UltraScale+ has a hard root complex, `docs/pdp64-fpga-plan.md`). *(D)*

**3.15.3** On the other side PCI Express is a standard enumerated bus, which suits the bus-as-a-device design (each function a slot, as each USB device is), and OpenBSD carries graphics drivers for several vendors' cards ported from Linux (*unverified*). *(P)*

*Commentary.* **Trade-offs.** The terminal described here works on the first board; a standard card needs a PCI Express root complex, a large block where the chip has none, and a graphics driver ported to the pdp64, which is a larger task than the architecture (`docs/pdp64-fpga-plan.md` says the same and answers no to a discrete GPU). **Modern comparables.** PowerPC and RISC-V workstations take PCI Express graphics cards with open drivers (general knowledge, *unverified*). **Impact.** *Kernel:* a large graphics driver ported. *Compiler:* none. *Hardware:* a PCI Express root complex and a bridge to the bus.

## 3.16 What made graphics programming annoying

The author, 2026-11-10: "basically, anything that made graphics programming annoying or cumbersome or boiler platey, we want to sugar away to almost nothing." This is a goal; the means are open. **Boilerplate** is code written the same way in every program before the program can do anything of its own. This section lists the boilerplate that exists, shows three pieces of it, and asks of each what the architecture could do so that the program does not have to. The PDP-11 has no antecedent: its console needed none (3.1). The chain runs from the VGA programmer's register lore (3.5) to the Linux and Vulkan setup lists below.

**3.16.1** The aim is that what made graphics programming annoying, cumbersome or boilerplate is reduced by the architecture to almost nothing; the means are open and each is a candidate (section 3.16 and its table). *(P)* (The author, 2026-11-10, errata 105.)

**3.16.2** The standard first-iteration device, virtio-gpu, keeps its own protocol (3.14); where this section says that a sugar "would" appear, it appears in a device of the second iteration (3.8) or as a library over virtio-gpu, and no sugar is specified. *(S)*

**3.16.3** The measure that every design in this chapter is held to is the author's: "graphics programming should be as simple and pleasurable as the c64 was." *(P)* (2026-11-10, errata 105; a goal, not a design.)

The books of Michael Abrash on VGA and PC graphics programming (the author's "800 page michael abrash books"; titles and page counts *unverified*, 3.5) exist because a programmer could not get a fast picture without knowing the VGA's registers, its planar memory, its retrace, the banking of each chip and how to hand-tune the inner loops. Each row of the table below is a piece of that knowledge, or of its successor (the long setup lists of the Linux display interface and of Vulkan), that the author would like the architecture to make unnecessary. The knowledge was real and was needed.

Three worked pairs follow. Each shows the boilerplate as the real systems have it (names are those of the real interfaces, checked in the headers on this machine where marked, otherwise general knowledge, *unverified*) and then what the pdp64 could offer. The pdp64 versions are sketches with placeholder names, not registers.

**Pair 1: getting a picture on the screen at all.** On a VGA/VESA PC the program asked the BIOS for the list of modes, picked one, set it, and found the framebuffer:

```
# VESA (VBE), 1990s: about 15 lines in a real program (illustrative, not measured)
info = vbe_get_controller_info()
for m in info.mode_list:
    mi = vbe_get_mode_info(m)
    if mi.width == 1024 and mi.height == 768 and mi.bits_per_pixel == 32 and mi.has_linear_framebuffer:
        mode = m
vbe_set_mode(mode | LINEAR_FRAMEBUFFER_BIT)
fb = map_physical(mi.physical_base, mi.pitch * mi.height)
```

On Linux (DRM/KMS, the kernel's display interface) the same job is longer. The program opens the device, lists **connectors** (the outputs), reads the monitor's modes (**EDID**, the data block in which a monitor describes the modes it supports; general knowledge), chooses one (`struct drm_mode_modeinfo` in `drm_mode.h`: pixel clock, horizontal and vertical totals and sync positions, refresh rate), allocates a **dumb buffer** (a plain pixel buffer), registers it as a framebuffer (`DRM_IOCTL_MODE_ADDFB2`, with a format code and a pitch), maps it, and sets the mode on a **CRTC** (the unit that does scanout; the name comes from cathode-ray tube controller):

```
# Linux DRM/KMS, one output, no atomic: about 40 lines in a real program (illustrative, not measured)
fd = open("/dev/dri/card0")
res = drmModeGetResources(fd)
conn = first connected connector in res
mode = conn.modes[0]                           # the monitor's preferred mode, by convention first
crtc = a crtc the encoder of conn can use
buf = create_dumb(fd, mode.hdisplay, mode.vdisplay, 32)    # returns handle, pitch, size
fb_id = drmModeAddFB2(fd, w, h, XRGB8888, handle, pitch)
ptr = mmap(fd, map_dumb(buf).offset, size)
drmModeSetCrtc(fd, crtc, fb_id, 0, 0, conn, mode)
```

A program on Vulkan or OpenGL meets another list: create an instance, enumerate physical devices, choose a queue family, create a logical device, a window surface, a swap chain and its images, image views, a render pass, framebuffers, command pools and buffers and synchronisation objects (the names `vkCreateInstance` and `vkCreateSwapchainKHR` are Vulkan's, whose headers are not on this machine, *unverified*; OpenGL's `glGenBuffers`, `glCompileShader` and `glLinkProgram` are in `glext.h` here). A "hello triangle" in Vulkan is commonly several hundred lines (general knowledge, illustrative). In virtio-gpu the equivalent is five commands (3.14): create resource, attach backing, set scanout, transfer, flush, with the drawing between them.

The pdp64 could offer **a device that already shows something**:

```
# the pdp64 way, open (a sketch)
# the device powers up with a sane default mode, in the monitor's preferred mode, with a canonical pixel format:
fb = peek(DISPLAY_BASE)            # where the picture is, always mapped
w  = peek(DISPLAY_WIDTH); h = peek(DISPLAY_HEIGHT)
poke(fb + (y * w + x) * 4, 0xFFFFFFFF)     # a white pixel: done
```

Options, with trade-offs. (a) The device **reports its mode** (a register holds the width, height and refresh rate of the mode chosen at start-up from the monitor's data; virtio-gpu's `GET_DISPLAY_INFO` already returns the width and height of each output in a `virtio_gpu_resp_display_info`); nothing to set. *Cost:* the device reads the EDID itself (a small I2C engine, which 3.12.1 already puts at the transmitter chip) and applies a policy; a program that wants another mode still has the registers. (b) A **fixed canonical pixel format** with the device converting at scanout (the repository's 48-bit RGBA pixel, errata 73, would be that format on the native device; virtio-gpu offers only 32-bit formats with eight bits per channel: `VIRTIO_GPU_FORMAT_B8G8R8A8_UNORM` and its siblings, in `virtio_gpu.h`, so the 48-bit pixel does not exist on the standard device; 3.23 lists the inconsistency). *Cost:* a conversion stage in the scanout, and memory a program wastes if it wants fewer bits. (c) **Stride equal to width** unless the program asks for padding, and the framebuffer window **always mapped**: the program has no `mmap`, no bank register, no `map_physical`; the window is in its address space from the start, a decision of the page tables and the bus (2.3.3 and 3.13.4). *Cost:* a fixed place in the address space, and a rule for what a program does that wants two framebuffers.

**Pair 2: the cache and the flush.** A processor has a **cache** (a small fast memory that keeps recently used data close to the core). Pixels the program has written may still be in the cache and not in memory, and a device that reads memory by DMA then sees the old data. Where the device does not snoop the cache, the program must flush:

```
# a display that does not snoop the cache: about 3 lines per update, in every program (illustrative)
draw(framebuffer)
cache_clean_range(framebuffer, size)       # push the dirty lines to memory
memory_barrier()                           # and make sure the writes are ordered before the notification
poke(DOORBELL, 1)
```

The pdp64 already removes this, and chapter 2 says how: processor caches are coherent with each other, a device and the processor are not, and the answer is a memory type, **uncached**, instead of a flush instruction: "buffers are mapped uncached and the hand-off is explicit" (2.5.2), and "No driver can forget a cache clean or invalidate, because there is none" (2.5, commentary). The framebuffer is mapped uncached too (3.13.1). The cost, stated in 3.13, is that a long run of writes is no slower per byte but a single write is slow; a write-combining memory type for the framebuffer is a candidate improvement (3.13) that the four memory types of 2.3.4 do not name. So the sugar is decided for correctness *(D)* and open for speed *(P)*.

**Pair 3: drawing text.** On a GL or Vulkan system text is the longest boilerplate, because the GPU has no text:

```
# a GPU text path (illustrative; about 150 lines in a real small program, not measured)
font = ft_load("DejaVuSansMono.ttf"); ft_set_size(font, 16)
atlas = new_texture(1024, 1024)
for each character c needed:
    bitmap = ft_render_glyph(font, c)           # the font rasteriser (CPU)
    rect = pack_into_atlas(atlas, bitmap)       # find room: a bin-packing problem
    upload(atlas, rect, bitmap)
    remember(c, rect, advance, bearing)         # metrics: how far to move on, where the glyph sits
for each cell on screen:
    append_quad(vertex_list, x, y, rect_of(char), fg, bg)
upload(vertex_list); bind(atlas, shader); draw(vertex_list)
# plus kerning, ligatures, right-to-left runs, combining marks, fallback fonts, scaling for HiDPI
```

The pdp64's terminal would do it as the C64 did, with one store:

```
# the pdp64 way, open (a sketch; names are placeholders)
poke(CELL(row, col).glyph, SLOT_OF('A'))     # or: poke(CELL(row, col).char, 'A')
poke(CELL(row, col).fg, RED)
# a new glyph: one library call fills a slot from the TrueType engine
font_render_into_slot(font, 'λ', slot)       # rasterises the outline and writes the bitmap into the slot
```

The author's glyph slots do the work of the atlas, and one library call replaces the first half of the boilerplate (3.9). Two candidates: (a) the cell holds the **character code**, and the device or a table maps the code to a slot, so the program never names slots (the author's c64x terminal of 2026-06-18, `c64stuff.txt`, line 5015: "each cell holds its actual data, not a reference to the data"); or (b) the cell holds the **slot number** directly, which is the simplest hardware and makes the program responsible for assigning slots. The choice is open (3.23): (a) is easier for the program and costs a lookup table in the scanout; (b) is nearly free and puts a small allocator in a library.

### The pain points, in a table

Each row names something that has annoyed graphics programmers, the size of its boilerplate (line counts are *illustrative* and **not measured**), the sugar the architecture could offer, and where it appears in the sketches of 3.21 (S1 layers, S2 layers plus blitter, S3 command queue, S4 plain virtio-gpu with a library). "Decided" means the repository already decides it.

| Pain point | Typical boilerplate (illustrative) | The sugar that would remove it | Where (3.21) |
|---|---|---|---|
| Mode setting and discovering what the display supports (EDID, modes) | 15 lines (VESA) to 40 (DRM) | the device reads the monitor and starts in its preferred mode; a register reports it | S1 S2 S3 native; S4: `GET_DISPLAY_INFO` gives the size, a library the rest |
| Pixel formats | one format code to get right, and conversion code when it is not | one canonical format, the device converts at scanout | S1 S2 S3; S4 has 32-bit formats only |
| Stride and pitch | one multiply in every pixel address | stride equal to width unless asked; the address of pixel (x, y) is a register-reported formula | S1 S2 S3 |
| Endianness and colour order (RGB or BGR, alpha first or last) | a swap or a table, in every program | one defined order, little-endian (decided for the machine, errata 72); the colour field order named once | all |
| Bank switching and mapping the framebuffer | 5 to 20 lines | a window always mapped, no banks | all (3.13.4 is the rule for the type) |
| Double buffering and tearing | 10 to 30 lines, plus a frame loop | a latching base register, a fence, per-layer flip, versioned buffers (3.17) | S1 S2 per layer; S3 queue; S4 flush |
| Synchronising with the display | polling or a vblank interrupt handler | raster interrupt and a fence (3.17); decided: vblank interrupt at a fixed line (3.8.9) | all |
| Cache coherence between CPU writes and the device | 3 lines per update, forgotten once per project | decided: uncached memory type, no flush exists (2.5.2, 3.13.1); open: write-combining for speed | all |
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

## 3.17 Scanout, tearing and double buffering

The chain: the C64's raster register and interrupt (3.4) let a program time its changes to the beam; the VGA's retrace (3.5) asked the same of PC programmers; double buffering and compositors moved the timing into the operating system; the pdp64 puts a latch in the device (3.8.9). The PDP-11's teletype had nothing to tear.

**Scanout.** A display does not hold a picture; it is **refreshed**. The adapter reads the framebuffer from the first row to the last, in order, at a fixed rate, and sends each pixel to the monitor as it is read: this is **scanout**. The rate is the **refresh rate**, 60 times a second on most monitors (the C64's was 50 or 60, by television standard). Between frames, and between rows, there are **blanking intervals** when the monitor is sent no pixels (the beam of a tube had to fly back); the gap between the last row of a frame and the first of the next is the **vertical blank**, which VGA called the vertical **retrace**. The C64's raster register and interrupt (3.4) are the program's view of it: the number of the row being read now, and a way to be told when the beam reaches a chosen row.

**Tearing.** If the program changes the picture while the scanout is reading it, the part of the screen above the row being read shows the old picture and the part below shows the new one. The seam is a **tear**: a horizontal line where a moved object appears cut in two. **Flicker** is the related fault: a program that clears the screen and then draws lets the scanout catch it empty or half drawn. In the figure time runs to the right and the row being read rises from the first row to the last once a frame.

![Scanout and tearing against time](figures/gfx-tearing.svg)

**Double buffering.** The standard fix is two pictures. The **front buffer** is being shown; the program draws the next frame in the **back buffer**, and when it is complete the two exchange roles while the scanout is in the vertical blank and no row is being read. The exchange is a **swap** or a **page flip**. It can *change the base address* the scanout reads from (a register write; nothing is copied) or *copy* the back buffer into the front buffer (a **blit**, cheap with a blitter and slow without, and the copy itself tears if it outlasts the blank). In peek/poke pseudocode, single buffer first:

```
# 1. single buffer: tears and flickers
loop:
    clear(FRAME)                          # the scanout can see an empty screen here
    draw_scene(FRAME)                     # and half a scene here
```

```
# 2. double buffer, swap by changing the base address (a page flip), done by polling
front = BUF_A; back = BUF_B
poke(SCANOUT_BASE, front)
loop:
    draw_scene(back)                      # nobody is reading `back`
    while peek(RASTER_LINE) != 0:         # wait for the start of the blank: busy-waiting
        wait                              # (or wait for a vertical-blank interrupt)
    poke(SCANOUT_BASE, back)              # the flip: takes effect now
    swap(front, back)                     # draw next into the picture just retired
```

Double buffering has four costs. It **needs twice the memory**: at 1920 by 1080 and 4 bytes a pixel, 8.3 MB twice (3.13.2). It **needs a deadline**: if the next frame takes longer than a frame time the flip misses the blank, and the program either waits for the next one (the rate falls from 60 to 30 and then to 20, the "half frame rate" cost of `kernel-pain-points.md` 0.6 #3) or flips at once and tears. **Triple buffering** (three pictures, so the program can start the next frame while the finished one waits for the blank) removes the wait and adds a frame of memory and of **latency** (the delay between the program's input and what the screen shows). Polling the blank occupies the processor, and the interrupt version needs a driver. Finally, a base-address register must change *in the blank*, which a program that is itself interrupted cannot always manage: the Linux driver for one common graphics chip disables interrupts and busy-waits for the row to pass before it updates registers ("vblank evasion", `kernel-pain-points.md` 0.6 #13, from `intel_pipe_update_start`).

**Is this still a problem with HDMI?** The author asked (2026-11-10): "with modern hdmi is tearing even a concern?" Tearing is not a property of HDMI. HDMI (like DVI and DisplayPort, 3.12) carries a pixel stream at a steady rate and cannot know whether the picture was complete when it was read. A tear happens one step earlier, in the display controller that reads the framebuffer while a program changes it. On a phone or desktop the **compositor** (the system program that gathers the pictures of all windows and builds the one that is shown) and the driver hide it: they draw the next frame in a spare buffer and flip it at the vertical blank. That machinery is the boilerplate of 3.16, which the author wants the architecture to sugar away. A program on the pdp64 that writes straight into the framebuffer with no operating system between (a boot program, a game written to the metal, a C64-style program) can still tear, so the tear-free flip must come from the architecture or the device, not the cable.

A program on the pdp64 that writes straight into the framebuffer, with no operating system between (a boot program, a game written to the metal, a C64-style program), can still tear, so a tear-free flip has to come from the architecture or the device and not from the cable (the assistant's reasoning, from errata 105's wish for tear-free graphics).

Variable refresh (HDMI VRR, adaptive sync) turns a late frame into a short delay, which reduces the need for a blank-time flip but does not remove it: the frame still must not change *while* it is read. A television may hold a whole frame before showing it (latency), and a laptop panel may refresh itself from its own memory when nothing changes (panel self-refresh). Checked on this machine: HDMI is a pixel-stream transmitter (3.12.1), and the DRM header `drm_mode.h` has a page-flip call with a completion event (`DRM_MODE_PAGE_FLIP_EVENT`) and an asynchronous flag that allows a flip with tearing (`DRM_MODE_PAGE_FLIP_ASYNC`). *Unverified* general knowledge: the VRR and adaptive-sync standards and what a sink does with a late frame, television latency, panel self-refresh, and what phone and desktop compositors do. Whether a tear-free flip is worth hardware when the display is variable-refresh is a question for the author (3.23).

**What the repository already decides.** The video device (3.8) shadows every register that takes effect at a frame boundary: one write to `ARM` latches them all at the start of the next vertical blank, a status bit says whether the arm was taken or missed, a sticky underrun bit reports a scan-out that ran dry, and the vertical-blank interrupt occurs at a fixed line (3.8.9, errata 71, from `kernel-pain-points.md`). A base address in that register set therefore flips at the blank without the program arranging anything. The author's device chat of 2026-08 said the same ("multi-register updates are atomic at a named raster line or vblank", `docs/c64-devices-from-chat.md` section 2) and, for the eight-way machine, the assistant's proposal that the author accepted: "Flip on vsync unconditionally with an overrun interrupt instead of a barrier" (`c64stuff.txt` line 5647; the capitalisation is mine). No text decides anything beyond one shadowed register set: independent layers, damage, variable rate, fences, or a default that needs no program setup.

**3.17.1** The architecture is to offer conveniences that avoid tearing, flicker and the other faults that forced programmers to double-buffer, and to do it so that the common program needs no more than a store; the form of those conveniences is open. *(P)* (The author, 2026-11-10: "we want to put in nice architectural sugar to avoid 'tearing' and all those other issues graphics programmers had to use double buffering to fix", errata 105.)

**3.17.2** The mechanism that is decided is the shadowed registers and the one `ARM` write of 3.8.9; everything else in this section is a candidate. *(D)*

The candidates, each with what it costs, and none decided:

* **A scanout base register that latches at the vertical blank** (a page flip: the register holds the address of the picture to show and takes the new value only in the blank), with a completion **interrupt** or a **fence** (a counter that the device advances when the flip has happened, which the program can read or wait on, so it knows that the old picture is free). *Gives:* no tearing, no polling of the raster; the program writes one register and goes on. *Costs:* two pictures of memory for the program that uses it, and a rule for what the register shows if it is written twice in one frame (the first is dropped, or the second waits). *Already in 3.8.9, except the fence.*
* **Per-layer latching**, in a design with layers (3.21, sketches 1 and 2): each layer has its own base register and flips independently, so a cursor or a sprite layer can move every frame while the text layer flips only when its text changes. *Gives:* the cheapest case for text, a moving cursor with no redraw. *Costs:* one set of registers per layer.
* **An atomic commit of several registers**: several registers are staged and applied together at the blank (this is what `ARM` of 3.8.9 is for the single set; Linux calls the same idea "atomic modesetting" and offers `DRM_MODE_ATOMIC_TEST_ONLY` to ask "would this work?" and `DRM_MODE_ATOMIC_NONBLOCK` to ask for it without waiting, both in `drm_mode.h` on this machine). *Gives:* a change of mode, picture and cursor that cannot be seen half-done. *Costs:* the shadow copies of the registers, which a small device pays in flip-flops; an optional test-before-commit is more.
* **A raster-position register and a raster interrupt** (the C64 way): the program can know the row being read and be interrupted at a chosen row. *Gives:* mid-frame changes (the C64's trick of a different colour or sprite position per band) and a way to time drawing behind the beam. *Costs:* one register and an interrupt source; encourages programs that are tied to the display's timing.
* **Variable refresh** (the monitor waits for the frame instead of reading at a fixed rate: so a frame that is late is not a missed blank but a short wait; the standards are called adaptive sync, FreeSync, G-Sync and, for HDMI, VRR, variable refresh rate; unverified general knowledge). *Gives:* a late frame costs only its own delay, not a halving of the rate. *Costs:* the output must support it (the HDMI transmitter chip of 3.12.1 and the monitor), and the device's mode registers must say so.
* **Damage rectangles** (the program says which part of the picture changed and only that part is sent on): this is what virtio-gpu's `TRANSFER_TO_HOST_2D` and `RESOURCE_FLUSH` take as a `virtio_gpu_rect` (3.14). *Gives:* less memory traffic when little changes (a terminal). *Costs:* the program must track what it changed.
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

## 3.18 A c64 mode: a small computer on the die that acts as the terminal

The author, 2026-11-10: "we will have a c64 mode, where a c128 is built onto the die with sid etc, so a bit of code loaded into its address space by pcie dma will let it act as a terminal the way the blit and vt55 did." This is a **proposed idea**, not a design. This section explains it for the two readers and states the questions it leaves open.

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

The core's address space is the C64's (3.4) with a mailbox added. Everything the loaded program needs is in one flat space, as in the 1982 machine: its own code, screen and colour memory, glyph slots, the video and sound registers, and a window the host also sees. Video goes to the display connector and audio to its audio channel (3.12); audio over HDMI brings the audio clock relation of 3.12.4 with it, which the core's program must honour or the transmitter's own calculation must supply.

**3.18.1** A **c64 mode** may be offered: a small core on the die, with the C64 family's circuits (SID and others), into whose address space a program is loaded by DMA over PCI Express so that it acts as a terminal, as the Blit's terminal program did. *(P)* (The author, 2026-11-10, errata 105.)

**3.18.2** C64 mode is the enabling or disabling of the on-die c128 as a PCI Express device: when it is enabled it takes over the graphics and audio output, or sends them to a compositor; the form of the compositor path is open. *(P)* (The author, 2026-11-10: "the mode is just enabling/disabling the c128 as a pcie device so it takes over the graphics and audio output... or sends them to a compositor. not sure what that would look like. is there virtio-compositor?")

**3.18.3** Everything about this idea other than the two sentences above is open and unspecified: which core; whether "c64 mode" also means running unmodified C64 software; how video memory is shared; the form of the compositor path; how the core and the host talk; how the loaded image is authenticated and contained; and how the idea relates to the native devices and to virtio. *(S)*

**The questions the author's words leave open**, stated and not answered:

1. **Which core?** He wrote "a c128". The C128 (general knowledge, *unverified*) combined an 8502 (a faster member of the 6502 family, like the C64's 6510), a Z80 for CP/M, the VIC-IIe video chip, the 8563 **VDC** (a separate 80-column video chip with its own memory) and a SID, with a memory-management chip for banking. The repository mentions the 8502 only: the author's earlier device chat (`docs/c64-devices-from-chat.md` section 4, nothing decided) put an **"8502 compatibility island"** in the design, a soft 8502 held in reset at power-on, readable and writable by the host, running at the C64's clock so that Commodore software could run. Is the core (a) a real 6502-family core, hard or soft; (b) an emulation of one, in software or hardware; or (c) a core of the pdp64's own instruction set with the C64's registers? Does "c128" mean the 8502 only, or the Z80, the VDC and the memory-management chip too?
2. **What does "c64 mode" mean beyond the author's clarification?** He says the mode is "just" the on-die c128 appearing as a PCI Express device that takes over graphics and audio or sends them to a compositor (3.18.2). Open: does the loaded program run **unmodified C64 software** (the Kernal, BASIC and games, which need the exact chips and timing) or only **terminal firmware** written for the small core?
3. **How is video memory shared** with the host and with virtio-gpu (3.14)? Is the core's screen memory its own, behind a window, or in host memory that the video chip reads by DMA (3.13.2)? Who owns the scanout when the standard device is virtio-gpu, which has a resource of its own?
4. **How do the core and the host talk?** A mailbox and a doorbell, a virtio device with queues (2.7), or a shared window of memory? The figure draws a mailbox only as a placeholder.
5. **How is the host's program image authenticated and contained?** A program loaded from the host runs on the die with access to the core's whole address space and, depending on the design, to the bus. The IOMMU of errata 75 and 85 (the table of which memory a device may touch) answers this for devices that master the bus; whether the core's DMA goes through it, whether the image must be signed and who holds the key are the author's to decide.
6. **How does it relate to the deferred native devices (errata 78) and to virtio across the board (errata 95)?** The author said "forget the native 8 register devices. gone. virtio across the board." (errata 95) and earlier "iommu will allow us to map in c64/c128 and i think we should, but that is extraneous" (errata 75, 2026-11-03). A core with the C64 family's chips is a native, register-level device by definition. It is either (i) the surviving form of the native devices, serving as a terminal, with VIC and SID as its private chips; (ii) a device that speaks virtio to the host on its outside and the C64's registers only inside, which honours errata 95 on the bus; or (iii) an optional extra outside the standard that errata 95 did not have in view.
7. **What does it cost in gates and die area?** A 6502-class core is a few thousand gates (general knowledge, *unverified*). My own estimate, unmeasured: the core is small beside the display memory, which makes the idea attractive. A hard block costs area for everyone; a soft core exists only in the FPGA phase.
8. **How does its sound reach HDMI audio?** Through the 48-bit-sample sound path (errata 74, 3.8.3) or the SID's own output converted to the stream of 3.12.4.

**The options, none decided.** (a) **A hard core on the die** (a real 6502-family core plus the chips): fastest and smallest per core, permanent die area, and it fixes the idea in silicon before the author has answered the questions above. (b) **A soft core in the FPGA phase only**: no silicon cost, and the idea can be tried on the first board (the programmable logic can hold a small core and the chips, as the MiSTer framework does, 3.12); gone from a later chip unless made hard. (c) **Software emulation of the C64 machine on a pdp64 core**: no hardware and easiest to change, but it uses a core and loses the C64's exact timing; it is the Blit's idea turned around, with the emulator as the "terminal program". (d) **None: the terminal is a virtio device served by a host process**, the standard route of errata 95, with firmware that is a program on the host as a terminal emulator is (3.7); nothing on the die, and the terminal is no longer a computer of its own, which the author values in the Blit. Options (c) and (d) differ in where the C64 machine runs, not in whether it exists.

### The compositor question

The author, 2026-11-10: "the mode is just enabling/disabling the c128 as a pcie device so it takes over the graphics and audio output... or sends them to a compositor. not sure what that would look like. is there virtio-compositor?"

**What a compositor is.** A **compositor** is the program (or hardware) that combines the pictures of several windows or sources into the one picture sent to the display, which is then scanned out as in 3.17. In a desktop window system each program draws into its own picture (its **surface**) and the compositor places the surfaces, one over another, into the frame the scanout reads. The PC's windowing systems did this in software (3.5); in the layered sketches of 3.21 the scanout hardware does it, as the C64's chip did with sprites. The PDP-11 has no antecedent; its terminal was a single stream.

**Why "takes over" is the simple case.** If the c128 owns the output outright when enabled, there is nothing to compose: the machine has one scanout and one audio path, and the only question is who drives them. The multiplexer is a single enable bit (path (a) below). The compositor case differs in one way: the core is one client among others, so its picture and sound must be handed over in a form that the host's compositor, or the display controller's layers, can place.

![Five data paths for a c64-mode core sharing the display](figures/gfx-compositor-paths.svg)

**What exists, checked.** No virtio device is called a compositor: no entry of `virtio_ids.h` on this machine names one. The display-related types are GPU (16), input (18), sound (25), video encoder and decoder (30, 31), DMA buffer (37) and audio policy (39). The nearest parts in `virtio_gpu.h` are up to 16 scanouts (`VIRTIO_GPU_MAX_SCANOUTS`); `SET_SCANOUT_BLOB`, which sets a scanout from a blob resource (a memory object shared with the host without copying); a **cursor queue** separate from the control queue (`UPDATE_CURSOR`, `MOVE_CURSOR`); and capability sets (`VIRTIO_GPU_CAPSET_VIRGL`, `VIRGL2`, `GFXSTREAM_VULKAN`, `VENUS`, `CROSS_DOMAIN`, `DRM`) selected with `context_init`, so that several rendering contexts, each with its own ordering (the "timelines" of the header comment), share the device. QEMU's `docs/system/devices/virtio/virtio-gpu.rst` describes `virtio-gpu-rutabaga`, which provides "gfxstream rendering and Wayland display passthrough", with a `cross-domain` capset for Linux guests and experimental `x-gfxstream-composer` for Android guests; it says no more about what the cross-domain path carries. That the crosvm project uses the same mechanism to show a guest's windows as windows of the host's Wayland compositor (Wayland is the Linux display protocol in which clients hand surfaces to a compositor) is general knowledge and *unverified*. **virtio-snd** and **virtio-input** exist for audio and for keyboard and mouse. Paths (b) and (c) can therefore be built from parts that exist, and path (e) is a new device type; how a type gets its number is *unverified* here.

**The options, none decided.**

* **(a) Exclusive takeover.** When the c128 is enabled it owns scanout 0 and the audio path; the host's picture and sound stop. *Gives:* the simplest hardware (an enable bit and a mute); the C64's one-screen model. *Costs:* the host cannot show anything while the core runs; a text terminal that wants to coexist with a window system cannot. Right for a console in the Blit's sense, wrong for a window.
* **(b) The core is one more virtio-gpu scanout and one virtio-snd stream.** It is a second head of the display device (or a window on the host's, if the host maps heads to windows) and one more stream of the sound device. *Gives:* nothing new to invent; the host's existing drivers and compositor handle it; it is the shape of errata 95. *Costs:* the core must speak the virtio-gpu and virtio-snd protocols, so a small core would need those in firmware or hardware, which is the larger part of a driver.
* **(c) A surface for the host's compositor (the author's stated preference, below).** The core renders into a resource (or a blob) that the host's compositor treats as a window's surface, as any client's. *Gives:* the core appears as a window, with the host's window management, overlap and flipping; the path that Wayland passthrough takes (general knowledge, unverified). *Costs:* the compositor must know that the surface is the core's; a copy or a shared blob; the core's frame timing becomes the compositor's.
* **(d) Layers at scanout** (sketch 1 of 3.21). The display controller has a layer for the core and a layer for the host's picture and composes them as it reads them out. *Gives:* the cheapest path and no copy; the core's picture is a plane in video memory; a vertical-blank latch per layer (3.17) switches it without a tear. *Costs:* the display controller must be the layered one of sketch 1, which is not the first-iteration device.
* **(e) A new virtio device type for compositing.** It does not exist. What it would need to be useful: a way for a client to give the device a surface (a resource or blob), to say where it goes and how it overlaps, to swap it atomically at a blank, to ask for the frame's timing and to hand over the matching audio. Most of those are what virtio-gpu's resources, scanouts and fences already say; *a new device type would repeat them*, and it is the author's call whether a compositor is a device or a protocol of existing ones. *Gives:* one model for every client of the display, the core included. *Costs:* a specification to write and have accepted (unverified: the virtio process), and a driver for every host.

**3.18.4** Of the five compositor paths the author prefers (c), that the c128 renders into a buffer that the host's compositor treats as a surface: "c128 drawing into a buffer makes most sense" (2026-11-10, errata 106). This is a stated preference, not a decision. *(P)*

It makes the core a client like any other, the way rio treats every window (3.20: a window is a buffer and a rectangle), and its parts exist (a virtio-gpu resource or blob as the surface, 3.14). Still open under it: how the compositor learns that the buffer is the core's, who owns the copy or shared memory, and how the core's frame timing meets the compositor's. The audio form of the same choice is in 3.19.

**How the switch avoids tearing and pops.** Enabling or disabling the mode changes who feeds the scanout and the audio path. A change in mid-frame tears the picture (3.17), and a sudden change of the waveform's value is heard as a pop. The remedy has the shape of 3.17: hand over at a **vertical blank**, as the latch of 3.8.9 does for registers (the enable bit is one more shadowed register that `ARM` latches), and **mute with a short ramp** (a fade of a few milliseconds down before and up after, not a cut). In path (a) the enable bit is the shadowed register and the mute belongs to the audio path; in (b) to (e) the compositor does the hand-over and the core only stops or starts its stream. The audio clock relation of 3.12.4 must stay unchanged across the switch, or the transmitter loses its lock and the sound drops.

*Commentary.* **Chain.** The PDP-11 had only the fixed terminals of 3.2. The Blit loaded its terminal program from the host. The C128 put several complete computers in one box (general knowledge, *unverified*), and the MiSTer framework runs C64 and C128 cores in programmable logic. The pdp64 proposal puts a small core on the die and loads it by DMA. **Trade-offs.** A computer of its own makes the terminal programmable and independent of the host's drawing, and makes it a second machine to load, secure and keep consistent with the first. **Impact.** *Kernel:* a driver for the loader and the mailbox. *Compiler:* none. *Hardware:* a core, memory, DMA and the C64 family's circuits, or nothing in option (d).

## 3.19 The audio path: samples, mixers and the pdp64

The author asked, 2026-11-10: "what is the audio equivalent, what do those mixers do to combine multiple programs audio?" Audio has the same structure as video, with a **mixer** where video has a compositor, and this section follows the order of 3.17 and 3.18. The chain: the PDP-11 had no sound hardware in this repository's records, so there is no antecedent there; the C64's SID synthesised sound from registers (3.4); PC sound cards stored samples and read them out; a sound server mixes several programs; the pdp64 has to decide where that mixing lives.

**What a sound card does.** A sound is a pressure wave, stored as a list of **samples** (numbers, each the height of the wave at one instant) taken at a fixed rate, commonly 44,100 or 48,000 a second (both appear in the virtio-snd rate list below), each sample a 16-bit integer, 24 bits or a floating-point number. A **DAC** (digital-to-analogue converter: the chip that turns a number into a voltage) takes one sample on each tick of a clock, and the speaker moves. The device is fed from a **ring buffer** (a block of memory treated as a circle, which the program fills and the device empties, the device reading the next sample at each tick and the program writing ahead of it). This is the scanout of 3.17 again: the display reads the framebuffer at a fixed rate and the DAC reads the ring buffer at a fixed rate. A **buffer underrun** (the device reaches samples the program has not yet written) is **audio's tearing**, heard as a click or a gap, and as certain when the program is late as a tear is when it draws late.

```
# fill the ring buffer: the program writes ahead of the read pointer, and notices an underrun
fill_ring(ring, next_frame):                 # called by an interrupt each period, or in a loop
    while free_space(ring) >= PERIOD:
        samples = generate_or_read(PERIOD)   # this period's samples
        write_to_ring(ring, samples)
    if device_read_pointer_passed_write_pointer(ring):    # underrun
        count_underrun(); write_silence_up_to(...)        # a click is unavoidable; at least not noise
```

**The SID's way.** The C64 stored no samples (3.4). The SID has three **voices**, each an oscillator with a waveform, an envelope and a filter, in hardware: a program says "this frequency, this waveform, this attack and release" and the chip *synthesises* the sound. The sound is never in memory as numbers, so nothing underruns and nothing is mixed in software; the chip mixes its three voices inside itself. This is the difference between the C64's text mode (the chip draws from a description) and a framebuffer (the program draws every dot).

**What a mixer does.** When several programs play sound the card has one ring buffer and one DAC, so something must combine the sounds into one stream: the **mixer**, the audio compositor. Its job, per **period** (a short block of samples, a few milliseconds):

```
mix_period(streams, out):                    # one block of the output; runs once per period
    for each frame i in 0 .. PERIOD-1:
        sum = 0
        for s in streams:
            x = s.next_sample()              # after converting s to the output's rate and format
            sum += x * s.volume              # per-stream volume
        out[i] = clip(sum)                   # or a limiter: a gentle gain reduction instead of a hard cut
    write_to_ring(out)
```

A mixer also has four other jobs. It **converts each stream to a common rate and format**, because one program plays 44.1 kHz music, another 48 kHz speech and a third floating-point effects; this **sample-rate conversion** (resampling: computing the samples of a wave at the new rate) is a filtering job, so a mixer is more than an adder. It **applies per-stream volume** and **clips or limits** the sum, because two loud samples added exceed what the output can hold (**clipping**: a hard cut of the top of the wave, heard as distortion; a **limiter** lowers the gain smoothly instead). It balances **latency against underrun**: a small buffer follows the program quickly and leaves little margin for the program being late; a large one is safe and late. And it handles **clock drift**: the program's timer and the DAC's clock are different crystals, so over minutes one runs ahead of the other. The remedy is to drive the mixer from the *device's* clock (write when the ring buffer has room) and to resample by a fraction of a percent to absorb the difference.

**Who the mixer is in real systems** (general knowledge, *unverified* except where noted): on Linux a **sound server** (PulseAudio and, more recently, PipeWire) or ALSA's software mixing plug-in (`dmix`); on macOS CoreAudio; on Windows WASAPI's shared mode. This machine has the `pulseaudio` program and the ALSA library `libasound`; it has PipeWire's client library but no PipeWire program. QEMU has a mixing engine (`audio/mixeng.c`, `audio-mixeng-be.c`) and backends for ALSA, PulseAudio, PipeWire, CoreAudio, DirectSound, JACK, SDL and others (`qemu-src/audio`): a virtual machine's sound is mixed by the **host**, like any other program's.

**What virtio-snd defines** (checked in `/usr/include/linux/virtio_snd.h`). Four queues: control, event, transmit (`TX`) and receive (`RX`). Streams are **PCM streams** (pulse-code modulation: plain samples) with a direction (output or input), described by `virtio_snd_pcm_info`: a bitmap of formats (from 4-bit ADPCM and 8-bit mu-law through `S16`, `S24`, `S32`, `FLOAT` and `FLOAT64` to DSD and IEC958), a bitmap of rates (5,512 Hz to 384,000 Hz, including 44,100 and 48,000), and a range of channels. The driver sets a stream's parameters (`PCM_SET_PARAMS`: `buffer_bytes`, `period_bytes`, channels, format, rate), prepares, starts and stops it, then sends audio as buffers on the TX queue, each tagged with a `stream_id` and answered with a `virtio_snd_pcm_status` that carries a `status` and the **current device latency** in bytes. The event queue reports `PCM_PERIOD_ELAPSED` and `PCM_XRUN` (an underrun or overrun: the same word as the ring buffer's), and jack events; each stream has feature bits for shared memory, polling, and period and xrun events (`VIRTIO_SND_PCM_F_*`). Controls such as volume are optional (`VIRTIO_SND_F_CTLS`). The header says nothing about **who mixes**: it defines one stream at a time, as one card. Mixing several programs happens on the host side of the device (QEMU's engine above) or, on a machine with no host, in the pdp64's own kernel or library before the stream is sent. The pdp64 is that machine, so who mixes is open.

**3.19.1** The standard audio device is virtio-snd (errata 79); the device carries one stream at a time as a PCM stream of the formats and rates the device lists. *(D)*

**3.19.2** The pdp64's mixer (the program or device that combines the audio of several programs into one stream, converts rates and formats and applies volume), where it lives (the kernel, a library or the device) and who drives it, are unspecified. *(S)*

**The audio of the c128 core, the options parallel to the pixel options of 3.18, none decided.** The author's preference for the pixel path (the c128 draws into a buffer, 3.18.4) has an audio form, but he has stated no preference for audio.

* **Exclusive takeover of the audio path** (parallel to 3.18 (a)): when the core is enabled it owns the audio output and the host's sound stops. *Gives:* nothing to mix; the SID's output goes to the converter or the HDMI audio channel. *Costs:* no music while the terminal bells.
* **The SID's output as a virtio-snd stream** that the host mixes with the others (parallel to 3.18 (c)): the core renders its voices to samples (or the SID model does), and the samples go into a stream as any program's would. *Gives:* the core is a client of the mixer; the host's volume, rate conversion and routing apply. *Costs:* the SID must produce samples at a rate (a design choice: the 48-bit sample path of errata 74 is exactly that), and its latency is the stream's.
* **A mix inside the device with a fixed gain:** the core's voices and the host's stream are summed by a small mixer in the device, at a fixed or registered gain. *Gives:* nothing for the host to know; cheap (an adder and a clamp). *Costs:* a fixed policy; the device has its own clock and a rate converter, or both streams must already be at one rate.
* **Hand-over with a fade:** whichever is chosen, switching the core on or off ramps the volume over a few milliseconds and changes at a period boundary (3.18) so that no pop is heard.

![The audio path beside the video path](figures/gfx-audio-path.svg)

## 3.20 Windows: from the Blit to rio and NeWS

The author, 2026-11-10: "it should mention blit terminal was inspiration for the rio and NeWS windowing systems, and we'd like to bring over what we can of that simplicity also."

**What the sources confirm and what they do not.** The Blit's `mux` was a window system in the terminal; its successor on Plan 9 was **8½**, whose paper says "Primarily for reasons of history and familiarity, the general model and appearance of 8½ are similar to those of mux"; and **rio** replaced 8½ ("Note that 8½ has been replaced by rio (see rio(1))"; rio(1): "Rio manages asynchronous layers of text, or windows, on a raster display"; *layers* is the Blit's word). All of this is recorded in `docs/kernel-pain-points.md` section 14I. That the Blit inspired **NeWS** is the author's statement; no source read for the repository makes the claim, and the glossary says so. From *The UNIX-HATERS Handbook* (section 14G of the same file) the repository records that NeWS was an extensible window server in which "the client can download programs and data structures to draw the whole schematic", and that "Ultimately, NeWS was not economically or politically viable" (the reasons given are about licensing). That NeWS was Sun's, written in PostScript (a page-description language that is also a programming language) and designed by James Gosling is general knowledge, *unverified*.

**What rio is.** rio is the window system of Plan 9 (the research operating system that followed Unix at Bell Labs; Rob Pike wrote 8½ and rio descends from it). Its central idea, in the 8½ paper, is that the window system is a **file server**: "The most important contributor to its small size, though, is its overall design as a file server." A program uses a window by opening files (`/dev/cons` for text, `/dev/mouse`, `/dev/bitblt` or later `/dev/draw` for graphics); each window is a private screen, and the server keeps its bitmap and does the drawing ("no bitmap graphics operations are executed in the client at all"). It is one small server with no **toolkit** (a library of buttons, menus and other widgets that every program of a window system links in; that X has several and rio's base system none is general knowledge, *unverified*).

**What NeWS was.** In a conventional window system a program on the host sends the display server drawing commands one at a time over a slow link, and each round trip costs time (the latency complaint of 3.2). NeWS made the server programmable: the host *downloaded a program* into the display server, which ran it locally for every mouse movement, so dragging a shape never crossed the link. This is the Blit's idea one step on: the Blit downloaded a program into a *terminal*, NeWS into a *window server*. The repository's note in section 14G of `kernel-pain-points.md` says the NeWS argument "is the same shape as the Blit lineage" and records that the text read does not mention the Blit.

The chain for windows: the PDP-11's teletype had none; the Blit's `mux` (terminal-side windows over a serial line), 8½ and rio (windows as files, on a local bus), NeWS (windows as downloaded code); the pdp64 asks which of these simplicities survive.

**3.20.1** The pdp64 is to bring over what it can of the simplicity of the Blit's descendants rio and NeWS (the author: "we'd like to bring over what we can of that simplicity also"); a goal, and the means are open. *(P)*

**3.20.2** Which of the options below the pdp64 takes, if any, is open. *(S)*

**What simplicity could be carried over, as options with their trade-offs, none decided.**

* **A window is a plain buffer and a rectangle.** The program owns a pixel buffer (or a cell array, 3.9) and the system knows only where to place it. *Gives:* the model of 3.16's goal; drawing is writes to memory with nothing to ask for. *Costs:* a buffer per window (memory), and a rule for who may write whose (the memory protection of chapter 6). *Ties to:* path (c) of the compositor question (3.18), where the c128 draws into a buffer that the compositor places.
* **Drawing is writes to that buffer.** No drawing protocol in the base system: the program uses `memcpy`, a library, or the blitter (3.21 sketch 2). *Gives:* no round trips, no server-side drawing language. *Costs:* every program draws for itself (the opposite of rio's "the server carries out the drawing"); a library must exist for text and shapes.
* **The server composes the buffers.** A small program (or the display hardware, sketch 1) places the buffers into the one picture. *Gives:* one place that handles overlap, flip and tear (3.17). *Costs:* a copy or a layer per window; the server must be trusted with every buffer.
* **Downloadable server-side code.** A program is loaded into the display server, as the Blit's terminal program and NeWS's PostScript were: here, into the c128 core of 3.18, which would be the display server. *Gives:* the display can be given new abilities without changing the host; interaction stays local. *Costs:* a second program to secure (3.18 question 5), and the two-halves problem of the Blit ("writing one program in two pieces is much harder than writing two programs", `kernel-pain-points.md` row 12).
* **No toolkit in the base system.** The system provides windows, text and pixels; widgets, if any, are a library the program chooses. *Gives:* the size rio had; nothing to keep consistent. *Costs:* every program draws its own look, and users see the inconsistency.
* **Windows as files, or as virtio queues.** rio exposes a window as files; the pdp64's devices are virtio queues (chapter 2). A window could be a queue of drawing messages (one more virtio shape), or a file the kernel maps, or both. *Gives:* the uniformity rio and 8½ had (`kernel-pain-points.md` records "the same device interface at every level"). *Costs:* a naming and permission model for files (a chapter 6 matter) or a queue per window.

## 3.21 A design still being worked out: what a mashup of GPU, video memory, C64 and Blit could look like

The author, 2026-11-10: "conclude the graphics chapter: we're still figuring it out, what would a mashup of gpu, vram, c64 and blit look like." **Nothing in this section is decided.** Every statement is tagged *(P)* or *(S)*; the sketches are shapes of ideas put side by side so that the questions at the end can be answered, and the repository recommends none. The chain behind them: the PDP-11 terminal was a character stream (3.1), the Blit and the C64 put memory-mapped bitmaps, text, sprites and sound behind a processor or a few chips (3.3, 3.4), the PC split them (3.5), and the GPU turned drawing into queued commands and shaders (3.6); the sketches mix those inheritances.

**Two terms first.** **VRAM** (video memory) is memory that belongs to the display device: it sits on the device, behind a window on the bus, and the scanout reads it without crossing the bus; the processor reaches it through the window (slowly: every access is a bus transaction). The alternative is **system memory** that the device reads by DMA as a bus master, as the video device of 3.13.2 does; the framebuffer is then ordinary memory and the scanout competes with the processor for it. A GPU card has VRAM; the first board of the pdp64 has none to speak of (the block RAM is 5.5 megabits and a frame is 8.3 MB, 3.13.2), so on it every layer lives in system memory, and "VRAM" in the sketches below means "memory the device owns the use of", whichever kind it is. **Compositing** is combining several pictures into the one that is shown; the C64's sprites over text over a background were compositing in hardware, as the scanout read them out.

The device in these sketches is not specified beyond the 48-bit pixel and sample formats (errata 73 and 74). The properties the author has asked for, which each sketch is measured against: **(T)** simple peek/poke text and graphics at once; **(C)** modern colour depth and screen size; **(G)** glyph slots filled by a TrueType engine; **(S)** sprites, colour and sound in the C64's spirit; **(B)** the Blit's bit-blit and windows; **(U)** the GPU's command queue, parallel lanes and shaders. And the other two wishes of the day: anti-tearing sugar (3.17) and the boilerplate goal (3.16).

![Layers composed at scanout](figures/gfx-layers.svg)

### Sketch 1: layered scanout, no command queue

**3.21.1** Three **layers** (a text-cell layer, a pixel layer and a sprite layer) are plain arrays in video memory that the processor pokes; the display hardware composes them as it reads them out, one pixel at a time, and there is no command queue. *(P)*

*What the programmer sees.* Three arrays, each at a fixed place, each with a small set of registers (base, size, stride, enable). The text array is the cell array of 3.9, with its glyph slots in another array; the pixel array is a framebuffer; the sprite layer is a table of entries (x, y, shape, colour, enable). A program pokes whichever it wants, in any order. *What is in video memory:* the cells, the glyph slots, the pixels, the sprite table and the sprite shapes. *At scanout:* for each pixel the hardware asks the layers from the top down (sprites, then text, then pixels), looks the cell up to its glyph, takes the glyph's coverage and the colours, and gives the first layer that is not transparent; the sprite layer needs to know only a few entries per row. The composing is done in a **line buffer** (a small memory that holds one row), as 3.13.2 already provides for. *Costs:* a compositor of the order of the 1,500 lookup tables the repository estimates for the blitter, plus a line buffer per layer (an estimate of mine, unmeasured); scanout traffic is the pixel layer's 498 MB/s at 1920 by 1080, 4 bytes, 60 Hz (746 MB/s at 6 bytes), plus about 13 MB/s for the cells and the glyph reads (arithmetic from the examples of 3.9). *Gives up:* anything beyond what the layers can say: no scaling or rotation, no effect that is not in the compositor; every change a program wants to make to the pixel layer is the processor writing pixels. *Properties kept:* T yes (this is the C64 and the Blit's memory-mapped screen); C yes; G yes (the text layer's glyphs); S yes (sprites, and colour per cell; sound is a separate device, 3.8.3); B no (no blitter, windows are the program's job); U no. *Text and graphics split:* healed, the C64's way: a program has text and pixels at once in one frame, with no mode switch. *A game:* sprites and a scrolling text or pixel layer, moved with a few pokes a frame; the C64 game, with a modern screen. *A terminal emulator:* pokes cells (a scroll is a few stores, or, with a base register for the layer, one store); the glyph slots are filled by the TrueType engine. *Sugar:* per-layer flip and a hardware cursor for free (3.17); the fence is the vertical-blank counter. *With virtio across the board:* needs a virtio device type of its own (reading 1 of 3.9); the layers are a device's contents, not the virtio-gpu protocol.

### Sketch 2: the same, plus a small blitter and a glyph atlas

**3.21.2** Sketch 1 plus a **blitter**, a few registers that copy and combine rectangles inside video memory (the Blit's RasterOp, the Amiga's blitter; the register sketch of 3.8.4), and a glyph atlas that the TrueType engine fills and the text layer indexes. *(P)*

*What the programmer sees.* Sketch 1, and a handful of blitter registers: source, destination, strides, width, height, raster operation, go. The atlas is the glyph map seen as one picture (3.7): a glyph is drawn from it by the blitter into the pixel layer when a program wants a glyph on the pixel layer at an arbitrary position, and the text layer's cells point at it directly. *In video memory:* sketch 1's contents and the atlas. *At scanout:* as sketch 1. The blitter runs beside it, in the blanking time or contending for the memory. *Costs:* the blitter and its arbitration with scanout; the repository's own estimate is about 1,500 lookup tables and a line buffer, "nearly all address arithmetic" (3.8 commentary), and a bus-master port on video memory. *Gives up:* the same as sketch 1, except that drawing, scrolling and window moves in the pixel layer no longer cost the processor the pixels. *Properties kept:* T, C, G, S as sketch 1; **B yes** (bit-blit with the raster operations of 3.8.7, and windows as layers or as rectangles in the pixel layer); U no. *Split:* healed as sketch 1, and the pixel layer gains the Blit's operations, so that text on it (a window of a program that draws its own glyphs) is cheap. *A game:* sprites for the actors and the blitter for the background tiles. *A terminal emulator:* the text layer as in sketch 1; the blitter scrolls and moves windows drawn on the pixel layer. *Sugar:* as sketch 1, plus a blit that starts at the vertical blank (the "start-at-vblank" of `architecture-recommendations.md` R-9), which stops a copy from tearing. *With virtio:* as sketch 1, the blitter a feature of the device; it would be a feature bit and a queue if its commands are descriptors rather than registers (the chat chose a three-operand `draw` command, `decisions-pending.md` E3).

```
# sketch 2: scroll the pixel layer up by one text line, then draw a glyph from the atlas (placeholders)
poke(BLT_SRC, FB + LINE_H * STRIDE);  poke(BLT_DST, FB)
poke(BLT_STRIDE, STRIDE);  poke(BLT_W, W);  poke(BLT_H, H - LINE_H)
poke(BLT_OP, STORE);  poke(BLT_GO, 1);  wait_until(peek(BLT_BUSY) == 0)
```

### Sketch 3: a command-queue device with a peek/poke window

**3.21.3** A device whose main interface is a **ring of commands** in the manner of virtio-gpu, with a tiny shader-like fixed program for drawing glyphs and sprites and video memory managed by the device, and a peek/poke compatibility window on top for the programs that want to poke cells and pixels. *(P)*

![A command queue with a peek/poke window](figures/gfx-cmdqueue.svg)

*What the programmer sees.* Mostly commands: "put this text at this cell", "move this sprite", "fill this rectangle", "present"; and, as a convenience, the window: cells and pixels as plain memory that mirrors the device's. The device allocates its own video memory, so a program does not choose addresses. *In video memory:* what the device decides; the program sees handles. *At scanout:* the device renders the commands into whatever it scans out, at its own pace, and flips at the blank by itself (the sugar is free: a commit is a command). *Costs:* a command processor (a queue engine, as the virtio devices of chapter 2 already are), a drawing engine of fixed programs (the small piece of the GPU that the terminal needs: a textured quad with a glyph and two colours, a sprite), a memory manager for video memory and a consistency rule between the window and the queue; more gates than sketches 1 and 2 by a clear margin (a judgement of mine, unmeasured), and more software in the driver. *Gives up:* the plainness of sketch 1; the program must know the device's model, and two ways to reach one cell must be reconciled. *Properties kept:* T only through the window (and only as well as the window is made); C yes; G yes (the engine reads glyph slots); S yes; B no blit, but "fill" and "copy" commands do its job; **U yes**, a command queue and parallel work, but a *fixed* program, not the general shaders of 3.6. *Split:* healed by the engine, which draws text and pixels from one queue. *A game:* a command per sprite or per tile, one "present" per frame, with little processor work. *A terminal emulator:* one command per changed run of cells; the glyph atlas as in 3.7, but made by the device. *Sugar:* the fence and atomic commit are the natural form (each command completes in order; a commit is a command); versioned buffers are the device's business. *With virtio:* the natural fit, a device with queues as in 2.7, and the closest in spirit to virtio-gpu, of which it could be a profile (reading 2 of 3.9).

### Sketch 4: virtio-gpu 2D, the sugar in a library

**3.21.4** The standard virtio-gpu 2D route of 3.14, with the C64 and Blit conveniences done in software by a library (cells, glyphs, sprites and cursor, blits, flips), and no special hardware. *(P)*

*What the programmer sees.* A library that offers the peek/poke look: a cell array in memory, `put_char`, sprites as library objects, and a `present` call that does the transfer and the flush for the damaged rectangles. *In video memory:* the host's resources; on the pdp64 the program's memory is the backing (3.14.3). *At scanout:* the host reads its resource when it likes; the library cannot flip at a blank because virtio-gpu has none (3.14); tearing is the host's concern and, on an emulator, usually invisible. *Costs:* nothing in gates; the processor draws everything and a flush copies; bus traffic is the damage rectangles. The glyph slots are a library table, filled from the TrueType engine on the processor. *Gives up:* everything hardware: the hardware cursor is the cursor queue only, there are no sprites except the cursor, no blits, no layers; the C64's "the chip draws it while you do other things" is the library's loop. *Properties kept:* T only through the library (the program pokes memory the library owns, and the library presents it); C only to 32 bits (3.14.4); G yes, in software; S no (the cursor excepted); B in software; U no. *Split:* healed in the library's picture, but each screen is still one pixel framebuffer. *A game:* draws into a back buffer and flushes it, in the PC way of 3.5 (slow, but running now). *A terminal emulator:* the library draws glyphs from a cache and flushes the damaged rows. *Sugar:* damage rectangles and the fence only (3.17, 3.14). *With virtio:* it is the standard (errata 79, 95); sketches 1 to 3 would be added to it as another device or as a profile.

### Sketch 5: a c64-mode core as the terminal (a variant)

**3.21.5** A small core with the C64 family's chips, into which the host loads the terminal program by DMA (3.18), as a variant or addition to any of the sketches above: it is the terminal, and the other sketches say what the display behind it does. *(P)*

*What the programmer sees.* The host programmer sees a device that takes messages (the mailbox); the programmer of the small core sees the C64: peek, poke, a screen at a fixed place, colour RAM, glyph slots, sprites and the SID, which is the author's "as simple and pleasurable as the c64 was" at its most literal. *In video memory:* the core's screen memory, colour RAM, glyph slots, sprite shapes. *At scanout:* the VIC (or its extension) composes text, bitmap and sprites as sketch 1 does; the flip is a register of the core's own. *Costs:* a core, its memory, a DMA loader and the chips (3.18, question 7); a second program to write, load and keep secure. *Gives up:* a single, standard programming model on the host's side; the host cannot poke a cell, only send a message. *Properties kept:* T yes, for the core's programmer; C if the chips are widened as the native devices were (3.8); G yes; S yes, with sound; B only if the chip family has a blitter; U no. *Split:* healed, in the core. *A game:* a C64 game, or one written for the core. *A terminal emulator:* the core *is* the terminal; the host sends text. *Sugar:* the VIC's latches and raster interrupt, which the core's program uses; nothing is hidden from it. *With virtio:* the open tension of 3.18, question 6.

### The four main sketches side by side (sketch 5 is a variant of any of them)

| | S1 layers | S2 layers + blitter | S3 command queue + window | S4 virtio-gpu + library |
|---|---|---|---|---|
| What the program does | pokes arrays | pokes arrays, starts blits | writes commands (or pokes the window) | calls a library, which sends the commands of 3.14 |
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

**3.21.6** The five sketches (the four layers-and-queues shapes, and the c64-mode core as a variant) are the author's open design question, and none is decided; a combination (for example, sketch 4 now and sketch 2 or 3 as a second device later) is as open as a choice among them. *(S)*

*A leaning, mine and not the repository's.* Sketch 4 is what the first iteration already is; the author's question is what the second should be. Sketch 2 matches his words most closely (the Blit's bit-blit and the C64's text, graphics and sprites at once) and is the smallest hardware that makes peek and poke the main interface. Sketch 1 is sketch 2 without the blitter, which can be added later because it only reads and writes video memory. Sketch 3 fits better if he wants one family with virtio-gpu and a command queue as the main interface. The leaning assumes poke is the main interface; if he wants commands, sketch 3 is nearer.

**The questions the author must answer to choose** (each is repeated in 3.23): (1) **Who composes the layers**: the display hardware at scanout (1, 2), the device's engine (3), or software (4)? (2) **Where glyphs live**: a slot array the text layer indexes (1, 2), the device's own cache (3), or a library table (4); and does a cell hold a code or a slot number (3.16, pair 3)? (3) **Do sprites exist**, as a hardware layer, as an engine primitive, or only as the cursor? (4) **Is there a blitter**, and if so as registers or as commands? (5) **Are commands or pokes the main interface**, and what does the other do? (6) **Which virtio shape**: a device type of its own, a profile of virtio-gpu, or the standard device with a library, and so what the "virtio-console" of the author's words is (3.9)? (7) **VRAM or system memory** on the first board and later? (8) **What pixel format**: 48-bit native, with the standard device at 32 bits (3.14.4)?

## 3.22 What was checked, and what was not

* **Checked against the Linux headers on this machine:** `virtio_gpu.h` (command names and structures, formats and their values, the fence flag, cursor commands, `VIRTIO_GPU_MAX_SCANOUTS`, feature bits, capset ids; no vertical-blank or flip command), `virtio_console.h` and `virtio_ids.h` (the console's type 3, configuration and features; the list of device types, which has no compositor), `virtio_snd.h` (queues, formats, rates, `PCM_SET_PARAMS`, events, features), `/usr/include/drm/drm.h` and `drm_mode.h` (the page-flip, atomic and add-framebuffer ioctls and their flags, the mode structure) and `GL/glext.h` (the OpenGL entry points named).
* **Checked against QEMU sources** (`/home/david/claude/qemu-src`): `transfer_to_host_2d` and `resource_flush` and what they reject (`hw/display/virtio-gpu.c`); the `refresh_rate` field (`include/hw/virtio/virtio-gpu.h`); the rutabaga text (`docs/system/devices/virtio/virtio-gpu.rst`); the audio backends (`audio/`).
* **Checked against 2.11BSD** (`/home/david/claude/facetlang/unixtree/2.11BSD/sys/pdp/cons.h.gz` and `cons.c.gz`): the KL11/DL11 register structure, address 0177560 and `DLXCSR_TRDY`.
* **Checked against the repository's records:** the Blit's statements and numbers (the Blit and Tradeoffs papers as recorded in `docs/kernel-pain-points.md` section 14I; the Handbook quotations in section 14G); the VT52 `ESC Y` code and the "VT100/ANSI" and "xterm-256color" remarks (`c64stuff.txt`, lines 218, 4875, 4888, the assistant's words); the author's terminal chat (`docs/c64-devices-from-chat.md` section 6); the vertical-blank rules (3.8.9, errata 71); the blitter's 1,500 lookup tables (`docs/pdp64-fpga-plan.md`).
* **Unverified** (general knowledge; no manual of these machines is on this computer): everything about the C64 chips (addresses, sizes, sprite size and count, colours, the SID's voices, the processor) and the IBM PC adapters (VGA text addresses and attributes, mode 13h and the planar modes, the 64 KB window, VBE, the palette, Mode X); the details of VT52 and VT100 sequences beyond the records; **what "vt55" refers to**; the speed of a teletype; which terminal emulators use the GPU; the Valve signed-distance-field paper; the titles, dates and page counts of Michael Abrash's books; GPU lane group sizes; variable refresh and its names; the Vulkan names; EDID as a data block; the Amiga's blitter; the C128's chips; NeWS as Sun's, in PostScript, by Gosling; the toolkit comparison; the real mixers on other systems; the Cyclone V and Zynq 7020 lacking a hard PCI Express block; the line counts of boilerplate (illustrative throughout); and all gate-count estimates of the sketches (mine).
* **Decided by the author and recorded in `errata.md`:** every statement tagged *(D)*; the author's words of 2026-11-10 are in errata 105 and 106 and tagged *(P)* or *(S)*.

## 3.23 Still open

1. **What "our virtio-console device" is**: a new virtio device type, virtio-gpu extended, the real virtio-console beside a display device, or the native family (3.9.2).
2. **The sketches of 3.21**: who composes the layers, where glyphs live, whether sprites exist, whether there is a blitter, whether commands or pokes are the main interface, VRAM or system memory.
3. **Whether a cell holds a character code or a slot number**, the glyph slot's layout and the number of slots (3.16 pair 3, 3.9.3).
4. **The anti-tearing sugar** (3.17): which candidates, whether a fence, per-layer latching, variable refresh or versioned buffers are specified, and whether a tear-free flip is worth hardware when the display is variable-refresh.
5. **The boilerplate sugar** (3.16): the default mode, the canonical pixel format, stride and mapping, colour space and gamma, the units of cells and fonts for HiDPI, a palette or none.
6. **The 48-bit pixel against virtio-gpu's 32-bit formats** (3.14.4), and a write-combining memory type for the framebuffer (3.13).
7. **What the mashup device is, and its register-level definitions** (3.8, 3.11, 3.21); the feature subset of virtio-gpu and virtio-snd (3.14.2), and whether OpenBSD has a virtio-snd driver (errata 79).
8. **The block-RAM budget** and the underrun rule of the line buffer (3.13.3); the hot-plug scope (`decisions-pending.md` F23).
9. **The c64 mode** (3.18): which core, unmodified C64 software or terminal firmware only, how video memory is shared, how core and host talk, how the loaded image is authenticated and contained, how it relates to the native devices (errata 78) and to virtio across the board (errata 95), the cost, the sound path.
10. **The compositor path of the c64 mode** (3.18.4 and the five paths): the details under the author's preferred path (c), and the hand-over without tear or pop.
11. **The audio path** (3.19): where the mixer lives and who drives it, the form of the core's audio (takeover, a virtio-snd stream the host mixes, a fixed-gain mix in the device), the rate and format of the SID's output, the fade at hand-over.
12. **The window model** (3.20): a plain buffer and a rectangle, drawing as writes, a composing server, downloadable server-side code, no toolkit, windows as files or as virtio queues, and whether the c128 core is the display server.
