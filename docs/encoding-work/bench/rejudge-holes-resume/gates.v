// New models for the re-judgement, written in the style of ../holes-1-and-6/gates (behavioural; the repository's yosys method).
// ---- hole 6: hardware that tracks "this register holds the user's value" (one bit U per register) ----
// rf_w (design T0): U set for all registers at entry from a lesser mode; any write clears the register's bit; a return to a lesser mode clears every register whose bit is 0. No mask.
module rf_w(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input rti_down, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] u;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (enter) u[i] <= 1'b1;
    else if (we && wa == i) u[i] <= 1'b0;
    if (rti_down && !u[i]) r[i] <= 64'b0;
    else if (we && wa == i) r[i] <= wd;
  end
endmodule
// rf_t1 (design T1): as rf_w, and a POPM (pop_en, pop_mask) sets the bit of each popped register from the bit stored beside the value (tagin); a PUSHM reads the bits out (tagout).
module rf_t1(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input rti_down, input pop_en, input [31:0] pop_mask, input [31:0] tagin, output [31:0] tagout, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] u;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc]; assign tagout = u;
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (enter) u[i] <= 1'b1;
    else if (pop_en && pop_mask[i]) u[i] <= tagin[i];
    else if (we && wa == i) u[i] <= 1'b0;
    if (rti_down && !u[i]) r[i] <= 64'b0;
    else if (we && wa == i) r[i] <= wd;
  end
endmodule
// ---- hole 1: how the arena's flag reaches a core that did not make the store ----
// arena_flag: the repository's proposal for one core: two range comparators on two store ports (the core's and one more), the refusal test of the walker, and a flag (the two ports and the refusal come from h1.v `arena`).
// arena_snoop_core: one more comparator for every OTHER core's store port that reaches this core (what "every core runs the same range test on the stores that reach the shared memory" needs, per remote core).
module arena_snoop_core(input [27:0] lo, input [27:0] hi, input sv, input [27:0] sppn, output hit);
  assign hit = sv & (sppn >= lo) & (sppn < hi);
endmodule
// arena_epoch: the alternative.  The storing core's own comparator (the same one) increments a 64-bit epoch word in shared memory (a read-modify-write by the storing core, ordinary coherent memory);
// the entering core compares the word, which it has loaded, with the copy it keeps from its last flush.  No snoop wiring, any number of cores.  This module is the entering core's part only:
// a 64-bit register, a 64-bit equality and a valid bit.
module arena_epoch_enter(input clk, input genter, input [63:0] mem_epoch, input flushed, output discard);
  reg [63:0] seen; reg v;
  assign discard = genter & (~v | (mem_epoch != seen));
  always @(posedge clk) if (flushed) begin seen <= mem_epoch; v <= 1'b1; end
endmodule
// ... and the storing core's part: a hit increments (the increment is done by a normal add in the core; here a 64-bit incrementer is counted for the case where it is done in hardware).
module arena_epoch_inc(input clk, input hit, input [63:0] mem_epoch, output [63:0] next);
  assign next = hit ? mem_epoch + 64'd1 : mem_epoch;
endmodule
// ---- vector resume: the token (a counter that cannot repeat, not shown to others as a count) ----
module tok_ctr32(input clk, input inc, output [31:0] t);               // today's design without the scrambler: a 32-bit counter
  reg [31:0] c; always @(posedge clk) if (inc) c <= c + 1; assign t = c;
endmodule
// a keyed permutation of the counter: a Feistel network is a permutation whatever the round function, so tokens of one key never repeat until the counter wraps.
module feistel #(parameter W=48, parameter R=4) (input [W-1:0] x, input [W/2*R-1:0] key, output [W-1:0] y);
  localparam H = W/2;
  wire [H-1:0] l [0:R]; wire [H-1:0] r [0:R];
  assign l[0] = x[W-1:H]; assign r[0] = x[H-1:0];
  genvar i;
  generate for (i = 0; i < R; i = i + 1) begin : rd
    wire [H-1:0] f = ((r[i] ^ key[i*H +: H]) + {r[i][H-5:0], r[i][H-1:H-4]}) ^ {r[i][3:0], r[i][H-1:4]};
    assign l[i+1] = r[i]; assign r[i+1] = l[i] ^ f;
  end endgenerate
  assign y = {l[R], r[R]};
endmodule
module tok_perm48(input clk, input inc, input [95:0] key, output [47:0] t);
  reg [47:0] c; always @(posedge clk) if (inc) c <= c + 1; feistel #(48,4) f(c, key, t);
endmodule
module tok_perm32(input clk, input inc, input [63:0] key, output [31:0] t);
  reg [31:0] c; always @(posedge clk) if (inc) c <= c + 1; feistel #(32,4) f(c, key, t);
endmodule
// ---- guest tag allocated by the hardware (a reused number is a new generation by construction: the number is never chosen by software, and the wrap flushes everything) ----
module tag_alloc(input clk, input rst, input newtag, output [15:0] tag, output flush_all);
  reg [15:0] c; reg wrapped;
  assign tag = c; assign flush_all = newtag & (c == 16'hffff);
  always @(posedge clk) begin
    if (rst) begin c <= 16'd1; end
    else if (newtag) c <= (c == 16'hffff) ? 16'd1 : c + 1;
  end
endmodule
// ---- what the flash clear costs for the vector registers: 16 registers x 256 bits (the widest the design names), 2 read ports, 1 write port; "clear" is one input for the whole file (mask bit 14, which names no register, says keep) ----
module vrf_base(input clk, input [3:0] ra, rb, wa, input we, input [255:0] wd, output [255:0] qa, qb);
  reg [255:0] r [0:15]; assign qa = r[ra]; assign qb = r[rb];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule
module vrf_flash(input clk, input [3:0] ra, rb, wa, input we, input [255:0] wd, input clr, output [255:0] qa, qb);
  reg [255:0] r [0:15]; assign qa = r[ra]; assign qb = r[rb];
  integer i;
  always @(posedge clk) for (i = 0; i < 16; i = i + 1) if (clr) r[i] <= 256'b0; else if (we && wa == i) r[i] <= wd;
endmodule
