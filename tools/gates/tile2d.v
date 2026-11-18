// tile2d.v -- the silicon of the 2D block (vec2, errata 176; docs/encoding-work/vec-2d.md), as blocks.v measures the rest of the vector unit: gates.sh yosys tile2d.v
// (NAND2 equivalents of logic; flip-flops counted apart).  The integer registers are the machine's (the pointers, Re, Rn, Rw and the gaps are ordinary registers that the block reads and writes
// through the ports the strip commit already has); what is added is the arithmetic of the row advance and the decode latches.
module add64(input [63:0] a, input [63:0] b, output [63:0] s);
  assign s = a + b;
endmodule
// the row end: after a strip, the first stream's pointer has reached Re (unsigned compare, as the strip loop's `end <= cur`)
module rowend64(input [63:0] rs, input [63:0] re, output done);
  assign done = re <= rs;
endmodule
// the row count: Rn - 1 and the test for zero
module rowcnt64(input [63:0] rn, output [63:0] rn1, output zero);
  assign rn1 = rn - 64'd1;
  assign zero = (rn == 64'd0);
endmodule
// Re advance: Re + Rw + (the gap of the first stream's pointer, or 0): a 3-input add (carry-save then one carry-propagate)
module readv(input [63:0] re, input [63:0] rw, input [63:0] g1, output [63:0] re1);
  assign re1 = re + rw + g1;
endmodule
// the four pointer adders of the row advance and the Re adder and the counter: the whole datapath of a row advance, four streams
module rowadv4(input [63:0] p0, p1, p2, p3, g0, g1, g2, g3, re, rw, rn, rs, output [63:0] q0, q1, q2, q3, re1, rn1, output done, zero);
  assign q0 = p0 + g0; assign q1 = p1 + g1; assign q2 = p2 + g2; assign q3 = p3 + g3;
  assign re1 = re + rw + g0;
  assign rn1 = rn - 64'd1; assign zero = (rn == 64'd0); assign done = re <= rs;
endmodule
// the same with one adder shared by the four streams (the pointer updates take four cycles instead of one): a 4:1 multiplexer on each input and the output select
module rowadv1(input [63:0] p0, p1, p2, p3, g0, g1, g2, g3, input [1:0] sel, output [63:0] q);
  wire [63:0] p = sel == 0 ? p0 : sel == 1 ? p1 : sel == 2 ? p2 : p3;
  wire [63:0] g = sel == 0 ? g0 : sel == 1 ? g1 : sel == 2 ? g2 : g3;
  assign q = p + g;
endmodule
// a bounds check of one stream (not built; costed): the strip's first and last byte against [lo, hi): two unsigned 64-bit compares (the end address p + bytes is the pointer adder's output)
module bound1(input [63:0] p, input [63:0] pend, input [63:0] lo, input [63:0] hi, output ok);
  assign ok = (p >= lo) && (pend <= hi);
endmodule
module bound4(input [63:0] p0, p1, p2, p3, e0, e1, e2, e3, lo0, lo1, lo2, lo3, hi0, hi1, hi2, hi3, output ok);
  assign ok = (p0 >= lo0 && e0 <= hi0) && (p1 >= lo1 && e1 <= hi1) && (p2 >= lo2 && e2 <= hi2) && (p3 >= lo3 && e3 <= hi3);
endmodule
// the decode latches of a 2D block: four (pointer index, gap index) pairs of 5 bits, a valid bit each, the 2D flag (hidden state that is re-made by decoding the header again at a restart)
module latches(input clk, input [39:0] din, input [3:0] v, input two, input ld, output reg [39:0] q, output reg [3:0] qv, output reg q2);
  always @(posedge clk) if (ld) begin q <= din; qv <= v; q2 <= two; end
endmodule
