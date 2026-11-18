// Blocks of the vector, segment, gather and GEMM operations (docs/encoding-work/vec-gates.md), written to be counted, not to be used:
// each is synthesised by yosys and mapped to NAND2 and inverters (gates.sh).  Widths are the 256-bit strip of the cost-benefit study.

// a lane ALU: add, subtract, saturating add and subtract (signed), minimum, maximum, and, or, xor, shift left by one, per 16-bit lane, 16 lanes
module lanealu16(input [255:0] a, input [255:0] b, input [3:0] op, output reg [255:0] y);
  integer i;
  reg signed [16:0] s;
  reg [15:0] x, z;
  always @* begin
    for (i = 0; i < 16; i = i + 1) begin
      x = a[16*i +: 16]; z = b[16*i +: 16];
      case (op)
        0: y[16*i +: 16] = x + z;
        1: y[16*i +: 16] = x - z;
        2: begin s = $signed({x[15], x}) + $signed({z[15], z});
             y[16*i +: 16] = (s > 32767) ? 16'h7fff : (s < -32768) ? 16'h8000 : s[15:0]; end
        3: begin s = $signed({x[15], x}) - $signed({z[15], z});
             y[16*i +: 16] = (s > 32767) ? 16'h7fff : (s < -32768) ? 16'h8000 : s[15:0]; end
        4: y[16*i +: 16] = ($signed(x) < $signed(z)) ? x : z;
        5: y[16*i +: 16] = ($signed(x) > $signed(z)) ? x : z;
        6: y[16*i +: 16] = x & z;
        7: y[16*i +: 16] = x | z;
        8: y[16*i +: 16] = x ^ z;
        default: y[16*i +: 16] = x << 1;
      endcase
    end
  end
endmodule

// the same without the saturating and min/max operations (a plain add, subtract, and, or, xor)
module lanealu16plain(input [255:0] a, input [255:0] b, input [2:0] op, output reg [255:0] y);
  integer i;
  always @* begin
    for (i = 0; i < 16; i = i + 1)
      case (op)
        0: y[16*i +: 16] = a[16*i +: 16] + b[16*i +: 16];
        1: y[16*i +: 16] = a[16*i +: 16] - b[16*i +: 16];
        2: y[16*i +: 16] = a[16*i +: 16] & b[16*i +: 16];
        3: y[16*i +: 16] = a[16*i +: 16] | b[16*i +: 16];
        default: y[16*i +: 16] = a[16*i +: 16] ^ b[16*i +: 16];
      endcase
  end
endmodule

module mul8s(input signed [7:0] a, input signed [7:0] b, output signed [15:0] y); assign y = a * b; endmodule
module mul16s(input signed [15:0] a, input signed [15:0] b, output signed [31:0] y); assign y = a * b; endmodule
module mul24u(input [23:0] a, input [23:0] b, output [47:0] y); assign y = a * b; endmodule
module add32(input [31:0] a, input [31:0] b, output [31:0] y); assign y = a + b; endmodule
module add48(input [47:0] a, input [47:0] b, output [47:0] y); assign y = a + b; endmodule
module add64(input [63:0] a, input [63:0] b, output [63:0] y); assign y = a + b; endmodule

// a 48-bit barrel shifter (the alignment of a floating-point add), and a leading-zero count with the normalising shift
module shr48(input [47:0] a, input [5:0] n, output [47:0] y); assign y = a >> n; endmodule
module norm48(input [47:0] a, output reg [47:0] y, output reg [5:0] n);
  integer i;
  always @* begin
    n = 0;
    for (i = 47; i >= 0; i = i - 1) if (a[i] && n == 0 && (i == 47 || ((a >> (i + 1)) == 0))) n = 47 - i;
    y = a << n;
  end
endmodule

// int8 dot product: four 8x8 products and a four-input addition into a 32-bit lane, with the accumulation
module dot4(input [31:0] a, input [31:0] b, input signed [31:0] acc, output signed [31:0] y);
  wire signed [15:0] p0 = $signed(a[7:0]) * $signed(b[7:0]);
  wire signed [15:0] p1 = $signed(a[15:8]) * $signed(b[15:8]);
  wire signed [15:0] p2 = $signed(a[23:16]) * $signed(b[23:16]);
  wire signed [15:0] p3 = $signed(a[31:24]) * $signed(b[31:24]);
  assign y = acc + p0 + p1 + p2 + p3;
endmodule

// the sum of 16 lanes of 16 bits into a 32-bit result (the reduction `vacc`), and its accumulate into a 64-bit register
module reduce16(input [255:0] a, input [63:0] acc, output [63:0] y);
  integer i;
  reg signed [31:0] s;
  always @* begin
    s = 0;
    for (i = 0; i < 16; i = i + 1) s = s + $signed(a[16*i +: 16]);
  end
  assign y = acc + {{32{s[31]}}, s};
endmodule

// the hidden vector registers: 8 registers of 256 bits, 3 read ports and 1 write port
module vregs(input clk, input [2:0] ra, input [2:0] rb, input [2:0] rc, input [2:0] wa, input we, input [255:0] wd,
             output [255:0] qa, output [255:0] qb, output [255:0] qc);
  reg [255:0] r [0:7];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule

// segment load: the 32 bytes read from memory de-interleaved into 2, 3 or 4 fields of 8 bits per element: each output byte chooses among three source bytes
module segload8(input [255:0] m, input [1:0] nf, output reg [255:0] y);
  integer i;
  always @* for (i = 0; i < 32; i = i + 1)
    case (nf) 0: y[8*i +: 8] = m[8*((2*i) % 32) +: 8]; 1: y[8*i +: 8] = m[8*((3*i) % 32) +: 8]; default: y[8*i +: 8] = m[8*((4*i) % 32) +: 8]; endcase
endmodule

// gather, one lane a cycle: the address of the lane (a base and a scaled index selected from the 16 lanes) and the lane counter
module gather1(input clk, input [63:0] base, input [255:0] idx, input [1:0] sc, input start, output reg [63:0] addr, output reg [3:0] lane);
  wire [15:0] ix = idx[16*lane +: 16];
  always @(posedge clk) begin
    if (start) lane <= 0; else lane <= lane + 1;
    addr <= base + ({48'b0, ix} << sc);
  end
endmodule

// the sliding window: one output lane is eight taps of 8-bit times 8-bit, summed (the multipliers are counted separately)
module firsum8(input [127:0] p, output [18:0] y);
  integer i; reg [18:0] s;
  always @* begin s = 0; for (i = 0; i < 8; i = i + 1) s = s + p[16*i +: 16]; end
  assign y = s;
endmodule
