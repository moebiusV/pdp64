// The width-dependent blocks of the vector unit written for a strip of SNB bytes (docs/encoding-work/vec-strip.md).  `define SNB 32 (default) is the 256-bit strip of vec2.v, vec3.v,
// mem2.v and fp2.v and gives the same blocks (checked against them by run-strip.sh); 16 is a 128-bit strip, 8 a 64-bit strip.  Select the width with `read_verilog -D SNB=16`.
// SNB byte lanes, SNB/2 halfword (w) lanes, SNB/4 word (l) lanes, SNB/8 doubleword (q) lanes.  Lane letters b w l q are 8, 16, 32, 64 bits; sz code 0 b, 1 w, 2 l, 3 q.
// The modules are the modules of vec2.v, vec3.v, mem2.v and fp2.v with the literals 32, 16, 8, 256 made into functions of SNB (the logic of each lane is unchanged); the few places
// where a width cannot simply be scaled are marked WIDTH below.  Module names carry the prefix w_.  The floating-point blocks use fma32, cvt_i2f, cvt_f2i of fp2.v (read both files).
`ifndef SNB
`define SNB 32
`endif
`define SW (8*`SNB)

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the integer lane ALU, all widths (vec2.v lanealu_core).  AVG = 0 leaves out the two averages.
module w_lanealu_core #(parameter AVG = 1) (input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [4:0] op, output reg [`SW-1:0] y);
  integer i, t, lb, k;
  reg [`SNB-1:0] bnd, tp;
  reg [`SW-1:0] xa, bb, s1, s2, ox, oy;
  reg [`SNB-1:0] cy1, cy2;
  reg cin, avgop, sub1, ma, mb, ms, ovf, lt, c, sg;
  reg [8:0] w;
  reg [7:0] bt, sat;
  always @* begin
    lb = 1 << sz;
    for (i = 0; i < `SNB; i = i + 1) begin bnd[i] = ((i & (lb - 1)) == 0); tp[i] = (i == `SNB - 1) ? 1'b1 : bnd[(i + 1) % `SNB]; end
    avgop = (AVG != 0) && (op == 16 || op == 17);
    sub1 = (op == 1 || op == 3 || op == 5 || op == 6 || op == 7 || op == 8 || op == 9 || op == 11 || op == 12);
    for (i = 0; i < `SNB; i = i + 1) begin
      xa[8*i +: 8] = a[8*i +: 8];
      bb[8*i +: 8] = sub1 ? ~b[8*i +: 8] : b[8*i +: 8];
      if (avgop && op == 16 && tp[i]) begin xa[8*i + 7] = ~a[8*i + 7]; bb[8*i + 7] = ~b[8*i + 7]; end
    end
    cin = sub1 | avgop;
    for (i = 0; i < `SNB; i = i + 1) begin
      c = bnd[i] ? cin : cy1[(i + `SNB - 1) % `SNB];
      w = {1'b0, xa[8*i +: 8]} + {1'b0, bb[8*i +: 8]} + {8'b0, c};
      s1[8*i +: 8] = w[7:0]; cy1[i] = w[8];
    end
    for (i = 0; i < `SNB; i = i + 1) begin
      t = i | (lb - 1);
      ma = a[8*t + 7]; mb = bb[8*t + 7]; ms = s1[8*t + 7];
      ovf = (ma == mb) && (ms != ma);
      lt = (op == 8 || op == 9 || op == 12) ? ~cy1[t] : (ms ^ ovf);
      if (op == 10) begin ox[8*i +: 8] = ma ? 8'h00 : a[8*i +: 8]; oy[8*i +: 8] = ma ? a[8*i +: 8] : 8'h00; end
      else begin ox[8*i +: 8] = lt ? b[8*i +: 8] : a[8*i +: 8]; oy[8*i +: 8] = lt ? a[8*i +: 8] : b[8*i +: 8]; end
    end
    for (i = 0; i < `SNB; i = i + 1) begin
      c = bnd[i] ? 1'b1 : cy2[(i + `SNB - 1) % `SNB];
      w = {1'b0, ox[8*i +: 8]} + {1'b0, ~oy[8*i +: 8]} + {8'b0, c};
      s2[8*i +: 8] = w[7:0]; cy2[i] = w[8];
    end
    for (i = 0; i < `SNB; i = i + 1) begin
      t = i | (lb - 1);
      ma = a[8*t + 7]; mb = bb[8*t + 7]; ms = s1[8*t + 7];
      ovf = (ma == mb) && (ms != ma);
      sg = (op == 6 || op == 7) ? (ms ^ ovf) : ~cy1[t];
      sat = {tp[i] ? ma : ~ma, {7{~ma}}};
      bt[6:0] = s1[8*i + 1 +: 7];
      bt[7] = tp[i] ? (cy1[i] ^ (op == 16)) : s1[8*((i + 1) % `SNB)];
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
module w_lanealu_mw(input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [4:0] op, output [`SW-1:0] y); w_lanealu_core #(1) u(a, b, sz, op, y); endmodule
module w_lanealu_mw_noavg(input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [4:0] op, output [`SW-1:0] y); w_lanealu_core #(0) u(a, b, sz, op, y); endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// shifts with the rounding of vsarr, vshrr, every lane width (vec2.v shiftlane_core with RND = 1; RND = 0 is the plain shift)
module w_shift_core #(parameter RND = 1) (input [`SW-1:0] a, input [5:0] n, input [1:0] sz, input [1:0] op, output [`SW-1:0] y);
  wire [7*`SW-1:0] stg;
  assign stg[`SW-1:0] = a;
  genvar s, j, q;
  generate
    for (s = 0; s < 6; s = s + 1) begin: S
      for (j = 0; j < `SW; j = j + 1) begin: B
        localparam integer jr = (j + (1 << s)) % `SW, jl = (j - (1 << s) + `SW) % `SW;
        localparam integer R0 = (j + (1 << s) < `SW && ((j + (1 << s)) >> 3) == (j >> 3)) ? 1 : 0;
        localparam integer R1 = (j + (1 << s) < `SW && ((j + (1 << s)) >> 4) == (j >> 4)) ? 1 : 0;
        localparam integer R2 = (j + (1 << s) < `SW && ((j + (1 << s)) >> 5) == (j >> 5)) ? 1 : 0;
        localparam integer R3 = (j + (1 << s) < `SW && ((j + (1 << s)) >> 6) == (j >> 6)) ? 1 : 0;
        localparam integer L0 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 3) == (j >> 3)) ? 1 : 0;
        localparam integer L1 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 4) == (j >> 4)) ? 1 : 0;
        localparam integer L2 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 5) == (j >> 5)) ? 1 : 0;
        localparam integer L3 = (j - (1 << s) >= 0 && ((j - (1 << s)) >> 6) == (j >> 6)) ? 1 : 0;
        wire vr = (sz == 0) ? R0 : (sz == 1) ? R1 : (sz == 2) ? R2 : R3;
        wire vl = (sz == 0) ? L0 : (sz == 1) ? L1 : (sz == 2) ? L2 : L3;
        wire en = n[s] & ((s < 3) | (s == 3 & sz != 0) | (s == 4 & sz[1]) | (s == 5 & sz == 3));
        wire sb = (sz == 0) ? a[j | 7] : (sz == 1) ? a[j | 15] : (sz == 2) ? a[j | 31] : a[j | 63];
        wire fill = (op == 2) & sb;
        wire cur = stg[`SW*s + j], right = stg[`SW*s + jr], left = stg[`SW*s + jl];
        assign stg[`SW*(s+1) + j] = en ? ((op == 0) ? (vl & left) : (vr ? right : fill)) : cur;
      end
    end
  endgenerate
  wire [`SW-1:0] y0 = stg[6*`SW +: `SW];
  generate if (RND == 0) begin: P assign y = y0; end
  else begin: R
    wire [`SW-1:0] q0, q1, q2, q3;
    wire [`SNB-1:0] rb0; wire [`SNB/2-1:0] rb1; wire [`SNB/4-1:0] rb2; wire [`SNB/8-1:0] rb3;
    for (j = 0; j < `SW; j = j + 1) begin: Q
      assign q0[j] = a[j] & (n[2:0] == (j & 7) + 1);
      assign q1[j] = a[j] & (n[3:0] == (j & 15) + 1);
      assign q2[j] = a[j] & (n[4:0] == (j & 31) + 1);
      assign q3[j] = a[j] & (n[5:0] == (j & 63) + 1);
    end
    for (j = 0; j < `SNB; j = j + 1) begin: R0 assign rb0[j] = |q0[8*j +: 8]; end
    for (j = 0; j < `SNB/2; j = j + 1) begin: R1 assign rb1[j] = |q1[16*j +: 16]; end
    for (j = 0; j < `SNB/4; j = j + 1) begin: R2 assign rb2[j] = |q2[32*j +: 32]; end
    for (j = 0; j < `SNB/8; j = j + 1) begin: R3 assign rb3[j] = |q3[64*j +: 64]; end
    wire [`SW:0] cc;
    assign cc[0] = 1'b0;
    for (j = 0; j < `SW; j = j + 1) begin: C
      wire st = (sz == 0) ? ((j & 7) == 0) : (sz == 1) ? ((j & 15) == 0) : (sz == 2) ? ((j & 31) == 0) : ((j & 63) == 0);
      wire rbl = (sz == 0) ? rb0[j >> 3] : (sz == 1) ? rb1[j >> 4] : (sz == 2) ? rb2[j >> 5] : rb3[j >> 6];
      wire cin = st ? (rbl & (op != 0)) : cc[j];
      assign y[j] = y0[j] ^ cin;
      assign cc[j+1] = cin & y0[j];
    end
  end endgenerate
endmodule
module w_shiftround_mw(input [`SW-1:0] a, input [5:0] n, input [1:0] sz, input [1:0] op, output [`SW-1:0] y); w_shift_core #(1) u(a, n, sz, op, y); endmodule
module w_shiftlane_mw(input [`SW-1:0] a, input [5:0] n, input [1:0] sz, input [1:0] op, output [`SW-1:0] y); w_shift_core #(0) u(a, n, sz, op, y); endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the narrowing store with the rounding shift: w lanes to bytes (SNB/2 lanes) or l lanes to halfwords (SNB/4 lanes); the output is half the strip
module w_narrow_both(input [`SW-1:0] a, input [3:0] sh, input [1:0] sat, input l, output reg [`SW/2-1:0] y);
  integer i;
  reg signed [32:0] x, v;
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
    if (!l)
      for (i = 0; i < `SNB/2; i = i + 1) begin
        x = (sat == 3) ? {17'b0, a[16*i +: 16]} : {{17{a[16*i + 15]}}, a[16*i +: 16]};
        v = x >>> sh; if (sh != 0 && x[sh - 1]) v = v + 1;
        y[8*i +: 8] = clamp(v, sat, 8);
      end
    else
      for (i = 0; i < `SNB/4; i = i + 1) begin
        x = (sat == 3) ? {1'b0, a[32*i +: 32]} : {a[32*i + 31], a[32*i +: 32]};
        v = x >>> sh; if (sh != 0 && x[sh - 1]) v = v + 1;
        y[16*i +: 16] = clamp(v, sat, 16);
      end
  end
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the shared multiplier array of 8 x 8 products (vec3.v ms8x8): SNB/2 halfword lanes of four 9 x 9 byte products, shared by vmul, vmulh, vmulhu, vmulhr, vmla, vdot.w, vdot.b, .bu, .bsu;
// r: the SNB/4 word lanes of y summed into the scalar accumulate (vdacc).  w_ms8x8_notree leaves the tree out.
module w_ms8x8(input [`SW-1:0] a, input [`SW-1:0] b, input [`SW-1:0] c, input [3:0] m, input sa, input sb, input [63:0] sacc, output reg [`SW-1:0] y, output reg [63:0] r);
  integer i;
  reg sah, sal, sbh, sbl;
  reg signed [17:0] hh [0:`SNB/2-1]; reg signed [17:0] hl [0:`SNB/2-1]; reg signed [17:0] lh [0:`SNB/2-1]; reg signed [17:0] ll [0:`SNB/2-1];
  reg signed [33:0] full [0:`SNB/2-1]; reg signed [33:0] rr; reg signed [31:0] d;
  reg signed [63:0] s;
  always @* begin
    y = 0; r = 0;
    sah = (m == 6) ? sa : (m != 2); sal = (m == 6) ? sa : 1'b0;
    sbh = (m == 6) ? sb : (m != 2); sbl = (m == 6) ? sb : 1'b0;
    for (i = 0; i < `SNB/2; i = i + 1) begin
      hh[i] = $signed({sah & a[16*i + 15], a[16*i + 8 +: 8]}) * $signed({sbh & b[16*i + 15], b[16*i + 8 +: 8]});
      hl[i] = $signed({sah & a[16*i + 15], a[16*i + 8 +: 8]}) * $signed({sbl & b[16*i + 7], b[16*i +: 8]});
      lh[i] = $signed({sal & a[16*i + 7], a[16*i +: 8]}) * $signed({sbh & b[16*i + 15], b[16*i + 8 +: 8]});
      ll[i] = $signed({sal & a[16*i + 7], a[16*i +: 8]}) * $signed({sbl & b[16*i + 7], b[16*i +: 8]});
      full[i] = (hh[i] <<< 16) + ((hl[i] + lh[i]) <<< 8) + ll[i];
    end
    for (i = 0; i < `SNB/2; i = i + 1) begin
      rr = (full[i] + 34'sd16384) >>> 15;
      case (m)
        0: y[16*i +: 16] = full[i][15:0];
        1, 2: y[16*i +: 16] = full[i][31:16];
        3: y[16*i +: 16] = (rr > 32767) ? 16'h7fff : rr[15:0];
        4: y[16*i +: 16] = full[i][15:0] + c[16*i +: 16];
        5: if (i % 2 == 0) begin d = c[16*i +: 32] + full[i][31:0] + full[i + 1][31:0]; y[16*i +: 32] = d; end
        default: if (i % 2 == 0) begin d = $signed(c[16*i +: 32]) + hh[i] + ll[i] + hh[i + 1] + ll[i + 1]; y[16*i +: 32] = d; end
      endcase
    end
    s = sacc;
    for (i = 0; i < `SNB/4; i = i + 1) s = s + $signed(y[32*i +: 32]);
    r = s;
  end
endmodule
module w_ms8x8_notree(input [`SW-1:0] a, input [`SW-1:0] b, input [`SW-1:0] c, input [3:0] m, input sa, input sb, output [`SW-1:0] y);
  wire [63:0] r; w_ms8x8 u(a, b, c, m, sa, sb, 64'd0, y, r); endmodule
// the vdacc tree alone: the SNB/4 word lanes into a 64-bit scalar accumulate
module w_dacc_tree(input [`SW-1:0] lanes, input [63:0] acc, output [63:0] y);
  integer i; reg signed [63:0] s;
  always @* begin s = acc; for (i = 0; i < `SNB/4; i = i + 1) s = s + $signed(lanes[32*i +: 32]); end
  assign y = s;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// vfir.w on the shared multipliers (vec3.v vfir_added): the window select over {strip, halo}, the tap select, SNB/2 accumulators of 32 bits.  WIDTH: the filter has 8 taps whatever the
// strip is (vec-isa.md), so the halo stays 7 halfwords = 112 flip-flops, the tap register 128 bits.
module w_vfir_added(input clk, input [`SW-1:0] s, input [111:0] halo, input [127:0] taps, input [2:0] k, input first, input [16*`SNB-1:0] prod,
                    output [`SW-1:0] xo, output [15:0] tapo, output [16*`SNB-1:0] accq);
  reg [16*`SNB-1:0] acc; wire [`SW+111:0] win = {s, halo};
  integer i; reg [16*`SNB-1:0] nx; reg [`SW-1:0] x;
  always @* begin
    for (i = 0; i < `SNB/2; i = i + 1) x[16*i +: 16] = win[16*(i + 7 - k) +: 16];
    for (i = 0; i < `SNB/2; i = i + 1) nx[32*i +: 32] = (first ? 32'd0 : acc[32*i +: 32]) + prod[32*i +: 32];
  end
  always @(posedge clk) acc <= nx;
  assign xo = x; assign tapo = taps[16*k +: 16]; assign accq = acc;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// reductions into a scalar: vacc, one tree for each source type and a selector (vec2.v vacc_naive), and vmaxacc / vminacc (vmmacc)
module w_vacc_naive(input [`SW-1:0] a, input [1:0] sz, input sgn, input [63:0] acc, output reg [63:0] y);
  integer i; reg signed [63:0] sb, sw, sl, sq;
  always @* begin
    sb = 0; sw = 0; sl = 0; sq = 0;
    for (i = 0; i < `SNB; i = i + 1) sb = sb + (sgn ? {{56{a[8*i + 7]}}, a[8*i +: 8]} : {56'b0, a[8*i +: 8]});
    for (i = 0; i < `SNB/2; i = i + 1) sw = sw + (sgn ? {{48{a[16*i + 15]}}, a[16*i +: 16]} : {48'b0, a[16*i +: 16]});
    for (i = 0; i < `SNB/4; i = i + 1) sl = sl + (sgn ? {{32{a[32*i + 31]}}, a[32*i +: 32]} : {32'b0, a[32*i +: 32]});
    for (i = 0; i < `SNB/8; i = i + 1) sq = sq + a[64*i +: 64];
    y = acc + (sz == 0 ? sb : sz == 1 ? sw : sz == 2 ? sl : sq);
  end
endmodule
module w_vmmacc(input [`SW-1:0] a, input [1:0] sz, input sgn, input mx, input [63:0] acc, output reg [63:0] y);
  integer i; reg [63:0] best, v; reg lt;
  always @* begin
    best = 0;
    case (sz)
      0: begin best = sgn ? {{56{a[7]}}, a[7:0]} : {56'b0, a[7:0]};
           for (i = 1; i < `SNB; i = i + 1) begin v = sgn ? {{56{a[8*i + 7]}}, a[8*i +: 8]} : {56'b0, a[8*i +: 8]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      1: begin best = sgn ? {{48{a[15]}}, a[15:0]} : {48'b0, a[15:0]};
           for (i = 1; i < `SNB/2; i = i + 1) begin v = sgn ? {{48{a[16*i + 15]}}, a[16*i +: 16]} : {48'b0, a[16*i +: 16]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      2: begin best = sgn ? {{32{a[31]}}, a[31:0]} : {32'b0, a[31:0]};
           for (i = 1; i < `SNB/4; i = i + 1) begin v = sgn ? {{32{a[32*i + 31]}}, a[32*i +: 32]} : {32'b0, a[32*i +: 32]};
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
      default: begin best = a[63:0];
           for (i = 1; i < `SNB/8; i = i + 1) begin v = a[64*i +: 64];
             lt = sgn ? ($signed(v) < $signed(best)) : (v < best); best = (mx ? !lt : lt) ? v : best; end end
    endcase
    lt = sgn ? ($signed(best) < $signed(acc)) : (best < acc);
    y = (mx ? !lt : lt) ? best : acc;
  end
endmodule
// the sum of the SNB bytes (unsigned) into the accumulate: the tree that vsad adds to the absolute differences (it is also vacc.bu); and vsad.bu alone
module w_sum_bu(input [`SW-1:0] a, input [63:0] acc, output [63:0] y);
  integer i; reg [63:0] s;
  always @* begin s = acc; for (i = 0; i < `SNB; i = i + 1) s = s + a[8*i +: 8]; end
  assign y = s;
endmodule
module w_vsad_bu(input [`SW-1:0] a, input [`SW-1:0] b, input [63:0] acc, output [63:0] y);
  integer i; reg [63:0] s; reg [7:0] d;
  always @* begin
    s = acc;
    for (i = 0; i < `SNB; i = i + 1) begin d = (a[8*i +: 8] > b[8*i +: 8]) ? a[8*i +: 8] - b[8*i +: 8] : b[8*i +: 8] - a[8*i +: 8]; s = s + d; end
  end
  assign y = s;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// vtbl.b, register form: lane i looks in the 16 bytes of vT of its group of 16 lanes, 0 if the index is 16 or more.  WIDTH: a lane of vT that is not in the strip reads as 0 (as
// sim64's vop_tbl), so with an 8-byte strip a lane selects among 8 bytes, not 16.  (The memory form, a 16-byte table for every lane, is not counted, as in vec-silicon.md.)
module w_vtbl_g16(input [`SW-1:0] t, input [`SW-1:0] idx, output reg [`SW-1:0] y);
  integer i, p; reg [7:0] ix;
  always @* for (i = 0; i < `SNB; i = i + 1) begin
    ix = idx[8*i +: 8]; p = 16*(i/16) + ix[3:0];
    y[8*i +: 8] = (ix[7] || p >= `SNB) ? 8'h00 : t[8*p +: 8];
  end
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// compare and select.  w_vcmp_mw is vec2.v vcmp_mw (a dynamic shift of the operands for each lane: it maps to a huge Xilinx netlist, 89,804 LUT6 at 256 bits, a mapping artifact);
// w_vcmp2 is the same function with a fixed comparator for each lane of each width and a final select by sz (no dynamic shifts), the form used for the Xilinx count.
module w_vcmp_mw(input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [1:0] op, output reg [`SW-1:0] y);
  integer i, j, lb; reg lane; reg [`SW-1:0] sa, sb;
  always @* begin
    lb = 1 << sz;
    y = 0;
    for (j = 0; j < `SNB; j = j + 1) if (j % lb == 0) begin
      sa = a >> (8 * j); sb = b >> (8 * j);
      case (sz)
        0: lane = (op == 0) ? (sa[7:0] == sb[7:0]) : (op == 1) ? ($signed(sa[7:0]) > $signed(sb[7:0])) : (sa[7:0] > sb[7:0]);
        1: lane = (op == 0) ? (sa[15:0] == sb[15:0]) : (op == 1) ? ($signed(sa[15:0]) > $signed(sb[15:0])) : (sa[15:0] > sb[15:0]);
        2: lane = (op == 0) ? (sa[31:0] == sb[31:0]) : (op == 1) ? ($signed(sa[31:0]) > $signed(sb[31:0])) : (sa[31:0] > sb[31:0]);
        default: lane = (op == 0) ? (sa[63:0] == sb[63:0]) : (op == 1) ? ($signed(sa[63:0]) > $signed(sb[63:0])) : (sa[63:0] > sb[63:0]);
      endcase
      for (i = 0; i < 64; i = i + 1) if (i < 8 * lb) y[(8*j + i) % `SW] = lane;
    end
  end
endmodule
module w_cmplane #(parameter L = 1) (input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] op, output [`SW-1:0] y);
  genvar m;
  generate for (m = 0; m < `SNB / L; m = m + 1) begin: g
    wire [8*L-1:0] x = a[8*L*m +: 8*L], z = b[8*L*m +: 8*L];
    wire r = (op == 0) ? (x == z) : (op == 1) ? ($signed(x) > $signed(z)) : (x > z);
    assign y[8*L*m +: 8*L] = {(8*L){r}};
  end endgenerate
endmodule
module w_vcmp2(input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [1:0] op, output [`SW-1:0] y);
  wire [`SW-1:0] y1, y2, y4, y8;
  w_cmplane #(1) u1(a, b, op, y1); w_cmplane #(2) u2(a, b, op, y2); w_cmplane #(4) u4(a, b, op, y4); w_cmplane #(8) u8(a, b, op, y8);
  assign y = (sz == 0) ? y1 : (sz == 1) ? y2 : (sz == 2) ? y4 : y8;
endmodule
module w_vbsl(input [`SW-1:0] d, input [`SW-1:0] a, input [`SW-1:0] b, output [`SW-1:0] y); assign y = (d & a) | (~d & b); endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// segment loads and stores (vec2.v segload, segstore): one beat of the strip's width; nf = nfm1 + 1 fields (2, 3, 4), esz = 1 << ez bytes per field element, bt: which beat.
// per = SNB / (nf * esz) elements a beat.  WIDTH: with an 8-byte strip a field element of 4 bytes with 3 or 4 fields (12 or 16 bytes) does not fit in a beat (per = 0); those two
// cases are not built (the connection is left out), so the 64-bit count is short of a design that handles them (two beats an element), by an amount not measured.
function integer wsld(input integer nf, input integer esz, input integer bt, input integer f, input integer i);
  integer per, e, src;
  begin per = `SNB / (nf * esz); e = (i / esz) - bt * per; src = (e * nf + f) * esz + (i % esz);
    wsld = (per > 0 && f < nf && e >= 0 && e < per && src < `SNB) ? src : -1; end
endfunction
function integer wsst(input integer nf, input integer esz, input integer bt, input integer k);
  integer per, e, fld, src;
  begin per = `SNB / (nf * esz); fld = (k / esz) % nf; e = bt * per + (k / esz) / nf; src = e * esz + (k % esz);
    wsst = (per > 0 && src < `SNB) ? fld * `SW + 8 * src : -1; end
endfunction
module w_segload(input [`SW-1:0] m, input [1:0] nfm1, input [1:0] ez, input [1:0] bt, output reg [4*`SW-1:0] y);
  integer f, i, x, z, b, src;
  always @* begin
    y = 0;
    for (f = 0; f < 4; f = f + 1) for (i = 0; i < `SNB; i = i + 1)
      for (x = 1; x < 4; x = x + 1) for (z = 0; z < 3; z = z + 1) for (b = 0; b < 4; b = b + 1) begin
        src = wsld(x + 1, 1 << z, b, f, i);
        if (src >= 0 && nfm1 == x && ez == z && bt == b) y[`SW*f + 8*i +: 8] = m[8*src +: 8];
      end
  end
endmodule
module w_segstore(input [4*`SW-1:0] f, input [1:0] nfm1, input [1:0] ez, input [1:0] bt, output reg [`SW-1:0] y);
  integer k, x, z, b, src;
  always @* begin
    y = 0;
    for (k = 0; k < `SNB; k = k + 1)
      for (x = 1; x < 4; x = x + 1) for (z = 0; z < 3; z = z + 1) for (b = 0; b < 4; b = b + 1) begin
        src = wsst(x + 1, 1 << z, b, k);
        if (src >= 0 && nfm1 == x && ez == z && bt == b) y[8*k +: 8] = f[src +: 8];
      end
  end
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the vector register file: 16 registers of SNB bytes, 3 read ports, 1 write, flip-flops (vec2.v vregs16_r3)
module w_vregs16_r3(input clk, input [3:0] ra, input [3:0] rb, input [3:0] rc, input [3:0] wa, input we, input [`SW-1:0] wd,
                    output [`SW-1:0] qa, output [`SW-1:0] qb, output [`SW-1:0] qc);
  reg [`SW-1:0] r [0:15];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// load alignment with widening and store merge (mem2.v vmem_ld, vmem_st): a window of two strips, the offset in bytes (0 to SNB-1)
module w_vmem_ld(input [2*`SW-1:0] win, input [$clog2(`SNB)-1:0] off, input [2:0] t, input sgn, output reg [`SW-1:0] y);
  wire [2*`SW-1:0] sh = win >> (8 * off);
  integer i, tt, S, L, e, k;
  always @* begin
    y = sh[`SW-1:0];
    for (tt = 1; tt < 7; tt = tt + 1) begin
      S = (tt <= 3) ? 1 : (tt <= 5) ? 2 : 4;
      L = (tt == 1) ? 2 : (tt == 2 || tt == 4) ? 4 : 8;
      if (t == tt)
        for (i = 0; i < `SNB; i = i + 1) begin
          e = i / L; k = i % L;
          if (k < S) y[8*i +: 8] = sh[8*(e * S + k) +: 8];
          else y[8*i +: 8] = sgn ? {8{sh[8*(e * S + S - 1) + 7]}} : 8'h00;
        end
    end
  end
endmodule
module w_vmem_st(input [`SW-1:0] v, input [$clog2(`SNB)-1:0] off, input [$clog2(`SNB):0] nbytes, output [2*`SW-1:0] data, output [2*`SNB-1:0] be);
  assign data = {{`SW{1'b0}}, v} << (8 * off);
  wire [2*`SNB-1:0] ones = ({{(2*`SNB-1){1'b0}}, 1'b1} << nbytes) - 1;
  assign be = ones << off;
endmodule

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// the floating-point lanes: SNB/4 single-precision fused multiply-add lanes (fp2.v fma32x8 is 8), and the conversions vcvt.f.l, vcvt.l.f for SNB/4 lanes each way
module w_fma32xn(input [`SW-1:0] a, input [`SW-1:0] b, input [`SW-1:0] c, output [`SW-1:0] y);
  genvar i; generate for (i = 0; i < `SNB/4; i = i + 1) begin: g fma32 f(a[32*i +: 32], b[32*i +: 32], c[32*i +: 32], y[32*i +: 32]); end endgenerate
endmodule
module w_cvt_both(input [`SW-1:0] a, output [`SW-1:0] yi, output [`SW-1:0] yf);
  genvar i; generate for (i = 0; i < `SNB/4; i = i + 1) begin: g cvt_i2f u(a[32*i +: 32], yf[32*i +: 32]); cvt_f2i v(a[32*i +: 32], yi[32*i +: 32]); end endgenerate
endmodule
