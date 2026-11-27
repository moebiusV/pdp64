// colour3.v: the 3-bit colour against the 4-bit colour, counted by the repository's flow (gates3.sh here = gates.sh on this file: yosys, abc to NAND2, inverter 0.5, flip-flops apart).
// Colour 0 = uncoloured memory, all ones = freed (7 with 3 bits, 15 with 4).  NO timing, NO wiring, NO memory arrays: logic only.  New file: colour.v is unchanged.
module col3_check(input [2:0] pc, input [2:0] mc, output fault);  assign fault = (mc == 3'd7) | (pc != mc); endmodule
module col4_check(input [3:0] pc, input [3:0] mc, output fault);  assign fault = (mc == 4'd15) | (pc != mc); endmodule
// an access touching up to two granules (unaligned or 32 bytes): two compares
module col3_check2(input [2:0] pc, input [2:0] m0, input [2:0] m1, input two, output fault);  assign fault = ((m0 == 3'd7) | (pc != m0)) | (two & ((m1 == 3'd7) | (pc != m1))); endmodule
module col4_check2(input [3:0] pc, input [3:0] m0, input [3:0] m1, input two, output fault);  assign fault = ((m0 == 4'd15) | (pc != m0)) | (two & ((m1 == 4'd15) | (pc != m1))); endmodule
// picking one granule's colour out of the colours of a 64-byte line (4 granules): 12 bits against 16
module sel3_line(input [11:0] t, input [1:0] i, output [2:0] c);  assign c = t[i*3 +: 3]; endmodule
module sel4_line(input [15:0] t, input [1:0] i, output [3:0] c);  assign c = t[i*4 +: 4]; endmodule
// picking out of a 128-byte pair of lines (8 granules): 24 bits against 32
module sel3_pair(input [23:0] t, input [2:0] i, output [2:0] c);  assign c = t[i*3 +: 3]; endmodule
module sel4_pair(input [31:0] t, input [2:0] i, output [3:0] c);  assign c = t[i*4 +: 4]; endmodule
// the canonical-address rule: the bits above the top translated bit equal it; the colour field is not compared.  mode 0: 39 bits (bit 38 top), 1: 48 (bit 47), 2: 57 (bit 56)
module canon_col4(input [63:0] va, input [1:0] mode, output fault);
  wire t = (mode == 2'd0) ? va[38] : (mode == 2'd1) ? va[47] : va[56];
  wire [63:0] rep = {64{t}};
  wire [63:0] mask = (mode == 2'd0) ? 64'h0FFFFF8000000000 : (mode == 2'd1) ? 64'h0FFF800000000000 : 64'h0E00000000000000;
  assign fault = |((va ^ rep) & mask);
endmodule
module canon_col3(input [63:0] va, input [1:0] mode, output fault);
  wire t = (mode == 2'd0) ? va[38] : (mode == 2'd1) ? va[47] : va[56];
  wire [63:0] rep = {64{t}};
  wire [63:0] mask = (mode == 2'd0) ? 64'h1FFFFF8000000000 : (mode == 2'd1) ? 64'h1FFF800000000000 : 64'h1E00000000000000;
  assign fault = |((va ^ rep) & mask);
endmodule
module ucmp64(input [63:0] a, input [63:0] b, output lt);  assign lt = a < b; endmodule
module ucmp61(input [63:0] a, input [63:0] b, output lt);  assign lt = a[60:0] < b[60:0]; endmodule
module ucmp60(input [63:0] a, input [63:0] b, output lt);  assign lt = a[59:0] < b[59:0]; endmodule
