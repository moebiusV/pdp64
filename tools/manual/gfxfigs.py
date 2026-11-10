"""The box-and-arrow figures of chapter 3 (graphics): memory maps, cell arrays, the pipeline, the timing of a frame.

Like tools/manual/busfigs.py (whose Canvas it uses) these are drawn by hand-written code, not generated from the grammar, and
tools/mkmanual.py writes the ones the text names (figures/gfx-NAME.svg) into the figures directory of every member's manual.
Facts about historical machines (the C64 map, the VGA cell) are general knowledge, marked unverified in section 3.21 of the chapter;
the virtio-gpu command names and the field order are from /usr/include/linux/virtio_gpu.h.  All figures are 690 units wide.
"""
from busfigs import Canvas, W, GREY, SOFT, BLUE

PINK = '#f7e3dc'
GREEN = '#e1f0dd'


def fig_c64_map():
    """The C64's 64 KB address space: where the screen, colour RAM, character ROM and sprite pointers sit, and how a cell reaches its glyph."""
    c = Canvas(380)
    x, w = 20, 190
    c.text(x + w / 2, 16, 'the C64 address space (64 KB)', 12, bold=True)
    rows = [
        (30, 34, 'Kernal ROM', SOFT, '$E000-$FFFF'),
        (64, 70, 'I/O and colour RAM', BLUE, '$D000-$DFFF'),
        (134, 34, 'BASIC ROM', SOFT, '$A000-$BFFF'),
        (168, 80, 'free RAM (programs)', '#fff', '$0800-$9FFF'),
        (248, 44, 'screen memory', GREEN, '$0400-$07E7, 1000 bytes'),
        (292, 36, 'zero page, stack, system', GREY, '$0000-$03FF'),
    ]
    for y, h, lab, fill, sub in rows:
        c.box(x, y, w, h, lab, fill, 11, sub=sub)
    c.text(x + w + 6, 38, '$FFFF', 9, 'start', '#555', True)
    c.text(x + w + 6, 336, '$0000', 9, 'start', '#555', True)
    # the I/O block
    ix = 250
    c.text(ix, 58, 'inside the I/O block', 10, 'start', bold=True)
    for i, (n, d, f) in enumerate([('VIC-II', '$D000: 47 registers; $D020 border, $D021 background', PINK), ('SID', '$D400: sound registers', PINK),
                                   ('colour RAM', '$D800-$DBE7: 1000 nibbles, one per cell', GREEN), ('CIA 1, 2', '$DC00, $DD00: keyboard, timers', SOFT)]):
        c.box(ix, 66 + i * 22, 78, 22, n, f, 10)
        c.text(ix + 84, 81 + i * 22, d, 9, 'start', '#333')
    c.line([(x + w, 99), (ix - 6, 99), (ix - 6, 99), (ix, 99)], arrow=False, dash=True)
    # one cell
    c.text(ix, 184, 'one text cell = two small numbers, in two places', 10, 'start', bold=True)
    c.box(ix, 192, 110, 24, 'screen byte = 1', GREEN, 10, mono=True)
    c.box(ix, 222, 110, 24, 'colour nibble = 14', GREEN, 10, mono=True)
    c.text(ix + 118, 208, 'which glyph: code x 8 = ROM offset', 9, 'start', '#333')
    c.text(ix + 118, 238, 'which colour (of 16)', 9, 'start', '#333')
    c.line([(x + w, 270), (ix - 12, 270), (ix - 12, 204), (ix, 204)], arrow=True)
    # the glyph in the character ROM
    gx, gy = ix + 330, 190
    c.text(gx + 40, 180, 'character ROM', 10, bold=True)
    c.text(gx + 40, 170, '', 9)
    bits = ['00011000', '00111100', '01100110', '01111110', '01100110', '01100110', '01100110', '00000000']
    for r, b in enumerate(bits):
        for k, ch in enumerate(b):
            c.box(gx + k * 10, gy + r * 10, 10, 10, '', '#222' if ch == '1' else '#fff')
    c.text(gx + 40, gy + 90, '8 bytes (A)', 9, fill='#555')
    c.line([(ix + 110, 204), (gx - 8, 204), (gx - 8, gy + 14), (gx - 1, gy + 14)], arrow=True, dash=True)
    # sprite pointers
    c.text(ix, 276, 'sprite pointers: the last 8 bytes of screen memory', 10, 'start', bold=True)
    c.box(ix, 284, 160, 24, 'pointer n (a byte)', GREEN, 10, mono=True)
    c.box(ix + 230, 284, 150, 24, '63 bytes: 24 x 21 bits', '#fff', 10)
    c.line([(ix + 160, 296), (ix + 228, 296)], arrow=True)
    c.text(ix + 195, 290, 'x 64', 9, fill='#555')
    c.text(ix, 328, 'The VIC-II reads screen, colour RAM, glyphs and sprites itself, while the processor runs.', 10, 'start', '#333')
    c.text(ix, 344, 'Addresses: general knowledge of the C64 (unverified, 3.22); the glyph bits are an example.', 9, 'start', '#555')
    return c.svg()


def fig_cells_glyphs():
    """A cell array on the left, a glyph slot table on the right, an arrow from each cell to its glyph's bitmap."""
    c = Canvas(360)
    c.text(20, 16, 'the screen: an array of cells', 12, 'start', bold=True)
    c.text(400, 16, 'the glyph map: an array of slots', 12, 'start', bold=True)
    names = ['H', 'e', 'l', 'l', 'o']
    slots = {'H': 2, 'e': 3, 'l': 4, 'o': 5}
    cx, cy, cw, ch = 20, 30, 54, 128
    for i, n in enumerate(names):
        x = cx + i * (cw + 4)
        c.text(x + cw / 2, cy - 2, 'cell %d' % i, 9, fill='#555')
        for j, (f, v) in enumerate([('glyph', 'slot %d' % slots[n]), ('fg', '0xFFF'), ('bg', '0x000'), ('attr', '0')]):
            c.box(x, cy + 4 + j * 28, cw, 28, v, GREY if j else GREEN, 9, mono=True)
    gx, gw = 400, 270
    for k in range(7):
        y = 30 + k * 36
        lab = 'slot %d' % k
        c.box(gx, y, 56, 34, lab, GREY, 10, mono=True)
        if k == 0:
            c.box(gx + 56, y, gw - 56, 34, 'blank (never drawn)', '#fff', 10)
        elif k == 1:
            c.box(gx + 56, y, gw - 56, 34, 'the replacement glyph', '#fff', 10)
        elif k == 6:
            c.box(gx + 56, y, gw - 56, 34, 'free: the engine fills it on demand', '#fff', 10, dash=True)
        else:
            ch2 = 'Hel o'[k - 2] if k < 6 else ''
            c.box(gx + 56, y, gw - 56, 34, '', BLUE)
            c.text(gx + 56 + (gw - 56) / 2, y + 22, "bitmap of '%s': w x h coverage values" % 'Helo'[k - 2], 10, fill='#111')
    # arrows: cell glyph field to the slot
    for i, n in enumerate(names):
        x = cx + i * (cw + 4) + cw / 2
        s = slots[n]
        ty = 30 + s * 36 + 17
        c.line([(x, cy + 4), (x, cy - 12 - (i % 2) * 0)], arrow=False)
    # draw a few clean arrows from the bottom of the cell array
    ay = 214
    for i, n in enumerate(names):
        x = cx + i * (cw + 4) + cw / 2
        s = slots[n]
        ty = 30 + s * 36 + 17
        c.line([(x, cy + 4 + 4 * 28), (x, ay + i * 6), (gx - 14 - (i % 2) * 5 - i * 0, ay + i * 6), (gx - 14 - (i % 2) * 5, ty), (gx - 1, ty)], arrow=True)
    c.text(20, 290, 'a cell is a few bytes at  base + (row * columns + column) * cell size;  cells 0 to 4 of row 0 are shown', 9, 'start', '#555')
    c.text(20, 322, 'The same slot 4 serves both letters l: a glyph is drawn once and used by every cell that names it.', 10, 'start', '#333')
    c.text(20, 338, 'A TrueType engine rasterises each glyph into its slot (3.9.3). Field names and sizes are placeholders, not a specification.', 9, 'start', '#555')
    c.text(20, 352, 'Slot 6 shows an empty slot, to be filled when a cell first needs it.', 9, 'start', '#555')
    return c.svg()


def fig_vga_cell():
    """VGA colour text mode: two bytes a cell at 0xB8000, the character byte and the attribute byte."""
    c = Canvas(270)
    c.text(20, 16, 'VGA colour text mode: 80 x 25 cells of two bytes, from 0xB8000', 12, 'start', bold=True)
    x0 = 20
    for i in range(5):
        a = 0xB8000 + 2 * i
        c.box(x0 + i * 60, 30, 30, 26, 'ch', GREEN, 10)
        c.box(x0 + i * 60 + 30, 30, 30, 26, 'at', BLUE, 10)
        c.text(x0 + i * 60, 70, '%X' % a, 8, 'start', '#555', True)
    c.text(x0 + 310, 46, '... 2000 cells, 4000 bytes', 10, 'start', '#333')
    # zoom
    zx, zy = 20, 120
    c.text(zx, 108, 'one cell, the attribute byte opened (bit 7 is the left end):', 10, 'start', bold=True)
    fields = [(8, 'character code (one byte)', GREEN, 'byte 0: the glyph number in the font'), ]
    c.box(zx, zy, 240, 30, 'character code, bits 7 to 0', GREEN, 11)
    c.text(zx + 250, zy + 19, 'even address: which glyph (code page 437 on a PC: unverified)', 9, 'start', '#333')
    parts = [(1, 'B', PINK), (3, 'background', BLUE), (4, 'foreground', BLUE)]
    x = zx
    unit = 30
    for n, lab, f in parts:
        c.box(x, zy + 44, n * unit, 30, lab, f, 10 if n > 1 else 9)
        x += n * unit
    for k in range(8):
        c.text(zx + k * unit + unit / 2, zy + 90, str(7 - k), 9, fill='#555', mono=True)
    c.text(zx + 250, zy + 63, 'odd address: attribute. 4 bits a colour: 16 colours', 9, 'start', '#333')
    c.text(zx + 250, zy + 76, 'bit 7: blink, or a bright background (a mode bit chooses)', 9, 'start', '#333')
    c.text(zx, 244, 'The glyph shapes are in the display adapter, not in this memory; the cell says which, and in what colours.', 10, 'start', '#333')
    c.text(zx, 260, 'Layout as in general knowledge of the IBM PC adapters (unverified here, 3.22).', 9, 'start', '#555')
    return c.svg()


def fig_framebuffer():
    """A framebuffer: rows of pixels in one-dimensional memory, with a stride that may exceed the width."""
    c = Canvas(300)
    c.text(20, 16, 'a framebuffer: a picture stored as rows in one-dimensional memory', 12, 'start', bold=True)
    px, py, cs = 20, 34, 24
    wd, ht, pad = 8, 5, 2
    for r in range(ht):
        for k in range(wd + pad):
            if k < wd:
                c.box(px + k * cs, py + r * cs, cs, cs, '', '#fff' if (r + k) % 2 else SOFT)
            else:
                c.box(px + k * cs, py + r * cs, cs, cs, '', GREY, dash=True)
    c.text(px + wd * cs / 2, py + ht * cs + 14, 'width = 8 pixels', 10, bold=False)
    c.text(px + (wd + pad / 2) * cs, py + ht * cs + 14, 'padding', 9, fill='#555')
    c.line([(px, py + ht * cs + 24), (px + (wd + pad) * cs, py + ht * cs + 24)], arrow=True)
    c.text(px + (wd + pad) * cs / 2, py + ht * cs + 38, 'stride = bytes from the start of one row to the start of the next', 10, fill='#333')
    # the memory strip
    mx = 330
    c.text(mx, 28, 'the same bytes, as memory sees them', 11, 'start', bold=True)
    for r in range(ht):
        y = 38 + r * 30
        c.box(mx, y, 200, 24, 'row %d: pixels 0 to 7' % r, SOFT if r % 2 else '#fff', 10)
        c.box(mx + 200, y, 50, 24, 'pad', GREY, 9, dash=True)
        c.text(mx + 258, y + 16, 'base + %d x stride' % r, 9, 'start', '#555', True)
    c.text(mx, 206, 'address of pixel (x, y) = base + y * stride + x * bytes_per_pixel', 10, 'start', bold=True, mono=False)
    c.text(mx, 222, 'e.g. 1920 x 1080, 4 bytes a pixel: stride 7680, 8,294,400 bytes', 10, 'start', '#333')
    c.text(mx, 238, 'the display reads this from the top row down, ~60 times a second', 10, 'start', '#333')
    c.text(20, 286, 'Padding makes every row start on an aligned address; software must use the stride, not width x bytes.', 9, 'start', '#555')
    return c.svg()


def fig_pipeline():
    """The graphics pipeline as boxes."""
    c = Canvas(330)
    c.text(20, 16, 'the graphics pipeline: data goes in at the left, pixels come out at the right', 12, 'start', bold=True)
    y, h = 50, 60
    xs = [10, 150, 290, 430, 570]
    labs = [('vertices', 'a list of points in memory', SOFT), ('vertex shader', 'a small program, run once per vertex', PINK),
            ('rasterizer', 'fixed hardware: which pixels does each triangle cover?', GREY), ('pixel shader', 'a small program, run once per pixel', PINK),
            ('framebuffer', 'the colour of each pixel, blended in', GREEN)]
    for x, (a, b, f) in zip(xs, labs):
        c.box(x, y, 110, h, a, f, 11, bold=True)
    for x, (a, b, f) in zip(xs, labs):
        # subtitle wrapped in two lines
        words = b.split(' ')
        half = (len(words) + 1) // 2
        c.text(x + 55, y + h + 14, ' '.join(words[:half]), 9, fill='#333')
        c.text(x + 55, y + h + 26, ' '.join(words[half:]), 9, fill='#333')
    for i in range(4):
        c.line([(xs[i] + 110, y + h / 2), (xs[i + 1], y + h / 2)])
    c.box(430, 190, 110, 40, 'texture', BLUE, 11, bold=True, sub='an image the shader may read')
    c.line([(485, 190), (485, y + h + 34)], arrow=True)
    c.box(150, 190, 110, 40, 'uniforms', SOFT, 11, bold=True, sub='numbers shared by all')
    c.line([(205, 190), (205, y + h + 34)], arrow=True)
    c.text(20, 270, 'Every vertex goes through the same program at the same time on different lanes; so does every pixel.', 10, 'start', '#333')
    c.text(20, 286, 'The programmer writes the two shaders (pink); the rasterizer between them is fixed.', 10, 'start', '#333')
    c.text(20, 304, 'This is the model of general knowledge of current GPUs (unverified here, 3.22); stages such as geometry and tessellation are left out.', 9, 'start', '#555')
    return c.svg()


def fig_atlas():
    """A glyph atlas and a screen grid: one textured quad per cell."""
    c = Canvas(330)
    c.text(20, 16, 'a glyph atlas (drawn once) ...', 12, 'start', bold=True)
    c.text(380, 16, '... and the screen grid (one quad a cell)', 12, 'start', bold=True)
    letters = 'ABCDEFGHabcdefghIJKLMNOPijklmnop'
    ax, ay, s = 20, 30, 30
    for k, L in enumerate(letters):
        r, q = divmod(k, 8)
        c.box(ax + q * s, ay + r * s, s, s, L, BLUE if L in 'Hel o' else '#fff', 12, mono=True)
    c.text(ax, ay + 4 * s + 16, 'one texture in video memory: every glyph the screen uses, side by side', 9, 'start', '#555')
    gx, gy, gs = 380, 30, 34
    msg = ['Hell', 'o,  ']
    for r in range(3):
        for q in range(8):
            t = ''
            if r < 2 and q < 4:
                t = msg[r][q]
            c.box(gx + q * gs, gy + r * gs, gs, gs, t, GREEN if t.strip() else '#fff', 12, mono=True)
    # arrows from atlas H to grid cell (0,0), and e to (0,1)
    c.line([(ax + 6 * s + 15, ay + 30), (ax + 6 * s + 15, ay + 4 * s + 44), (gx - 20, ay + 4 * s + 44), (gx - 20, gy + 17), (gx - 1, gy + 17)], arrow=True, dash=True)
    c.text(gx + 4 * gs + 14, gy + 20, 'cell (0,0): quad with', 9, 'start', '#333')
    c.text(gx + 4 * gs + 14, gy + 32, 'texture rectangle = H', 9, 'start', '#333')
    c.text(20, 222, 'To draw the screen: send the GPU a list with one entry per cell, and run one draw call.', 10, 'start', bold=True)
    for i, t in enumerate(['entry = (cell column, cell row, atlas rectangle of the glyph, foreground, background)',
                           'vertex shader: turn the cell position into screen corners; pixel shader: look the glyph up, mix fg and bg',
                           'a change of one cell, or a scroll by a row, is a change to the list or to a number, not to 2 million pixels']):
        c.text(20, 240 + i * 16, t, 10, 'start', '#333')
    c.text(20, 300, 'The atlas is made by a font rasteriser (CPU) and uploaded once; new glyphs are added as they first appear.', 9, 'start', '#555')
    return c.svg()


def fig_virtio_seq():
    """The virtio-gpu 2D command sequence, as a sequence diagram: names from virtio_gpu.h."""
    c = Canvas(430)
    dx, vx = 130, 560
    c.text(dx, 16, 'driver (the pdp64)', 12, bold=True)
    c.text(vx, 16, 'virtio-gpu device', 12, bold=True)
    c.line([(dx, 24), (dx, 416)], arrow=False, dash=True)
    c.line([(vx, 24), (vx, 416)], arrow=False, dash=True)
    steps = [
        ('RESOURCE_CREATE_2D', 'resource_id=1, format, width, height', 'a host-side picture, named 1'),
        ('RESOURCE_ATTACH_BACKING', 'resource_id=1, nr_entries, then {addr, length} x n', 'tell it which pages of my memory back the picture'),
        ('SET_SCANOUT', 'rect, scanout_id=0, resource_id=1', 'display resource 1 on output 0'),
        (None, 'the driver draws into its own memory (the backing pages)', ''),
        ('TRANSFER_TO_HOST_2D', 'rect, offset, resource_id=1', 'copy this rectangle from my memory into the picture'),
        ('RESOURCE_FLUSH', 'rect, resource_id=1', 'now show this rectangle on screen'),
    ]
    y = 46
    for name, args, mean in steps:
        if name is None:
            c.box(dx - 100, y, 200, 28, 'draw pixels into the backing memory', GREEN, 10)
            y += 46
            continue
        c.line([(dx, y + 8), (vx, y + 8)])
        c.text((dx + vx) / 2, y, name, 11, bold=True, mono=True)
        c.text((dx + vx) / 2, y + 22, args, 9, fill='#333')
        c.text(dx + 8, y + 36, mean, 9, 'start', '#555')
        c.line([(vx, y + 40), (dx, y + 40)], dash=True, width=1)
        c.text((dx + vx) / 2 + 170, y + 52, 'OK_NODATA', 8, fill='#555', mono=True)
        y += 62
    c.text(20, 424, 'Each line is one command in the control queue, answered by a response; the header of every command is a type, flags, a fence id, a context id.', 9, 'start', '#555')
    return c.svg()


def fig_tearing():
    """Scanout row position against time: a tear in a single buffer, and a page flip at the blank."""
    c = Canvas(450)
    X0, X1 = 70, 670
    T = 150  # one frame, drawn 150 units wide, then a 30-unit blank
    def panel(y0, title, flip):
        c.text(20, y0 - 8, title, 12, 'start', bold=True)
        top, bot = y0, y0 + 130
        c.text(X0 - 8, top + 4, 'row 0', 9, 'end', '#555')
        c.text(X0 - 8, bot + 4, 'last row', 9, 'end', '#555')
        c.line([(X0, top), (X1, top)], arrow=False, width=0.6)
        c.line([(X0, bot), (X1, bot)], arrow=False, width=0.6)
        for k in range(3):
            xs = X0 + k * 190
            c.o.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" opacity="0.5"/>' % (xs + T, top, 40, bot - top, '#ddd'))
            c.line([(xs, top), (xs + T, bot)], arrow=False, width=1.8)
            c.text(xs + T + 20, top + 70, 'blank', 8, fill='#555')
        c.text(X0 + 30, top - 8 + 0, '', 8)
        return top, bot
    top, bot = panel(40, 'single buffer: the program draws frame N+1 into the picture being shown', False)
    # the drawing activity: a vertical band at time tw in frame 1; picture changes at that instant
    tw = X0 + 190 + 70
    c.line([(tw, top - 4), (tw, bot + 4)], arrow=False, dash=True, width=1.2)
    c.text(tw + 8, top + 18, 'the program writes the new frame here', 9, 'start', '#333')
    ry = top + 70 * 130 / 150.0
    c.o.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" opacity="0.7"/>' % (tw, top, 6, bot - top, '#f2b8a8'))
    c.text(X0 + 190 + T - 30, bot + 18, 'rows read before the write show frame N;', 9, 'end', '#333')
    c.text(X0 + 190 + T - 30, bot + 30, 'rows read after show frame N+1: a TEAR at the line', 9, 'end', '#333')
    # the tear line: the scanout position at time tw
    tx = tw
    ty = top + (tw - (X0 + 190)) * 130 / T
    c.line([(X0 + 190, ty), (X0 + 190 + T, ty)], arrow=False, dash=True, width=1.2)
    c.text(X0 + 190 + T + 4, ty + 4, 'tear', 10, 'start', bold=True)
    top2, bot2 = panel(240, 'double buffer: draw into the hidden picture; the base address changes in the blank', True)
    for k in range(2):
        xs = X0 + 190 * k
        c.text(xs + 50, bot2 - 14, 'shows A' if k == 0 else 'shows B', 10, fill='#333')
        c.o.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" opacity="0.6"/>' % (xs + 10, bot2 + 4, 140, 10, '#cfe3c9'))
    c.text(X0 + 20, bot2 + 28, 'program draws into B while A is shown', 9, 'start', '#333')
    flip = X0 + 190 * 1 - 20
    c.line([(X0 + 150 + 20, top2), (X0 + 150 + 20, bot2)], arrow=False, dash=True, width=1.4)
    c.text(X0 + 150 + 24, bot2 + 44, 'flip: base A to B, latched in the blank', 9, 'start', bold=True)
    c.text(20, 440, 'Time runs to the right; a frame is about 16.7 ms at 60 Hz (an example rate). The slanted line is the display reading one row after another.', 9, 'start', '#555')
    return c.svg()


def fig_layers():
    """Sketches 1 and 2: three layers in video memory composed at scanout; sketch 2 adds a blitter and a glyph atlas."""
    c = Canvas(380)
    c.text(20, 16, 'sketches 1 and 2: layers in video memory, composed by the display hardware as it reads them out', 12, 'start', bold=True)
    c.box(20, 36, 120, 56, 'CPU', SOFT, 12, bold=True, sub='pokes and peeks')
    # the three layers
    lx = 230
    c.box(lx, 30, 190, 40, 'sprite layer', PINK, 11, sub='position, pointer, colour: a table')
    c.box(lx, 76, 190, 40, 'pixel layer', GREEN, 11, sub='rows of pixels, base, stride')
    c.box(lx, 122, 190, 40, 'text layer', BLUE, 11, sub='cells: glyph, fg, bg, attr')
    c.box(lx, 168, 190, 40, 'glyph slots', '#fff', 11, sub='bitmaps the TrueType engine writes')
    c.text(lx + 95, 224, 'all in video memory, plain arrays', 9, fill='#555')
    c.line([(140, 64), (lx, 50)], arrow=True)
    c.line([(140, 64), (lx, 96)], arrow=True)
    c.line([(140, 64), (lx, 142)], arrow=True)
    c.line([(140, 64), (lx - 10, 64), (lx - 10, 188), (lx, 188)], arrow=True)
    c.text(20, 120, 'peek / poke', 10, 'start', '#333')
    # compositor
    c.box(500, 66, 90, 100, 'scanout', GREY, 12, bold=True, sub='composes the layers')
    c.text(545, 176, 'a pixel at a time', 9, fill='#555')
    for y in (50, 96, 142):
        c.line([(lx + 190, y), (500, 90 + (y - 50) * 0.4)], arrow=True)
    c.line([(lx + 190, 188), (545, 188), (545, 166)], arrow=True, dash=True)
    c.box(610, 96, 70, 40, 'HDMI', SOFT, 11, bold=True)
    c.line([(590, 116), (610, 116)])
    # the blitter (sketch 2)
    c.box(20, 260, 150, 54, 'blitter (sketch 2)', '#fff', 11, bold=True, dash=True, sub='copy / combine rectangles')
    c.line([(95, 260), (95, 100), (95, 100)], arrow=False, dash=True)
    c.line([(170, 287), (lx - 20, 287), (lx - 20, 250), (lx + 95, 250), (lx + 95, 232)], arrow=True, dash=True)
    c.text(lx + 100, 250, '', 9)
    c.text(20, 340, 'Sketch 1: the CPU writes the arrays; the display hardware does the composing; there is no command queue.', 10, 'start', '#333')
    c.text(20, 356, 'Sketch 2: the same, plus a few registers that move rectangles inside video memory (scrolling, window moves, glyph copies).', 10, 'start', '#333')
    c.text(20, 372, 'Nothing here is decided (3.21); the boxes are the shape of the idea.', 9, 'start', '#555')
    return c.svg()


def fig_cmdqueue():
    """Sketch 3: a ring of commands, a small drawing engine, video memory managed by the device, a peek/poke window on top."""
    c = Canvas(330)
    c.text(20, 16, 'sketch 3: commands in a ring, a small drawing engine, and a peek/poke window on top', 12, 'start', bold=True)
    c.box(20, 40, 110, 50, 'CPU', SOFT, 12, bold=True)
    c.box(190, 36, 150, 60, 'command ring', GREEN, 11, bold=True, sub='in memory: avail / used rings')
    c.box(400, 36, 130, 60, 'drawing engine', PINK, 11, bold=True, sub='tiny fixed program per cell or sprite')
    c.box(400, 150, 130, 60, 'video memory', BLUE, 11, bold=True, sub='managed by the device')
    c.box(570, 150, 100, 60, 'scanout', GREY, 12, bold=True)
    c.box(190, 150, 150, 50, 'peek/poke window', '#fff', 11, bold=True, dash=True, sub='cells and pixels as plain memory')
    c.line([(130, 60), (190, 60)])
    c.line([(340, 66), (400, 66)])
    c.line([(465, 96), (465, 150)])
    c.line([(530, 180), (570, 180)])
    c.line([(75, 90), (75, 175), (190, 175)], arrow=True)
    c.line([(340, 175), (400, 175)], arrow=True)
    c.text(20, 250, 'The program mostly writes commands (put this text, move this sprite); the window is for the cases where a poke is simpler.', 10, 'start', '#333')
    c.text(20, 266, 'The window and the engine both reach video memory, so the device must say which one wins when they touch the same cell.', 10, 'start', '#333')
    c.text(20, 290, 'Nothing here is decided (3.21).', 9, 'start', '#555')
    return c.svg()


def fig_core_map():
    """The c64-mode idea: the host's program image, the DMA copy, and the small core's address space."""
    c = Canvas(380)
    c.text(20, 16, 'c64 mode: the host loads a program into a small core on the die, and the core is the terminal', 12, 'start', bold=True)
    # host side
    c.box(20, 40, 150, 150, '', SOFT)
    c.text(95, 56, 'host memory', 11, bold=True)
    c.box(34, 66, 122, 44, 'program image', GREEN, 11, bold=True, sub='terminal code')
    c.box(34, 122, 122, 52, 'doorbell / mailbox', '#fff', 10, mono=True, sub='host and core talk')
    # DMA
    c.box(205, 66, 90, 44, 'DMA engine', GREY, 11, bold=True, sub='copies the image')
    c.line([(156, 88), (205, 88)])
    c.text(180, 78, '1', 10, bold=True)
    # core address space
    cx, cw = 345, 190
    c.text(cx + cw / 2, 36, "the small core's address space", 11, bold=True)
    rows = [('loaded program', GREEN, 'from the host'), ('screen memory', BLUE, 'cells'), ('colour RAM', BLUE, 'a colour a cell'),
            ('glyph slots', BLUE, 'filled by the TrueType engine'), ('VIC registers', PINK, 'video'), ('SID registers', PINK, 'sound'), ('mailbox window', '#fff', 'shared with the host')]
    for i, (n, f, sub) in enumerate(rows):
        c.box(cx, 44 + i * 36, cw, 36, n, f, 11, sub=sub)
    c.line([(295, 88), (cx, 62)])
    c.text(320, 66, '2', 10, bold=True)
    # reset
    c.box(205, 150, 90, 40, 'reset line', '#fff', 11, bold=True, dash=True, sub='held until loaded')
    c.line([(295, 170), (320, 170), (320, 62 + 0), (cx, 62 + 0)], arrow=False, dash=True)
    c.text(256, 208, '3: released', 9, fill='#333')
    # mailbox arrow
    c.line([(cx, 44 + 6 * 36 + 18), (180, 44 + 6 * 36 + 18), (180, 174), (156, 174)], arrow=True, dash=True)
    # outputs
    c.box(560, 60, 100, 40, 'video out', GREY, 11, bold=True, sub='to HDMI')
    c.box(560, 150, 100, 40, 'audio out', GREY, 11, bold=True, sub='to HDMI audio')
    c.line([(cx + cw, 62 + 72), (560, 80)], arrow=True)
    c.line([(cx + cw, 44 + 5 * 36 + 18), (560, 170)], arrow=True)
    c.text(20, 318, '1  the host places the image in its own memory; the device copies it into the core by DMA (over PCI Express).', 10, 'start', '#333')
    c.text(20, 334, '2  the program lands at the core\'s load address;  3  the core is let out of reset and runs it as the terminal.', 10, 'start', '#333')
    c.text(20, 356, 'Which core, what the mailbox is, and how the image is checked are open (3.18); sizes and order are an example.', 9, 'start', '#555')
    return c.svg()


def fig_compositor_paths():
    """Five data paths for a c64-mode core that shares the display with the host: boxes and arrows, one row each."""
    c = Canvas(430)
    c.text(20, 16, 'five ways the c64-mode core and the host could share the display and the audio', 12, 'start', bold=True)
    def row(y, tag, boxes, note):
        c.text(20, y + 24, tag, 11, 'start', bold=True)
        x = 50
        pos = []
        for lab, fill, w, dash in boxes:
            c.box(x, y + 6, w, 34, lab, fill, 9, dash=dash)
            pos.append((x, w))
            x += w + 24
        for i in range(len(pos) - 1):
            c.line([(pos[i][0] + pos[i][1], y + 23), (pos[i + 1][0], y + 23)])
        c.text(x - 12, y + 27, note, 9, 'start', '#555')
        return pos
    row(30, '(a)', [('c128 core', GREEN, 74, False), ('enable bit: output owner', GREY, 150, False), ('scanout 0 + audio', BLUE, 90, False)], 'exclusive: host picture off while on')
    row(94, '(b)', [('c128 core', GREEN, 74, False), ('scanout 1 + stream 2', BLUE, 130, False), ('host: head 0 + sound', SOFT, 150, False)], 'a second head and stream')
    row(158, '(c)', [('c128 core', GREEN, 74, False), ('resource / blob', BLUE, 90, False), ('host compositor: a window', GREY, 130, False), ('scanout', BLUE, 60, False)], 'a client of the host')
    row(222, '(d)', [('c128 layer', GREEN, 74, False), ('host layer', SOFT, 74, False), ('scanout composes layers', GREY, 130, False), ('HDMI', BLUE, 50, False)], 'planes in hardware (sketch 1)')
    row(286, '(e)', [('c128 core', GREEN, 74, False), ('host clients', SOFT, 74, False), ('no such virtio device', '#fff', 150, True), ('scanout', BLUE, 60, False)], 'a device type that does not exist')
    c.text(20, 372, 'Green: the on-die core. Blue: output. Grey: the arbiter. Dashed: a thing that would have to be invented.', 10, 'start', '#333')
    c.text(20, 388, 'In (a) the multiplexer is one enable bit; in (b) to (e) the core becomes a client of something else.', 10, 'start', '#333')
    c.text(20, 408, 'The hand-over of any of these should happen in a vertical blank, with the audio muted by a short ramp (3.18).', 9, 'start', '#555')
    return c.svg()


def fig_audio_path():
    """The audio path drawn beside the video path: streams, a combining stage, a buffer read at a fixed rate, the converter."""
    c = Canvas(300)
    c.text(20, 16, 'pixels and sound: several sources, one combiner, one buffer read at a fixed rate', 12, 'start', bold=True)
    def chain(y, tag, labs):
        c.text(20, y + 22, tag, 11, 'start', bold=True)
        x = 64
        pos = []
        for lab, sub, fill, w in labs:
            c.box(x, y + 4, w, 40, lab, fill, 10, bold=True, sub=sub)
            pos.append((x, w))
            x += w + 22
        for i in range(len(pos) - 1):
            c.line([(pos[i][0] + pos[i][1], y + 24), (pos[i + 1][0], y + 24)])
    chain(36, 'video', [('windows', 'buffers: app, app, c128', GREEN, 110), ('compositor', 'place, overlap, flip', GREY, 105),
                        ('framebuffer', 'rows of pixels', BLUE, 95), ('scanout', 'reads at 60 Hz: tear', PINK, 120), ('HDMI video', '', '#fff', 80)])
    chain(120, 'audio', [('streams', 'app, app, SID', GREEN, 110), ('convert', 'rate, format, volume', SOFT, 105),
                         ('mixer', 'sum, clip or limit', GREY, 95), ('ring buffer', 'read at 48 kHz: underrun', PINK, 120), ('DAC / HDMI audio', '', '#fff', 100)])
    c.text(20, 206, 'A late frame tears; a late buffer underruns: a click. Both are cured by writing ahead of the reader and by', 10, 'start', '#333')
    c.text(20, 222, 'letting the device clock, not the program clock, decide when the combiner runs.', 10, 'start', '#333')
    c.text(20, 246, 'The SID is the C64\'s exception: it makes the sound itself from three voices, so it has no buffer and no mixer in memory.', 10, 'start', '#333')
    c.text(20, 270, 'Stages after the model of general knowledge of sound servers (unverified, 3.22); virtio-snd streams as in virtio_snd.h.', 9, 'start', '#555')
    return c.svg()


FIGURES = {
    'gfx-c64-map': ('The C64 address space', fig_c64_map),
    'gfx-cells-glyphs': ('A cell array and a glyph slot table', fig_cells_glyphs),
    'gfx-vga-cell': ('A VGA text-mode cell', fig_vga_cell),
    'gfx-framebuffer': ('A framebuffer with a stride', fig_framebuffer),
    'gfx-pipeline': ('The graphics pipeline', fig_pipeline),
    'gfx-atlas': ('A glyph atlas and a screen grid of quads', fig_atlas),
    'gfx-virtio-seq': ('The virtio-gpu command sequence', fig_virtio_seq),
    'gfx-tearing': ('Scanout and tearing against time', fig_tearing),
    'gfx-layers': ('Layers composed at scanout', fig_layers),
    'gfx-core-map': ('A small core as the terminal: the loaded program and its address space', fig_core_map),
    'gfx-compositor-paths': ('Five data paths for a c64-mode core sharing the display', fig_compositor_paths),
    'gfx-audio-path': ('The audio path beside the video path', fig_audio_path),
    'gfx-cmdqueue': ('A command queue with a peek/poke window', fig_cmdqueue),
}
