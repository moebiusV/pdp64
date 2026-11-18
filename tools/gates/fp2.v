// Floating-point, tile, GEMM-sequencer, gather and conversion blocks for docs/encoding-work/vec-silicon.md (counted with gates2.sh, the flow of gates.sh).
// Single precision only.  The fused multiply-add keeps the full 74-bit frame (3 x 24 + 2) of a fused unit; infinities and NaNs are not handled (their logic, a few hundred gates, is not
// counted); subnormal inputs are read as zero and results below the normal range are flushed to zero; rounding is to nearest even.

// fma32: a * b + c, one rounding.  The frame is 74 bits (3 x 24 + 2): the product at bits [49:2], the addend C placed at [73:50] and shifted right by d + 25 (d the exponent difference,
// limited to 0 to 74, the bits shifted out kept as a sticky bit).  When C is more than 25 binades above the product, the product should be shifted right as well (a second, small
// shifter and a sticky: not built here; the model then rounds that corner case wrongly, the gate count is short by about 5%).
module fma32(input [31:0] a, input [31:0] b, input [31:0] c, output reg [31:0] y);
  reg sa, sb, sc, sp, effsub, sres;
  reg [7:0] ea, eb, ec;
  reg [23:0] ma, mb, mc;
  reg [47:0] prod;
  reg signed [10:0] pe, d, er, ef;
  reg [6:0] sh;
  reg [73:0] pw, cw, cwsh;
  reg sticky;
  reg [74:0] sum, mag;
  reg [6:0] lz;
  reg [74:0] nrm;
  reg [24:0] man;
  reg g, st, inc;
  integer i;
  always @* begin
    sa = a[31]; sb = b[31]; sc = c[31]; ea = a[30:23]; eb = b[30:23]; ec = c[30:23];
    ma = {ea != 0, a[22:0]}; mb = {eb != 0, b[22:0]}; mc = {ec != 0, c[22:0]};
    prod = ma * mb; sp = sa ^ sb;
    pe = $signed({3'b0, ea}) + $signed({3'b0, eb}) - 11'sd127;
    d = pe - $signed({3'b0, ec});
    pw = {24'b0, prod, 2'b0};
    if (d + 11'sd25 <= 0) sh = 0; else if (d + 11'sd25 > 74) sh = 74; else sh = d + 11'sd25;
    cw = {mc, 50'b0};
    cwsh = cw >> sh;
    sticky = 0; for (i = 0; i < 74; i = i + 1) if (i < sh) sticky = sticky | cw[i];
    effsub = sp ^ sc;
    sum = {1'b0, pw} + (effsub ? ~{1'b0, cwsh} + 75'd1 : {1'b0, cwsh});
    sres = sp;
    mag = sum;
    if (sum[74]) begin mag = ~sum + 75'd1; sres = ~sp; end
    lz = 0;
    for (i = 74; i >= 0; i = i - 1) if (mag[i] && lz == 0 && (i == 74 || ((mag >> (i + 1)) == 0))) lz = 74 - i;
    nrm = mag << lz;
    ef = (d < -11'sd25) ? $signed({3'b0, ec}) - 11'sd25 : pe;
    er = ef + 11'sd26 - $signed({4'b0, lz});
    man = {1'b0, nrm[74:51]}; g = nrm[50]; st = (nrm[49:0] != 0) | sticky;
    inc = g & (st | man[0]);
    man = man + inc;
    if (man[24]) er = er + 1;
    y = (mag == 0 || er <= 0) ? {sres, 31'b0} : (er >= 255) ? {sres, 8'hff, 23'b0} : {sres, er[7:0], man[24] ? 23'b0 : man[22:0]};
  end
endmodule

// 8 lanes: the floating-point multiply-add lanes of the vector unit (vfma and the rest of the floating-point lane operations are this)
module fma32x8(input [255:0] a, input [255:0] b, input [255:0] c, output [255:0] y);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g fma32 f(a[32*i +: 32], b[32*i +: 32], c[32*i +: 32], y[32*i +: 32]); end endgenerate
endmodule
module fma32x2(input [63:0] a, input [63:0] b, input [63:0] c, output [63:0] y);
  fma32 f0(a[31:0], b[31:0], c[31:0], y[31:0]); fma32 f1(a[63:32], b[63:32], c[63:32], y[63:32]); endmodule

// the tile of vec-isa.md: 8 x 8 single-precision accumulators (2,048 flops), the outer-product update C[i][j] += A[i] * B[j] by 64 multiply-adds,
// the read and write of a row (vtld, vtst: row select of 256 bits), the clear (vtclr), the add of a vector into the rows (vtadd as a row add is left out: it uses the fma lanes)
module tile8x8(input clk, input clr, input opa, input [255:0] A, input [255:0] B, input rd, input [2:0] row, input wr, input [255:0] wd, output [255:0] q);
  reg [31:0] t [0:63];
  wire [31:0] nx [0:63];
  genvar i, j;
  generate for (i = 0; i < 8; i = i + 1) begin: r for (j = 0; j < 8; j = j + 1) begin: c
    fma32 f(A[32*i +: 32], B[32*j +: 32], t[8*i + j], nx[8*i + j]);
  end end endgenerate
  integer k;
  always @(posedge clk) for (k = 0; k < 64; k = k + 1) begin
    if (clr) t[k] <= 0;
    else if (opa) t[k] <= nx[k];
    else if (wr && (k / 8) == row) t[k] <= wd[32*(k % 8) +: 32];
  end
  assign q = {t[8*row + 7], t[8*row + 6], t[8*row + 5], t[8*row + 4], t[8*row + 3], t[8*row + 2], t[8*row + 1], t[8*row]};
endmodule
// the tile without the 64 multiply-adds: the 2,048 accumulator flops, the clear, the row write and the row read (the rest of the tile's cost)
module tile_state(input clk, input clr, input opa, input [2047:0] nx, input rd, input [2:0] row, input wr, input [255:0] wd, output [255:0] q);
  reg [31:0] t [0:63];
  integer k;
  always @(posedge clk) for (k = 0; k < 64; k = k + 1) begin
    if (clr) t[k] <= 0;
    else if (opa) t[k] <= nx[32*k +: 32];
    else if (wr && (k / 8) == row) t[k] <= wd[32*(k % 8) +: 32];
  end
  assign q = {t[8*row + 7], t[8*row + 6], t[8*row + 5], t[8*row + 4], t[8*row + 3], t[8*row + 2], t[8*row + 1], t[8*row]};
endmodule

// the whole-GEMM sequencer (gemm.f): descriptor of three matrices (base, row stride) and the three loop counts M, N, K in 32 bits; the current addresses of A, B and C advance
// by the strides; the three loop counters; the state.  The DMA engine, the 64 KB of buffer SRAM and its ports are not in this count.
module gemm_seq(input clk, input start, input [63:0] pa, input [63:0] pb, input [63:0] pc, input [31:0] sa, input [31:0] sb, input [31:0] sc, input [31:0] m, input [31:0] n, input [31:0] k,
                output reg [63:0] aa, output reg [63:0] ab, output reg [63:0] ac, output reg busy, output reg [1:0] st);
  reg [31:0] i, j, l, M, N, K, SA, SB, SC;
  reg [63:0] ra, rb, rc;
  wire lastl = (l + 1 == K), lastj = (j + 1 == N), lasti = (i + 1 == M);
  always @(posedge clk) begin
    if (start) begin
      aa <= pa; ab <= pb; ac <= pc; ra <= pa; rb <= pb; rc <= pc; SA <= sa; SB <= sb; SC <= sc; M <= m; N <= n; K <= k; i <= 0; j <= 0; l <= 0; busy <= 1; st <= 0;
    end else if (busy) begin
      aa <= aa + 64'd32; ab <= ab + {32'b0, SB};
      if (lastl) begin l <= 0; ab <= rb;
        ac <= ac + {32'b0, SC}; aa <= ra;
        if (lastj) begin j <= 0; rb <= rb; ra <= ra + {32'b0, SA}; aa <= ra + {32'b0, SA}; if (lasti) busy <= 0; else i <= i + 1; end
        else j <= j + 1;
      end else l <= l + 1;
    end
  end
endmodule

// gather (vldx) -------------------------------------------------------------------------------------------------------------------------------------------------------
// the address generators of a gather that issues one lane a cycle: gather1 of blocks.v is that (1,260 and 68 flops); 4 lanes a cycle: four adders; all 32 lanes: 32 adders.
module gather_agen32(input [63:0] base, input [255:0] idx, input [1:0] sc, output [2047:0] addr);			// 32 byte-lane indices of 8 bits (the finest case); 64-bit addresses
  genvar i; generate for (i = 0; i < 32; i = i + 1) begin: g assign addr[64*i +: 64] = base + ({56'b0, idx[8*i +: 8]} << sc); end endgenerate
endmodule
// the merge: the element that comes back (64 bits, aligned to its low end) written into lane `lane` of the destination register of element size 1 << ez bytes (lane count 32 >> ez)
module gather_insert(input [255:0] old, input [63:0] data, input [4:0] lane, input [1:0] ez, input we, output reg [255:0] y);
  integer k, esz, base;
  always @* begin
    y = old; esz = 1 << ez; base = lane << ez;
    if (we) for (k = 0; k < 32; k = k + 1) if (k >= base && k < base + esz) y[8*k +: 8] = data[8*(k - base) +: 8];
  end
endmodule
// the one-lane-a-cycle gather as a whole: the address generator of gather1 (its counter, the 16-lane select) and the merge, the lane counter 5 bits (32 byte lanes); the load alignment (ldalign, 590) is the scalar load path's and not repeated
module gather_full(input clk, input [63:0] base, input [255:0] idx, input [1:0] sc, input [1:0] ez, input start, input [255:0] old, input [63:0] data,
                   output reg [63:0] addr, output reg [4:0] lane, output [255:0] y);
  wire [15:0] ix = (ez == 0) ? {8'b0, idx[8*lane +: 8]} : idx[16*lane[3:0] +: 16];
  always @(posedge clk) begin
    if (start) lane <= 0; else lane <= lane + 1;
    addr <= base + ({48'b0, ix} << sc);
  end
  gather_insert ins(old, data, lane, ez, 1'b1, y);
endmodule

// conversions (second wave), 32-bit lanes, 8 of each -----------------------------------------------------------------------------------------------------------------------
// vcvt.f.l: signed 32-bit integer to single, round to nearest even
module cvt_i2f(input [31:0] a, output reg [31:0] y);
  reg s; reg [31:0] m, n; reg [5:0] lz; reg [24:0] man; reg g, st, inc, cy; integer i; reg [7:0] e;
  always @* begin
    s = a[31]; m = s ? -a : a;
    lz = 0; for (i = 31; i >= 0; i = i - 1) if (m[i] && lz == 0 && (i == 31 || ((m >> (i + 1)) == 0))) lz = 31 - i;
    n = m << lz;									// the leading one at bit 31
    man = {1'b0, n[31:8]}; g = n[7]; st = (n[6:0] != 0);
    inc = g & (st | man[0]); man = man + inc; cy = man[24];
    e = 8'd127 + 8'd31 - lz + cy;
    y = (m == 0) ? 32'b0 : {s, e, cy ? 23'b0 : man[22:0]};
  end
endmodule
// vcvt.l.f: single to signed 32-bit integer, round to nearest even, saturating (NaN to 0 is not handled)
module cvt_f2i(input [31:0] a, output reg [31:0] y);
  reg s; reg [7:0] e; reg [23:0] m; reg [55:0] x; reg [31:0] mag; reg g, st; reg [4:0] sc;
  always @* begin
    s = a[31]; e = a[30:23]; m = {e != 0, a[22:0]};
    sc = e - 8'd127;
    x = {32'b0, m} << sc;								// value = x / 2^23
    g = x[22]; st = (x[21:0] != 0);
    mag = x[54:23] + (g & (st | x[23]));
    if (e < 8'd126) mag = 0; else if (e == 8'd126) mag = (m != 24'h800000);
    y = (e > 8'd158 || (e == 8'd158 && !(s && m == 24'h800000))) ? (s ? 32'h80000000 : 32'h7fffffff) : (s ? -mag : mag);
  end
endmodule
module cvt_both8(input [255:0] a, output [255:0] yi, output [255:0] yf);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g cvt_i2f u(a[32*i +: 32], yf[32*i +: 32]); cvt_f2i v(a[32*i +: 32], yi[32*i +: 32]); end endgenerate
endmodule
module cvt_i2f8(input [255:0] a, output [255:0] y);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g cvt_i2f u(a[32*i +: 32], y[32*i +: 32]); end endgenerate
endmodule
module cvt_f2i8(input [255:0] a, output [255:0] y);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g cvt_f2i u(a[32*i +: 32], y[32*i +: 32]); end endgenerate
endmodule
