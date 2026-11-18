// vecred.v -- the floating-point reduction (vacc.f) of the vec unit, four ways, for the choice of errata 173 (docs/encoding-work/vec-isa.md section 8, vec-strip.md 5.1 item 4).
// Counted with strip-synth.sh (SNB = strip bytes: read_verilog -D SNB=16|32|64): `tools/gates/run-red.sh`.  Single precision; behavioural Verilog, counted, not simulated; like fp2.v the adder
// does not handle infinities, NaNs or subnormals (a few hundred gates, not counted).  The lanes of a strip are L = SNB / 4.
//   fadd32       one floating-point add, the unit of the others
//   red_naive    the strip's own order before errata 173 (the reference): a balanced tree of the L lanes, then added to the register: L adders, no state
//   red_chunk    CHOSEN: the chunks of 4 lanes (16 bytes), each by the tree ((l0 + l1) + (l2 + l3)), added to the register one after the other: 3 adders for each chunk and one for the register: L adders, no state
//   red_part     option (b): G = 8 partial sums by element mod 8, each lane added to its own partial (L adders for L <= 8; 2 chained for L = 16), a final tree of the 8 partials at the end of the block and
//                added to the register (7 + 1 adders), 8 x 32 flip-flops of hidden state
//   red_exact    option (a): an exact (fixed-point) accumulator of 288 bits (the whole range of binary32: 2^-149 to 2^128 and carries), each lane aligned by its exponent (a shifter of 24 bits to 288),
//                the L aligned lanes and the accumulator added, 288 flip-flops; and red_round, the one rounding to binary32 at the end of the block (a count of leading zeros of 288 bits, a shifter)
`ifndef SNB
`define SNB 32
`endif
`define LN (`SNB/4)

module fadd32(input [31:0] a, input [31:0] b, output reg [31:0] y);
  reg [31:0] x, z; reg sw, eff, g, st, stk; reg [7:0] ex, ez; reg [23:0] mx, mz; reg [8:0] d; reg [4:0] sh;
  reg [26:0] fx, fz, fzs; reg [27:0] s, nrm; reg [4:0] lz; reg [24:0] man; reg signed [10:0] er; integer i;
  always @* begin
    sw = b[30:0] > a[30:0]; x = sw ? b : a; z = sw ? a : b;
    ex = x[30:23]; ez = z[30:23]; mx = {ex != 0, x[22:0]}; mz = {ez != 0, z[22:0]};
    d = {1'b0, ex} - {1'b0, ez}; sh = (d > 26) ? 5'd27 : d[4:0];
    fx = {mx, 3'b0}; fz = {mz, 3'b0}; fzs = fz >> sh;
    stk = 0; for (i = 0; i < 27; i = i + 1) if (i < sh) stk = stk | fz[i];
    eff = x[31] ^ z[31];
    s = eff ? {1'b0, fx} - {1'b0, fzs} : {1'b0, fx} + {1'b0, fzs};
    lz = 0; for (i = 27; i >= 0; i = i - 1) if (s[i] && lz == 0 && (i == 27 || ((s >> (i + 1)) == 0))) lz = 27 - i;
    nrm = s << lz; man = {1'b0, nrm[27:4]}; g = nrm[3]; st = (nrm[2:0] != 0) | stk;
    man = man + (g & (st | man[0]));
    er = {3'b0, ex} + 11'sd1 - $signed({6'b0, lz});
    if (man[24]) er = er + 1;
    y = (s == 0 || er <= 0) ? 32'b0 : (er >= 255) ? {x[31], 8'hff, 23'b0} : {x[31], er[7:0], man[24] ? 23'b0 : man[22:0]};
  end
endmodule

// the reference: a balanced tree of L lanes, then the register
module red_naive(input [32*`LN-1:0] x, input [31:0] acc, output [31:0] y);
  wire [31:0] t [0:2*`LN-1];
  genvar i;
  generate
    for (i = 0; i < `LN; i = i + 1) begin: leaf assign t[`LN + i] = x[32*i +: 32]; end
    for (i = `LN - 1; i >= 1; i = i - 1) begin: node fadd32 a(t[2*i], t[2*i+1], t[i]); end
  endgenerate
  fadd32 fin(acc, t[1], y);
endmodule

// chosen: chunks of 4 lanes, each by the fixed tree, added to the register in order (the chain through the register: `LN / 4 adds)
module red_chunk(input [32*`LN-1:0] x, input [31:0] acc, output [31:0] y);
  wire [31:0] c [0:`LN/4];
  assign c[0] = acc;
  genvar k;
  generate for (k = 0; k < `LN / 4; k = k + 1) begin: ch
    wire [31:0] s01, s23, t;
    fadd32 a(x[128*k +: 32], x[128*k+32 +: 32], s01);
    fadd32 b(x[128*k+64 +: 32], x[128*k+96 +: 32], s23);
    fadd32 d(s01, s23, t);
    fadd32 e(c[k], t, c[k+1]);
  end endgenerate
  assign y = c[`LN / 4];
endmodule

// option (b): G = 8 partials (hidden state), lane j of the strip added to the partial (element mod 8); at the end of the block a tree of the partials added to the register
module red_part(input clk, input [32*`LN-1:0] x, input [255:0] clr, input end_blk, input [31:0] acc, output [31:0] y);
  reg [255:0] p;
  wire [255:0] pn;
  genvar j;
  generate for (j = 0; j < 8; j = j + 1) begin: lane
    wire [31:0] u, v;
    if (`LN >= 16) begin
      wire [31:0] w; fadd32 a(p[32*j +: 32], x[32*j +: 32], w); fadd32 b(w, x[32*(j+8) +: 32], v); assign u = v;   // two elements for each partial: a chain of two adds
    end else if (`LN >= 8) begin
      fadd32 a(p[32*j +: 32], x[32*j +: 32], u);
    end else begin   // 4 lanes: the strip updates half of the partials, each adder takes its partial from one of two
      wire [31:0] pa = p[32*(j % 4) +: 32], pb = p[32*(j % 4 + 4) +: 32];
      fadd32 a(clr[j] ? pb : pa, x[32*(j % 4) +: 32], u);
    end
    assign pn[32*j +: 32] = u;
  end endgenerate
  always @(posedge clk) p <= end_blk ? 256'b0 : pn;
  wire [31:0] q [0:15];
  generate
    for (j = 0; j < 8; j = j + 1) begin: lf assign q[8 + j] = p[32*j +: 32]; end
    for (j = 7; j >= 1; j = j - 1) begin: nd fadd32 a(q[2*j], q[2*j+1], q[j]); end
  endgenerate
  fadd32 fin(acc, q[1], y);
endmodule

// option (a): the exact accumulator.  align: a binary32 as a signed 288-bit fixed-point number (unit 2^-149)
module red_align(input [31:0] a, output [287:0] y);
  wire [7:0] e = a[30:23]; wire [23:0] m = {e != 0, a[22:0]}; wire [8:0] sh = (e == 0) ? 9'd0 : {1'b0, e} - 9'd1;
  wire [287:0] v = {264'b0, m} << sh;
  assign y = a[31] ? ~v + 288'd1 : v;
endmodule
module red_exact(input clk, input [32*`LN-1:0] x, input clr, output [287:0] q);
  reg [287:0] acc;
  wire [287:0] t [0:`LN];
  assign t[0] = acc;
  genvar i;
  generate for (i = 0; i < `LN; i = i + 1) begin: lane
    wire [287:0] al; red_align u(x[32*i +: 32], al); assign t[i+1] = t[i] + al;
  end endgenerate
  always @(posedge clk) acc <= clr ? 288'b0 : t[`LN];
  assign q = acc;
endmodule
// the one rounding at the end of the block (and the add of the register: an exact accumulator would hold it too; counted as one adder)
module red_round(input [287:0] a, output reg [31:0] y);
  reg [287:0] mag, nrm; reg [8:0] lz; reg g, st; reg [24:0] man; reg signed [10:0] er; integer i;
  always @* begin
    mag = a[287] ? ~a + 288'd1 : a;
    lz = 0; for (i = 287; i >= 0; i = i - 1) if (mag[i] && lz == 0 && (i == 287 || ((mag >> (i + 1)) == 0))) lz = 287 - i;
    nrm = mag << lz; man = {1'b0, nrm[287:264]}; g = nrm[263]; st = (nrm[262:0] != 0);
    man = man + (g & (st | man[0]));
    er = 11'sd288 - 11'sd149 - $signed({2'b0, lz}) + (man[24] ? 11'sd1 : 11'sd0);
    y = (mag == 0 || er <= 0) ? 32'b0 : (er >= 255) ? {a[287], 8'hff, 23'b0} : {a[287], er[7:0], man[24] ? 23'b0 : man[22:0]};
  end
endmodule
