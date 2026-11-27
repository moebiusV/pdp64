// colour.v: behavioural models of the colour designs, counted by the repository's flow (gates.sh here: yosys, abc to NAND2, inverter 0.5, flip-flops apart).
// NO timing, NO wiring, NO memory arrays: logic only.  Colour 0 = uncoloured memory, 15 = freed (design 1 and 5).
module col4_check(input [3:0] pc, input [3:0] mc, output fault);   // equality of pointer colour and memory colour, and the freed colour faults even for an equal pointer colour
  assign fault = (mc == 4'd15) | (pc != mc);
endmodule
module col4_check_8bit(input [7:0] pc, input [7:0] mc, output fault);
  assign fault = (mc == 8'd255) | (pc != mc);
endmodule
module col2_check(input [1:0] pc, input [1:0] mc, output fault);    // 2 bits of memory colour: 00 poisoned, 01 colour A, 10 colour B, 11 unused (treated as poisoned); pointer carries 2 bits (01 or 10)
  assign fault = (mc == 2'd0) | (mc == 2'd3) | (pc != mc);
endmodule
module poison1_check(input p0, input p1, input two, output fault);  // one poison bit per granule: an access touches one or (unaligned or wide) two granules
  assign fault = p0 | (two & p1);
endmodule
module poison1_check5(input [4:0] p, input [4:0] n, output fault);   // an access of up to 64 bytes unaligned touches up to 5 granules: n marks which
  assign fault = |(p & n);
endmodule
// the canonical-address rule now: the bits above the top translated bit equal it. mode 0: 39 bits (bit 38 is the top), 1: 48 (bit 47), 2: 57 (bit 56)
module canon_old(input [63:0] va, input [1:0] mode, output fault);
  wire t = (mode == 2'd0) ? va[38] : (mode == 2'd1) ? va[47] : va[56];
  wire [63:0] rep = {64{t}};
  wire [63:0] mask = (mode == 2'd0) ? 64'hFFFFFF8000000000 : (mode == 2'd1) ? 64'hFFFF800000000000 : 64'hFE00000000000000;
  assign fault = |((va ^ rep) & mask);
endmodule
// with a four-bit colour field in bits 63..60: they are not compared, and the translation never reads them
module canon_col(input [63:0] va, input [1:0] mode, output fault);
  wire t = (mode == 2'd0) ? va[38] : (mode == 2'd1) ? va[47] : va[56];
  wire [63:0] rep = {64{t}};
  wire [63:0] mask = (mode == 2'd0) ? 64'h0FFFFF8000000000 : (mode == 2'd1) ? 64'h0FFF800000000000 : 64'h0E00000000000000;
  assign fault = |((va ^ rep) & mask);
endmodule
// a pointer compare that ignores the colour: what the compiler would use for a relational compare (a mask first; here the comparator on 60 bits against 64)
module ucmp64(input [63:0] a, input [63:0] b, output lt);  assign lt = a < b; endmodule
module ucmp60(input [63:0] a, input [63:0] b, output lt);  assign lt = a[59:0] < b[59:0]; endmodule
