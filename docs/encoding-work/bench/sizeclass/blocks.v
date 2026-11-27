// blocks.v: the extra logic of three pieces, written to be counted by the repository's flow (tools/gates/gates.sh: yosys synth -flatten, abc -g NAND; the unit is
// the NAND2 equivalent, an inverter 0.5, a flip-flop apart and 6 in the totals).  A behavioural model of the logic, not a design of the core: no timing, no wiring.
// 57 bits is the widest virtual address (five levels); the narrower widths are subsets of it (the same logic with the upper bits tied), so this is the upper bound.

// stack limit: the privileged limit register (57 flip-flops) and the unsigned comparator on the new value of SP, which faults when SP < limit
module stacklimit(input clk, input we, input [56:0] d, input [56:0] sp_new, output fault);
  reg [56:0] lim; always @(posedge clk) if (we) lim <= d;
  assign fault = sp_new < lim;
endmodule

// the comparator alone (a limit register that is a system register already counted elsewhere)
module stacklimit_cmp(input [56:0] sp_new, input [56:0] lim, output fault);
  assign fault = sp_new < lim;
endmodule

// size class, checked on an effective address: the pointer's base register has class c (0 = unchecked; 1..63 the slot is 2^c bytes, 16..) and the address is the
// effective address; fault when they are not in the same aligned slot of 2^c bytes
module sizeclass_ea(input [56:0] base, input [56:0] ea, input [5:0] c, output fault);
  wire [56:0] mask;
  genvar i;
  generate for (i = 0; i < 57; i = i + 1) begin : m
    assign mask[i] = (c != 0) && (i >= c);          // bits at and above bit c must agree
  end endgenerate
  assign fault = |((base ^ ea) & mask);
endmodule

// the same for one memory access of two ports (a core with two memory ports needs two); counted as two copies
module sizeclass_ea2(input [56:0] b0, input [56:0] e0, input [5:0] c0, input [56:0] b1, input [56:0] e1, input [5:0] c1, output fault);
  wire f0, f1;
  sizeclass_ea u0(b0, e0, c0, f0); sizeclass_ea u1(b1, e1, c1, f1);
  assign fault = f0 | f1;
endmodule

// memory colour, checked on an access: the pointer's 4-bit colour against the granule's 4-bit colour; the reserved colour 0 (unwritten: a load faults, a store
// faults unless it writes the whole granule) and 15 (freed: any access faults)
module colourcheck(input [3:0] pc, input [3:0] mc, input is_store, input full_granule, output fault);
  wire unwritten = (mc == 4'd0), freed = (mc == 4'd15);
  assign fault = freed | (unwritten & ~(is_store & full_granule)) | (~unwritten & ~freed & (pc != mc));
endmodule

// a one-bit lane of the register file: what a 'valid pointer' tag per register costs in the registers is a 65th bit of every register of the 32: the flip-flops
// (32), a write port (an enable and a multiplexer) and three read ports; modelled as a 32 x 1 array with 3 read ports and 1 write, as rf3 of core-silicon-blocks.tsv is 32 x 64
module tagregs(input clk, input we, input [4:0] wa, input wd, input [4:0] ra0, input [4:0] ra1, input [4:0] ra2, output rd0, output rd1, output rd2);
  reg [31:0] t; always @(posedge clk) if (we) t[wa] <= wd;
  assign rd0 = t[ra0]; assign rd1 = t[ra1]; assign rd2 = t[ra2];
endmodule
