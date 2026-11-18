// Blocks of the scalar core of the pdp64 (docs/encoding-work/vec-gates.md section "the scalar core"), written to be counted, not to be used: yosys, mapped to NAND2.

// 32 registers of 64 bits, 3 read ports and 1 write port (the three-register and the four-register forms read up to three)
module rf3(input clk, input [4:0] ra, input [4:0] rb, input [4:0] rc, input [4:0] wa, input we, input [63:0] wd, output [63:0] qa, output [63:0] qb, output [63:0] qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule

// the integer ALU: add, subtract, add and subtract with carry, and, or, bit clear, xor, compare outputs (the four flags), the maskeqz/masknez select, min/max (signed and unsigned), abs
module alu64(input [63:0] a, input [63:0] b, input cin, input [4:0] op, output reg [63:0] y, output reg [3:0] nzvc);
  wire [64:0] s = {1'b0, a} + {1'b0, b} + {64'b0, cin};
  wire [64:0] d = {1'b0, a} - {1'b0, b} - {64'b0, cin};
  wire lt = $signed(a) < $signed(b), ltu = a < b;
  always @* begin
    nzvc = 0;
    case (op)
      0: begin y = s[63:0]; nzvc = {y[63], y == 0, (a[63] == b[63]) && (y[63] != a[63]), s[64]}; end
      1: begin y = d[63:0]; nzvc = {y[63], y == 0, (a[63] != b[63]) && (y[63] != a[63]), d[64]}; end
      2: y = a & b;
      3: y = a | b;
      4: y = a & ~b;
      5: y = a ^ b;
      6: y = lt ? a : b;
      7: y = lt ? b : a;
      8: y = ltu ? a : b;
      9: y = ltu ? b : a;
      10: y = (b == 0) ? 64'b0 : a;
      11: y = (b != 0) ? 64'b0 : a;
      12: y = a[63] ? -a : a;
      default: y = a;
    endcase
  end
endmodule

// shifts and rotates: left, logical right, arithmetic right, rotate (64 bits), with the 32-bit forms
module shift64(input [63:0] a, input [5:0] n, input [2:0] op, output reg [63:0] y);
  wire [127:0] dbl = {a, a};
  always @* case (op)
    0: y = a << n;
    1: y = a >> n;
    2: y = $signed(a) >>> n;
    3: y = dbl[63:0] >> n;
    4: y = {{32{a[31]}}, a[31:0]} >> n;
    default: y = a;
  endcase
endmodule

// the bit manipulation words: count leading and trailing zeros and ones, population count, byte swap, bit reverse
module bitops64(input [63:0] a, input [2:0] op, output reg [63:0] y);
  integer i; reg [6:0] c; reg [63:0] t;
  always @* begin
    y = 0; c = 0;
    case (op)
      0: begin for (i = 63; i >= 0; i = i - 1) if (c == 63 - i && !a[i]) c = c + 1; y = c; end
      1: begin for (i = 0; i < 64; i = i + 1) if (c == i && !a[i]) c = c + 1; y = c; end
      2: begin for (i = 0; i < 64; i = i + 1) c = c + a[i]; y = c; end
      3: for (i = 0; i < 8; i = i + 1) y[8*i +: 8] = a[8*(7-i) +: 8];
      4: for (i = 0; i < 64; i = i + 1) y[i] = a[63-i];
      default: y = a;
    endcase
  end
endmodule

module mul64(input [63:0] a, input [63:0] b, output [127:0] y); assign y = a * b; endmodule

// an iterative divider: one quotient bit a cycle (the registers and the subtractor)
module div64(input clk, input start, input [63:0] n, input [63:0] d, output reg [63:0] q, output reg [63:0] r, output reg done);
  reg [63:0] dd; reg [6:0] cnt; reg [127:0] rem;
  wire [64:0] sub = {rem[126:63]} - {1'b0, dd};
  always @(posedge clk) begin
    if (start) begin rem <= {64'b0, n}; dd <= d; cnt <= 0; q <= 0; done <= 0; end
    else if (!done) begin
      if (!sub[64]) begin rem <= {sub[63:0], rem[62:0], 1'b0}; q <= {q[62:0], 1'b1}; end
      else begin rem <= {rem[126:0], 1'b0}; q <= {q[62:0], 1'b0}; end
      cnt <= cnt + 1; if (cnt == 63) begin done <= 1; r <= rem[127:64]; end
    end
  end
endmodule

// double precision floating point: the pieces (the multiplier of 53 x 53 bits, the aligner and the adder of a fused multiply-add of 106 bits, the normaliser)
module mul53(input [52:0] a, input [52:0] b, output [105:0] y); assign y = a * b; endmodule
module shr106(input [105:0] a, input [6:0] n, output [105:0] y); assign y = a >> n; endmodule
module add106(input [105:0] a, input [105:0] b, output [105:0] y); assign y = a + b; endmodule
module norm106(input [105:0] a, output reg [105:0] y, output reg [6:0] n);
  integer i;
  always @* begin
    n = 0;
    for (i = 105; i >= 0; i = i - 1) if (a[i] && n == 0 && (i == 105 || ((a >> (i + 1)) == 0))) n = 105 - i;
    y = a << n;
  end
endmodule

// carry-less multiply 64 x 64 (a crypto word): the AND array and the XOR trees
module clmul64(input [63:0] a, input [63:0] b, output reg [127:0] y);
  integer i;
  always @* begin y = 0; for (i = 0; i < 64; i = i + 1) if (b[i]) y = y ^ ({64'b0, a} << i); end
endmodule

// the load alignment and the store merge of 64 bits: a rotate of 8 bytes by a byte count, and the byte-lane merge
module ldalign(input [63:0] m, input [2:0] off, input [1:0] sz, input sgn, output reg [63:0] y);
  wire [127:0] dbl = {m, m};
  wire [63:0] sh = dbl[63:0] >> (8 * off);
  always @* case (sz) 0: y = sgn ? {{56{sh[7]}}, sh[7:0]} : {56'b0, sh[7:0]}; 1: y = sgn ? {{48{sh[15]}}, sh[15:0]} : {48'b0, sh[15:0]};
    2: y = sgn ? {{32{sh[31]}}, sh[31:0]} : {32'b0, sh[31:0]}; default: y = sh; endcase
endmodule
module stmerge(input [63:0] old, input [63:0] v, input [2:0] off, input [1:0] sz, output [63:0] y);
  wire [63:0] mask = (sz == 0 ? 64'hff : sz == 1 ? 64'hffff : sz == 2 ? 64'hffffffff : 64'hffffffffffffffff) << (8 * off);
  assign y = (old & ~mask) | ((v << (8 * off)) & mask);
endmodule

// a translation buffer of 32 entries: a virtual page number of 28 bits, a physical page number of 28 bits, 8 flag bits (the page-table entry of spec/grammars.d/50-system-v1.hbnf), the match of all entries
module tlb32(input clk, input [27:0] vpn, input we, input [4:0] wi, input [63:0] wd, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31];
  reg [31:0] m;
  integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = (e[i][63:36] == vpn);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) if (we) e[wi] <= wd;
endmodule
