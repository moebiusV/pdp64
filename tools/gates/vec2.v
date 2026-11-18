// Blocks of the revised vector family (docs/encoding-work/vec-silicon.md), written to be counted, not to be used: each is synthesised by yosys and mapped to
// NAND2 and inverters (gates2.sh, the same flow as gates.sh).  A strip is 256 bits: 32 byte lanes, 16 halfword lanes, 8 word lanes, 4 doubleword lanes.
// Lane letters as in vec-isa.md: b w l q are 8, 16, 32, 64 bits.  Size code sz: 0 b, 1 w, 2 l, 3 q.

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the integer lane ALU for every lane width: a byte-sliced adder with the carry cut at the lane boundary.  op: 0 add, 1 sub, 2 sadd, 3 ssub, 4 uadd, 5 usub,
// 6 min, 7 max, 8 minu, 9 maxu, 10 abs, 11 abd (signed lanes), 12 abdu, 13 and, 14 or, 15 xor, 16 avg (rounding, signed), 17 avgu (rounding, unsigned)
// AVG = 0 leaves out the two averages (the rest of the ALU); SZC >= 0 fixes the lane width (a constant size input)
module lanealu_core #(parameter AVG = 1, parameter SZC = -1) (input [255:0] a, input [255:0] b, input [1:0] szi, input [4:0] op, output reg [255:0] y);
  wire [1:0] sz = (SZC < 0) ? szi : SZC;
  integer i, t, lb, k;
  reg [31:0] bnd, tp;
  reg [255:0] xa, bb, s1, s2, ox, oy;
  reg [31:0] cy1, cy2;
  reg cin, avgop, sub1, ma, mb, ms, ovf, lt, c, sg;
  reg [8:0] w;
  reg [7:0] bt, sat;
  always @* begin
    lb = 1 << sz;
    for (i = 0; i < 32; i = i + 1) begin bnd[i] = ((i & (lb - 1)) == 0); tp[i] = (i == 31) ? 1'b1 : bnd[(i + 1) % 32]; end
    avgop = (AVG != 0) && (op == 16 || op == 17);
    sub1 = (op == 1 || op == 3 || op == 5 || op == 6 || op == 7 || op == 8 || op == 9 || op == 11 || op == 12);
    for (i = 0; i < 32; i = i + 1) begin
      xa[8*i +: 8] = a[8*i +: 8];
      bb[8*i +: 8] = sub1 ? ~b[8*i +: 8] : b[8*i +: 8];
      if (avgop && op == 16 && tp[i]) begin xa[8*i + 7] = ~a[8*i + 7]; bb[8*i + 7] = ~b[8*i + 7]; end
    end
    cin = sub1 | avgop;
    for (i = 0; i < 32; i = i + 1) begin
      c = bnd[i] ? cin : cy1[(i + 31) % 32];
      w = {1'b0, xa[8*i +: 8]} + {1'b0, bb[8*i +: 8]} + {8'b0, c};
      s1[8*i +: 8] = w[7:0]; cy1[i] = w[8];
    end
    // the second adder: the absolute difference and the absolute value
    for (i = 0; i < 32; i = i + 1) begin
      t = i | (lb - 1);
      ma = a[8*t + 7]; mb = bb[8*t + 7]; ms = s1[8*t + 7];
      ovf = (ma == mb) && (ms != ma);
      lt = (op == 8 || op == 9 || op == 12) ? ~cy1[t] : (ms ^ ovf);
      if (op == 10) begin ox[8*i +: 8] = ma ? 8'h00 : a[8*i +: 8]; oy[8*i +: 8] = ma ? a[8*i +: 8] : 8'h00; end
      else begin ox[8*i +: 8] = lt ? b[8*i +: 8] : a[8*i +: 8]; oy[8*i +: 8] = lt ? a[8*i +: 8] : b[8*i +: 8]; end
    end
    for (i = 0; i < 32; i = i + 1) begin
      c = bnd[i] ? 1'b1 : cy2[(i + 31) % 32];
      w = {1'b0, ox[8*i +: 8]} + {1'b0, ~oy[8*i +: 8]} + {8'b0, c};
      s2[8*i +: 8] = w[7:0]; cy2[i] = w[8];
    end
    for (i = 0; i < 32; i = i + 1) begin
      t = i | (lb - 1);
      ma = a[8*t + 7]; mb = bb[8*t + 7]; ms = s1[8*t + 7];
      ovf = (ma == mb) && (ms != ma);
      sg = (op == 6 || op == 7) ? (ms ^ ovf) : ~cy1[t];			// a < b for the subtract forms
      sat = {tp[i] ? ma : ~ma, {7{~ma}}};
      // the average: bit j of the lane is bit j+1 of the sum, the top bit is the carry (flipped back for signed)
      bt[6:0] = s1[8*i + 1 +: 7];
      bt[7] = tp[i] ? (cy1[i] ^ (op == 16)) : s1[8*((i + 1) % 32)];
      case (op)
        0, 1: y[8*i +: 8] = s1[8*i +: 8];
        2, 3: y[8*i +: 8] = ovf ? sat : s1[8*i +: 8];
        4: y[8*i +: 8] = cy1[t] ? 8'hff : s1[8*i +: 8];
        5: y[8*i +: 8] = cy1[t] ? s1[8*i +: 8] : 8'h00;
        6: y[8*i +: 8] = sg ? a[8*i +: 8] : b[8*i +: 8];
        7: y[8*i +: 8] = sg ? b[8*i +: 8] : a[8*i +: 8];
        8: y[8*i +: 8] = sg ? a[8*i +: 8] : b[8*i +: 8];
        9: y[8*i +: 8] = sg ? b[8*i +: 8] : a[8*i +: 8];
        10, 11, 12: y[8*i +: 8] = s2[8*i +: 8];
        13: y[8*i +: 8] = a[8*i +: 8] & b[8*i +: 8];
        14: y[8*i +: 8] = a[8*i +: 8] | b[8*i +: 8];
        15: y[8*i +: 8] = a[8*i +: 8] ^ b[8*i +: 8];
        default: y[8*i +: 8] = (AVG != 0) ? bt : 8'h00;
      endcase
    end
  end
endmodule
module lanealu_mw(input [255:0] a, input [255:0] b, input [1:0] sz, input [4:0] op, output [255:0] y);
  lanealu_core #(1, -1) u(a, b, sz, op, y); endmodule
module lanealu_mw_noavg(input [255:0] a, input [255:0] b, input [1:0] sz, input [4:0] op, output [255:0] y);
  lanealu_core #(0, -1) u(a, b, sz, op, y); endmodule
module lanealu_w(input [255:0] a, input [255:0] b, input [4:0] op, output [255:0] y);			// halfword lanes only: the like-for-like of lanealu16 with the new operations
  lanealu_core #(1, 1) u(a, b, 2'd1, op, y); endmodule
module lanealu_w_noavg(input [255:0] a, input [255:0] b, input [4:0] op, output [255:0] y);
  lanealu_core #(0, 1) u(a, b, 2'd1, op, y); endmodule

// the rounding average on its own (vavg, vavgu), every lane width
module vavg_mw(input [255:0] a, input [255:0] b, input [1:0] sz, input sgn, output reg [255:0] y);
  integer i, lb; reg [31:0] bnd, tp, cy; reg [255:0] xa, xb, s; reg c; reg [8:0] w;
  always @* begin
    lb = 1 << sz;
    for (i = 0; i < 32; i = i + 1) begin bnd[i] = ((i & (lb - 1)) == 0); tp[i] = (i == 31) ? 1'b1 : bnd[(i + 1) % 32]; end
    for (i = 0; i < 32; i = i + 1) begin
      xa[8*i +: 8] = a[8*i +: 8]; xb[8*i +: 8] = b[8*i +: 8];
      if (sgn && tp[i]) begin xa[8*i + 7] = ~a[8*i + 7]; xb[8*i + 7] = ~b[8*i + 7]; end
    end
    for (i = 0; i < 32; i = i + 1) begin
      c = bnd[i] ? 1'b1 : cy[(i + 31) % 32];
      w = {1'b0, xa[8*i +: 8]} + {1'b0, xb[8*i +: 8]} + {8'b0, c};
      s[8*i +: 8] = w[7:0]; cy[i] = w[8];
    end
    for (i = 0; i < 32; i = i + 1) begin
      y[8*i +: 7] = s[8*i + 1 +: 7];
      y[8*i + 7] = tp[i] ? (cy[i] ^ sgn) : s[8*((i + 1) % 32)];
    end
  end
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// shifts by one count for every lane of the strip (the count is a scalar or an immediate, as in vec-isa.md), a segmented barrel shifter: op 0 left, 1 logical right, 2 arithmetic right.
// RND = 1 adds the rounding of vsarr and vshrr: the last bit shifted out is added to the result.  SZC >= 0 fixes the lane width.  The shift is by n mod the lane width.
module shiftlane_core #(parameter RND = 0, parameter SZC = -1) (input [255:0] a, input [5:0] n, input [1:0] szi, input [1:0] op, output [255:0] y);
  wire [1:0] sz = (SZC < 0) ? szi : SZC;
  wire [1791:0] stg;
  assign stg[255:0] = a;
  genvar s, j, q;
  generate
    for (s = 0; s < 6; s = s + 1) begin: S
      for (j = 0; j < 256; j = j + 1) begin: B
        localparam integer jr = (j + (1 << s)) % 256, jl = (j - (1 << s) + 256) % 256;
        localparam integer R0 = (j + (1 << s) < 256 && ((j + (1 << s)) >> 3) == (j >> 3)) ? 1 : 0;
        localparam integer R1 = (j + (1 << s) < 256 && ((j + (1 << s)) >> 4) == (j >> 4)) ? 1 : 0;
        localparam integer R2 = (j + (1 << s) < 256 && ((j + (1 << s)) >> 5) == (j >> 5)) ? 1 : 0;
        localparam integer R3 = (j + (1 << s) < 256 && ((j + (1 << s)) >> 6) == (j >> 6)) ? 1 : 0;
        localparam integer L0 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 3) == (j >> 3)) ? 1 : 0;
        localparam integer L1 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 4) == (j >> 4)) ? 1 : 0;
        localparam integer L2 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 5) == (j >> 5)) ? 1 : 0;
        localparam integer L3 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 6) == (j >> 6)) ? 1 : 0;
        wire vr = (sz == 0) ? R0 : (sz == 1) ? R1 : (sz == 2) ? R2 : R3;
        wire vl = (sz == 0) ? L0 : (sz == 1) ? L1 : (sz == 2) ? L2 : L3;
        wire en = n[s] & ((s < 3) | (s == 3 & sz != 0) | (s == 4 & sz[1]) | (s == 5 & sz == 3));
        wire sb = (sz == 0) ? a[j | 7] : (sz == 1) ? a[j | 15] : (sz == 2) ? a[j | 31] : a[j | 63];
        wire fill = (op == 2) & sb;
        wire cur = stg[256*s + j], right = stg[256*s + jr], left = stg[256*s + jl];
        assign stg[256*(s+1) + j] = en ? ((op == 0) ? (vl & left) : (vr ? right : fill)) : cur;
      end
    end
  endgenerate
  wire [255:0] y0 = stg[1536 +: 256];
  generate if (RND == 0) begin: P assign y = y0; end
  else begin: R
    // the round bit of each lane: bit n-1 of the lane before the shift, for the right shifts; then added to the lane
    wire [255:0] q0, q1, q2, q3;
    wire [31:0] rb0; wire [15:0] rb1; wire [7:0] rb2; wire [3:0] rb3;
    for (j = 0; j < 256; j = j + 1) begin: Q
      assign q0[j] = a[j] & (n[2:0] == (j & 7) + 1);
      assign q1[j] = a[j] & (n[3:0] == (j & 15) + 1);
      assign q2[j] = a[j] & (n[4:0] == (j & 31) + 1);
      assign q3[j] = a[j] & (n[5:0] == (j & 63) + 1);
    end
    for (j = 0; j < 32; j = j + 1) begin: R0 assign rb0[j] = |q0[8*j +: 8]; end
    for (j = 0; j < 16; j = j + 1) begin: R1 assign rb1[j] = |q1[16*j +: 16]; end
    for (j = 0; j < 8; j = j + 1) begin: R2 assign rb2[j] = |q2[32*j +: 32]; end
    for (j = 0; j < 4; j = j + 1) begin: R3 assign rb3[j] = |q3[64*j +: 64]; end
    wire [256:0] cc;
    assign cc[0] = 1'b0;
    for (j = 0; j < 256; j = j + 1) begin: C
      wire st = (sz == 0) ? ((j & 7) == 0) : (sz == 1) ? ((j & 15) == 0) : (sz == 2) ? ((j & 31) == 0) : ((j & 63) == 0);
      wire rbl = (sz == 0) ? rb0[j >> 3] : (sz == 1) ? rb1[j >> 4] : (sz == 2) ? rb2[j >> 5] : rb3[j >> 6];
      wire cin = st ? (rbl & (op != 0)) : cc[j];
      assign y[j] = y0[j] ^ cin;
      assign cc[j+1] = cin & y0[j];
    end
  end endgenerate
endmodule
module shiftlane_mw(input [255:0] a, input [5:0] n, input [1:0] sz, input [1:0] op, output [255:0] y); shiftlane_core #(0, -1) u(a, n, sz, op, y); endmodule
module shiftround_mw(input [255:0] a, input [5:0] n, input [1:0] sz, input [1:0] op, output [255:0] y); shiftlane_core #(1, -1) u(a, n, sz, op, y); endmodule
module shiftlane_wl(input [255:0] a, input [5:0] n, input szl, input [1:0] op, output [255:0] y);			// only the w and l lanes (what the proposal rounds)
  wire [255:0] yw, yl; shiftlane_core #(0, 1) uw(a, n, 2'd1, op, yw); shiftlane_core #(0, 2) ul(a, n, 2'd2, op, yl); assign y = szl ? yl : yw; endmodule
module shiftround_wl(input [255:0] a, input [5:0] n, input szl, input [1:0] op, output [255:0] y);
  wire [255:0] yw, yl; shiftlane_core #(1, 1) uw(a, n, 2'd1, op, yw); shiftlane_core #(1, 2) ul(a, n, 2'd2, op, yl); assign y = szl ? yl : yw; endmodule
module shiftlane_w(input [255:0] a, input [5:0] n, input [1:0] op, output [255:0] y); shiftlane_core #(0, 1) u(a, n, 2'd1, op, y); endmodule
module shiftround_w(input [255:0] a, input [5:0] n, input [1:0] op, output [255:0] y); shiftlane_core #(1, 1) u(a, n, 2'd1, op, y); endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the narrowing store: lanes of 16 bits to bytes (16 lanes), or lanes of 32 bits to halfwords (8 lanes), with an immediate shift (0 to 15), the rounding, and the clamp.
// sat: 0 truncate (wrap), 1 signed clamp, 2 unsigned clamp of a signed value, 3 unsigned clamp of an unsigned value.  RSH = 0 is the store without the shift and the rounding.
module narrow_core #(parameter RSH = 1, parameter W16 = 1, parameter W32 = 1) (input [255:0] a, input [3:0] sh, input [1:0] sat, input l, output reg [127:0] y);
  integer i;
  reg signed [32:0] x, v;
  reg [15:0] lo;
  reg [7:0] o8;
  reg [15:0] o16;
  reg signed [32:0] lim;
  function [15:0] clamp(input signed [32:0] z, input [1:0] st, input integer bits);
    reg signed [32:0] mx, mn;
    begin
      case (st)
        1: begin mx = (33'sd1 <<< (bits - 1)) - 1; mn = -(33'sd1 <<< (bits - 1)); end
        2: begin mx = (33'sd1 <<< bits) - 1; mn = 0; end
        default: begin mx = (33'sd1 <<< bits) - 1; mn = 0; end
      endcase
      if (st == 0) clamp = z[15:0];
      else if (z > mx) clamp = mx[15:0];
      else if (z < mn) clamp = mn[15:0];
      else clamp = z[15:0];
    end
  endfunction
  always @* begin
    y = 0;
    if (W16 != 0 && (W32 == 0 || !l))
      for (i = 0; i < 16; i = i + 1) begin
        x = (sat == 3) ? {17'b0, a[16*i +: 16]} : {{17{a[16*i + 15]}}, a[16*i +: 16]};
        if (RSH != 0) begin v = x >>> sh; if (sh != 0 && x[sh - 1]) v = v + 1; end else v = x;
        y[8*i +: 8] = clamp(v, sat, 8);
      end
    else if (W32 != 0)
      for (i = 0; i < 8; i = i + 1) begin
        x = (sat == 3) ? {1'b0, a[32*i +: 32]} : {a[32*i + 31], a[32*i +: 32]};
        if (RSH != 0) begin v = x >>> sh; if (sh != 0 && x[sh - 1]) v = v + 1; end else v = x;
        y[16*i +: 16] = clamp(v, sat, 16);
      end
  end
endmodule
module narrow_w2b(input [255:0] a, input [3:0] sh, input [1:0] sat, output [127:0] y); narrow_core #(1, 1, 0) u(a, sh, sat, 1'b0, y); endmodule
module narrow_l2w(input [255:0] a, input [3:0] sh, input [1:0] sat, output [127:0] y); narrow_core #(1, 0, 1) u(a, sh, sat, 1'b1, y); endmodule
module narrow_both(input [255:0] a, input [3:0] sh, input [1:0] sat, input l, output [127:0] y); narrow_core #(1, 1, 1) u(a, sh, sat, l, y); endmodule
module narrow_w2b_plain(input [255:0] a, input [1:0] sat, output [127:0] y); narrow_core #(0, 1, 0) u(a, 4'd0, sat, 1'b0, y); endmodule
module narrow_l2w_plain(input [255:0] a, input [1:0] sat, output [127:0] y); narrow_core #(0, 0, 1) u(a, 4'd0, sat, 1'b1, y); endmodule
module narrow_both_plain(input [255:0] a, input [1:0] sat, input l, output [127:0] y); narrow_core #(0, 1, 1) u(a, 4'd0, sat, l, y); endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the multiplier arrays.  vmul16_lo: 16 lanes of 16 x 16, the low half (vmul); vmulh16_sep: a separate array for the high half, the unsigned high half and the Q15 rounding multiply (the shared forms are in vec3.v)
module vmul16_lo(input [255:0] a, input [255:0] b, output [255:0] y);
  genvar i; generate for (i = 0; i < 16; i = i + 1) begin: g
    assign y[16*i +: 16] = a[16*i +: 16] * b[16*i +: 16];
  end endgenerate
endmodule
// m: 0 high half signed (vmulh), 1 high half unsigned (vmulhu), 2 Q15 rounding, saturating (vmulhr)
module vmulh16_sep(input [255:0] a, input [255:0] b, input [1:0] m, output reg [255:0] y);
  integer i; reg signed [33:0] p; reg signed [33:0] r; reg signed [16:0] xa, xb;
  always @* for (i = 0; i < 16; i = i + 1) begin
    xa = (m == 1) ? {1'b0, a[16*i +: 16]} : {a[16*i + 15], a[16*i +: 16]};
    xb = (m == 1) ? {1'b0, b[16*i +: 16]} : {b[16*i + 15], b[16*i +: 16]};
    p = xa * xb;
    if (m == 2) begin r = (p + 34'sd16384) >>> 15; y[16*i +: 16] = (r > 32767) ? 16'h7fff : r[15:0]; end
    else y[16*i +: 16] = p[31:16];
  end
endmodule
// vmla alone: the separate form (a multiplier and an adder per lane)
module vmla16_sep(input [255:0] a, input [255:0] b, input [255:0] c, output [255:0] y);
  genvar i; generate for (i = 0; i < 16; i = i + 1) begin: g
    assign y[16*i +: 16] = a[16*i +: 16] * b[16*i +: 16] + c[16*i +: 16];
  end endgenerate
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// vdot.w alone: 8 lanes of two 16 x 16 products and a 32-bit accumulator (signed); separate multipliers
module vdotw_sep(input [255:0] a, input [255:0] b, input [255:0] acc, output [255:0] y);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g
    wire signed [31:0] p0 = $signed(a[32*i +: 16]) * $signed(b[32*i +: 16]);
    wire signed [31:0] p1 = $signed(a[32*i + 16 +: 16]) * $signed(b[32*i + 16 +: 16]);
    assign y[32*i +: 32] = acc[32*i +: 32] + p0 + p1;
  end endgenerate
endmodule
// vdot.b, .bu, .bsu as the family has it (the 37,000 of vec-gates.md, there for signed bytes only): 8 lanes of four 8 x 8 products and a 32-bit accumulator; sa, sb: the operands are signed
module vdotb_sep(input [255:0] a, input [255:0] b, input [255:0] acc, input sa, input sb, output [255:0] y);
  genvar i, k; generate for (i = 0; i < 8; i = i + 1) begin: g
    wire signed [31:0] p [0:3];
    for (k = 0; k < 4; k = k + 1) begin: h
      wire signed [8:0] xa = {sa & a[32*i + 8*k + 7], a[32*i + 8*k +: 8]};
      wire signed [8:0] xb = {sb & b[32*i + 8*k + 7], b[32*i + 8*k +: 8]};
      wire signed [17:0] pp = xa * xb;
      assign p[k] = pp;
    end
    assign y[32*i +: 32] = acc[32*i +: 32] + p[0] + p[1] + p[2] + p[3];
  end endgenerate
endmodule
// the dot product of signed bytes only, as dot4 of blocks.v, in the full strip: for the comparison with the first number of vec-gates.md
module vdotb_s(input [255:0] a, input [255:0] b, input [255:0] acc, output [255:0] y);
  genvar i; generate for (i = 0; i < 8; i = i + 1) begin: g
    dot4 d(a[32*i +: 32], b[32*i +: 32], acc[32*i +: 32], y[32*i +: 32]);
  end endgenerate
endmodule
module dot4(input [31:0] a, input [31:0] b, input signed [31:0] acc, output signed [31:0] y);
  wire signed [15:0] p0 = $signed(a[7:0]) * $signed(b[7:0]);
  wire signed [15:0] p1 = $signed(a[15:8]) * $signed(b[15:8]);
  wire signed [15:0] p2 = $signed(a[23:16]) * $signed(b[23:16]);
  wire signed [15:0] p3 = $signed(a[31:24]) * $signed(b[31:24]);
  assign y = acc + p0 + p1 + p2 + p3;
endmodule

// vdacc: the reduction tree on the 8 lanes of 32 bits of a vdot, into a 64-bit scalar accumulate (signed 32-bit lanes)
module dacc_tree(input [255:0] lanes, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s;
  always @* begin s = acc; for (i = 0; i < 8; i = i + 1) s = s + $signed(lanes[32*i +: 32]); end
  assign y = s;
endmodule
// vdacc.b whole, as a separate unit: 32 byte products summed into a 64-bit scalar accumulate (the products are not lane-wise accumulated)
module vdaccb_sep(input [255:0] a, input [255:0] b, input sa, input sb, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s; reg signed [8:0] xa, xb; reg signed [17:0] pp;
  always @* begin
    s = acc;
    for (i = 0; i < 32; i = i + 1) begin
      xa = {sa & a[8*i + 7], a[8*i +: 8]}; xb = {sb & b[8*i + 7], b[8*i +: 8]};
      pp = xa * xb; s = s + pp;
    end
  end
  assign y = s;
endmodule
module vdaccw_sep(input [255:0] a, input [255:0] b, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s; reg signed [31:0] pp;
  always @* begin
    s = acc;
    for (i = 0; i < 16; i = i + 1) begin pp = $signed(a[16*i +: 16]) * $signed(b[16*i +: 16]); s = s + pp; end
  end
  assign y = s;
endmodule

// vsad.bu: 32 absolute differences of unsigned bytes summed into a 64-bit scalar accumulate
module vsad_bu(input [255:0] a, input [255:0] b, input [63:0] acc, output [63:0] y);
  integer i; reg [63:0] s; reg [7:0] d;
  always @* begin
    s = acc;
    for (i = 0; i < 32; i = i + 1) begin d = (a[8*i +: 8] > b[8*i +: 8]) ? a[8*i +: 8] - b[8*i +: 8] : b[8*i +: 8] - a[8*i +: 8]; s = s + d; end
  end
  assign y = s;
endmodule
// the sum of the 32 bytes (unsigned) into the accumulate: the tree that vsad adds to the absolute differences, which is also vacc.bu
module sum32_bu(input [255:0] a, input [63:0] acc, output [63:0] y);
  integer i; reg [63:0] s;
  always @* begin s = acc; for (i = 0; i < 32; i = i + 1) s = s + a[8*i +: 8]; end
  assign y = s;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the reductions into a scalar.  vacc for every source type: each byte of the strip belongs to one of eight classes by its position in its lane (the weight 2^(8 c)); the top byte of a
// signed lane has a negative weight.  sz 0 b, 1 w, 2 l, 3 q; sgn signed.  AW: the accumulate width (64, or 32 as `l`).
module vacc_shared #(parameter AW = 64) (input [255:0] a, input [1:0] sz, input sgn, input [AW-1:0] acc, output [AW-1:0] y);
  integer i, c, lb, pos;
  reg signed [24:0] cs [0:7];
  reg signed [63:0] s;
  reg signed [24:0] v;
  always @* begin
    lb = 1 << sz;
    for (c = 0; c < 8; c = c + 1) cs[c] = 0;
    for (i = 0; i < 32; i = i + 1) begin
      pos = i & (lb - 1);
      v = (sgn && pos == lb - 1) ? {{17{a[8*i + 7]}}, a[8*i +: 8]} : {17'b0, a[8*i +: 8]};
      for (c = 0; c < 8; c = c + 1) if (pos == c) cs[c] = cs[c] + v;
    end
    s = {{(64-AW){1'b0}}, acc};
    for (c = 0; c < 8; c = c + 1) s = s + (cs[c] <<< (8 * c));
  end
  assign y = s[AW-1:0];
endmodule
module vacc_shared32(input [255:0] a, input [1:0] sz, input sgn, input [31:0] acc, output [31:0] y); vacc_shared #(32) u(a, sz, sgn, acc, y); endmodule
module vacc_shared64(input [255:0] a, input [1:0] sz, input sgn, input [63:0] acc, output [63:0] y); vacc_shared #(64) u(a, sz, sgn, acc, y); endmodule
// the same as one tree for each source type and a selector (the upper bound of the shared one)
module vacc_naive(input [255:0] a, input [1:0] sz, input sgn, input [63:0] acc, output reg [63:0] y);
  integer i; reg signed [63:0] sb, sw, sl, sq;
  always @* begin
    sb = 0; sw = 0; sl = 0; sq = 0;
    for (i = 0; i < 32; i = i + 1) sb = sb + (sgn ? {{56{a[8*i + 7]}}, a[8*i +: 8]} : {56'b0, a[8*i +: 8]});
    for (i = 0; i < 16; i = i + 1) sw = sw + (sgn ? {{48{a[16*i + 15]}}, a[16*i +: 16]} : {48'b0, a[16*i +: 16]});
    for (i = 0; i < 8; i = i + 1) sl = sl + (sgn ? {{32{a[32*i + 31]}}, a[32*i +: 32]} : {32'b0, a[32*i +: 32]});
    for (i = 0; i < 4; i = i + 1) sq = sq + a[64*i +: 64];
    y = acc + (sz == 0 ? sb : sz == 1 ? sw : sz == 2 ? sl : sq);
  end
endmodule
// one source type each, signed or unsigned by sgn (the pieces of the naive form)
module vacc_b(input [255:0] a, input sgn, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s;
  always @* begin s = acc; for (i = 0; i < 32; i = i + 1) s = s + (sgn ? {{56{a[8*i + 7]}}, a[8*i +: 8]} : {56'b0, a[8*i +: 8]}); end
  assign y = s;
endmodule
module vacc_w(input [255:0] a, input sgn, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s;
  always @* begin s = acc; for (i = 0; i < 16; i = i + 1) s = s + (sgn ? {{48{a[16*i + 15]}}, a[16*i +: 16]} : {48'b0, a[16*i +: 16]}); end
  assign y = s;
endmodule
module vacc_l(input [255:0] a, input sgn, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s;
  always @* begin s = acc; for (i = 0; i < 8; i = i + 1) s = s + (sgn ? {{32{a[32*i + 31]}}, a[32*i +: 32]} : {32'b0, a[32*i +: 32]}); end
  assign y = s;
endmodule
module vacc_q(input [255:0] a, input [63:0] acc, output [63:0] y);
  assign y = acc + a[63:0] + a[127:64] + a[191:128] + a[255:192];
endmodule
// vmaxacc / vminacc: the largest or smallest lane of every source type, against the scalar register (sgn: signed; mx: maximum)
module vmmacc(input [255:0] a, input [1:0] sz, input sgn, input mx, input [63:0] acc, output reg [63:0] y);
  integer i; reg [63:0] best, v; reg [63:0] fl; reg lt;
  always @* begin
    best = 0;
    case (sz)
      0: begin best = sgn ? {{56{a[7]}}, a[7:0]} : {56'b0, a[7:0]};
           for (i = 1; i < 32; i = i + 1) begin v = sgn ? {{56{a[8*i + 7]}}, a[8*i +: 8]} : {56'b0, a[8*i +: 8]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      1: begin best = sgn ? {{48{a[15]}}, a[15:0]} : {48'b0, a[15:0]};
           for (i = 1; i < 16; i = i + 1) begin v = sgn ? {{48{a[16*i + 15]}}, a[16*i +: 16]} : {48'b0, a[16*i +: 16]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      2: begin best = sgn ? {{32{a[31]}}, a[31:0]} : {32'b0, a[31:0]};
           for (i = 1; i < 8; i = i + 1) begin v = sgn ? {{32{a[32*i + 31]}}, a[32*i +: 32]} : {32'b0, a[32*i +: 32]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      default: begin best = a[63:0];
           for (i = 1; i < 4; i = i + 1) begin v = a[64*i +: 64];
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
    endcase
    lt = sgn ? ($signed(best) < $signed(acc)) : (best < acc);
    y = (mx ? !lt : lt) ? best : acc;
  end
endmodule
// the least: the reductions the survey names with 16 lanes of 16 bits only (vacc.w, vmaxacc.w) as vec-gates.md counted (reduce16 is vacc.w signed)

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// vtbl.b: for each of the 32 byte lanes, a 16-entry lookup.  The table is 16 bytes of vT per group of 16 lanes (the survey's definition): out = tbl[16*(i/16) + (idx & 15)], 0 if idx bit 7
module vtbl_g16(input [255:0] t, input [255:0] idx, output reg [255:0] y);
  integer i; reg [7:0] ix;
  always @* for (i = 0; i < 32; i = i + 1) begin
    ix = idx[8*i +: 8];
    y[8*i +: 8] = ix[7] ? 8'h00 : t[8*(16*(i/16) + ix[3:0]) +: 8];
  end
endmodule
// the same with one table of 16 bytes for all 32 lanes
module vtbl_one(input [127:0] t, input [255:0] idx, output reg [255:0] y);
  integer i; reg [7:0] ix;
  always @* for (i = 0; i < 32; i = i + 1) begin
    ix = idx[8*i +: 8];
    y[8*i +: 8] = ix[7] ? 8'h00 : t[8*ix[3:0] +: 8];
  end
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// compare and select (second wave): vceq, vcgt, vcgtu give an all-ones or all-zeros lane; vbsl is the bit select D = (D & A) | (~D & B).  op 0 eq, 1 gt, 2 gtu
module vcmp_mw(input [255:0] a, input [255:0] b, input [1:0] sz, input [1:0] op, output reg [255:0] y);
  integer i, j, lb; reg lane; reg [255:0] sa, sb;
  always @* begin
    lb = 1 << sz;
    y = 0;
    for (j = 0; j < 32; j = j + 1) if (j % lb == 0) begin
      sa = a >> (8 * j); sb = b >> (8 * j);
      case (sz)
        0: lane = (op == 0) ? (sa[7:0] == sb[7:0]) : (op == 1) ? ($signed(sa[7:0]) > $signed(sb[7:0])) : (sa[7:0] > sb[7:0]);
        1: lane = (op == 0) ? (sa[15:0] == sb[15:0]) : (op == 1) ? ($signed(sa[15:0]) > $signed(sb[15:0])) : (sa[15:0] > sb[15:0]);
        2: lane = (op == 0) ? (sa[31:0] == sb[31:0]) : (op == 1) ? ($signed(sa[31:0]) > $signed(sb[31:0])) : (sa[31:0] > sb[31:0]);
        default: lane = (op == 0) ? (sa[63:0] == sb[63:0]) : (op == 1) ? ($signed(sa[63:0]) > $signed(sb[63:0])) : (sa[63:0] > sb[63:0]);
      endcase
      for (i = 0; i < 64; i = i + 1) if (i < 8 * lb) y[(8*j + i) % 256] = lane;
    end
  end
endmodule
module vbsl(input [255:0] d, input [255:0] a, input [255:0] b, output [255:0] y); assign y = (d & a) | (~d & b); endmodule

// segment loads and stores, the de-interleave and the interleave network of the memory path.  One 32-byte beat of memory; nf = nfm1 + 1 fields (2, 3, 4); esz = 1 << ez bytes per
// field element (1, 2, 4); beat: which quarter of the field registers is written (the field registers have byte write enables, which are not counted).
// segload: field f of the destination (4 registers of 32 bytes): byte i of field f at beat bt takes the element ((i/esz) - bt*per)*nf + f of the beat, per = 32/(nf*esz) elements a beat.
function integer sld(input integer nf, input integer esz, input integer bt, input integer f, input integer i);
  integer per, e, src;
  begin per = 32 / (nf * esz); e = (i / esz) - bt * per; src = (e * nf + f) * esz + (i % esz);
    sld = (f < nf && e >= 0 && e < per && src < 32) ? src : -1; end
endfunction
function integer sst(input integer nf, input integer esz, input integer bt, input integer k);
  integer per, e, fld, src;
  begin per = 32 / (nf * esz); fld = (k / esz) % nf; e = bt * per + (k / esz) / nf; src = e * esz + (k % esz);
    sst = (src < 32) ? fld * 256 + 8 * src : -1; end
endfunction
module segload(input [255:0] m, input [1:0] nfm1, input [1:0] ez, input [1:0] bt, output reg [1023:0] y);
  integer f, i, x, z, b, src;
  always @* begin
    y = 0;
    for (f = 0; f < 4; f = f + 1) for (i = 0; i < 32; i = i + 1)
      for (x = 1; x < 4; x = x + 1) for (z = 0; z < 3; z = z + 1) for (b = 0; b < 4; b = b + 1) begin
        src = sld(x + 1, 1 << z, b, f, i);
        if (src >= 0 && nfm1 == x && ez == z && bt == b) y[256*f + 8*i +: 8] = m[8*src +: 8];
      end
  end
endmodule
module segstore(input [1023:0] f, input [1:0] nfm1, input [1:0] ez, input [1:0] bt, output reg [255:0] y);
  integer k, x, z, b, src;
  always @* begin
    y = 0;
    for (k = 0; k < 32; k = k + 1)
      for (x = 1; x < 4; x = x + 1) for (z = 0; z < 3; z = z + 1) for (b = 0; b < 4; b = b + 1) begin
        src = sst(x + 1, 1 << z, b, k);
        if (src >= 0 && nfm1 == x && ez == z && bt == b) y[8*k +: 8] = f[src +: 8];
      end
  end
endmodule

module vregs16_r3(input clk, input [3:0] ra, input [3:0] rb, input [3:0] rc, input [3:0] wa, input we, input [255:0] wd,
                  output [255:0] qa, output [255:0] qb, output [255:0] qc);
  reg [255:0] r [0:15];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule
module vregs16_r2(input clk, input [3:0] ra, input [3:0] rb, input [3:0] wa, input we, input [255:0] wd, output [255:0] qa, output [255:0] qb);
  reg [255:0] r [0:15];
  assign qa = r[ra]; assign qb = r[rb];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule
module vregs16_r4(input clk, input [3:0] ra, input [3:0] rb, input [3:0] rc, input [3:0] rd, input [3:0] wa, input we, input [255:0] wd,
                  output [255:0] qa, output [255:0] qb, output [255:0] qc, output [255:0] qd);
  reg [255:0] r [0:15];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc]; assign qd = r[rd];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule
module vregs16_latch(input clk, input [3:0] ra, input [3:0] rb, input [3:0] rc, input [3:0] wa, input we, input [255:0] wd,
                     output [255:0] qa, output [255:0] qb, output [255:0] qc);
  reg [255:0] r [0:15];
  reg [255:0] wq; reg [3:0] waq; reg weq;
  integer i;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) begin wq <= wd; waq <= wa; weq <= we; end
  always @* for (i = 0; i < 16; i = i + 1) if (!clk && weq && waq == i) r[i] = wq;
endmodule
// 8 registers of 256 bits, 3 read ports, flip-flops (the `vregs` of blocks.v) is the reference; the same with 16 registers of 128 bits would be half: not built.
