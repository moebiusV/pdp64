// RTI mask reuse: the register file of 32 x 64 bits with the flash clear (same model as rf_flash of ../holes-1-and-6/gates/h6.v, copied here so that the references can be reproduced
// from this directory) and, around it, the places where the mask can come from.
// rf_base2 and rf_imm: the references.  keep = the mask; a register whose bit is zero is cleared by the return to a lesser mode (rti_down).
module rf_base2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) if (we && wa == i) r[i] <= wd;
endmodule
// B: the mask is the immediate of the instruction (an input from the decoder; its 32 bits travel with the instruction)
module rf_imm(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1)
    if (rti_down && !keep[i]) r[i] <= 64'b0;
    else if (we && wa == i) r[i] <= wd;
endmodule
// A1: one latch, written by GENTER (gen_w, gen_m = the immediate of GENTER); RTI has no immediate and always uses the latch
module rf_a1(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (gen_w) lat <= gen_m;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !lat[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// A2: RTI either carries an immediate (a long form: it is used and it replaces the latch) or not (a short form: the latch is used); GENTER writes the latch too.
module rf_a2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat;
  wire [31:0] keep = short ? lat : imm;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (gen_w) lat <= gen_m; else if (rti_down) lat <= keep;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// A2 with the latch readable and writable as a system register (so that a context switch or a guest switch can save and restore it): MFSR reads it, MTSR writes it.
module rf_a2_sr(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input short, input [31:0] imm, input gen_w, input [31:0] gen_m,
                input sr_w, input [31:0] sr_d, input sr_sel, input [31:0] sr_other, output [31:0] sr_q, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat;
  wire [31:0] keep = short ? lat : imm;
  assign sr_q = sr_sel ? lat : sr_other;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (sr_w) lat <= sr_d; else if (gen_w) lat <= gen_m; else if (rti_down) lat <= keep;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// A2 with two latches: one for the code that runs GENTER (the hypervisor level), one for the code that runs RTI inside a guest or a native kernel (level = which one)
module rf_a2_lvl(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input lvl, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat0, lat1;
  wire [31:0] lat = lvl ? lat1 : lat0;
  wire [31:0] keep = short ? lat : imm;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (gen_w) lat1 <= gen_m;
    if (rti_down) lat0 <= keep;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// A2 with one latch per nesting level (N levels, a pointer that moves at every exception entry and every return): the nested entry pushes, the return pops
module rf_a2_nest #(parameter N=4, parameter LG=2) (input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input enter, input ret, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat [0:N-1];
  reg [LG-1:0] p;
  wire [31:0] cur = lat[p];
  wire [31:0] keep = short ? cur : imm;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (enter) p <= p + 1; else if (ret) p <= p - 1;
    if (gen_w) lat[p] <= gen_m; else if (rti_down) lat[p] <= keep;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
module rf_a2_nest2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input enter, input ret, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  rf_a2_nest #(2,1) x(clk, ra, rb, rc, wa, we, wd, rti_down, enter, ret, short, imm, gen_w, gen_m, qa, qb, qc);
endmodule
module rf_a2_nest4(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input enter, input ret, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  rf_a2_nest #(4,2) x(clk, ra, rb, rc, wa, we, wd, rti_down, enter, ret, short, imm, gen_w, gen_m, qa, qb, qc);
endmodule
module rf_a2_nest8(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input enter, input ret, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  rf_a2_nest #(8,3) x(clk, ra, rb, rc, wa, we, wd, rti_down, enter, ret, short, imm, gen_w, gen_m, qa, qb, qc);
endmodule
// A3: one latch for each kind of return (start, system call, fault or interrupt, GENTER: 4 latches, kind = 2 bits), constant after the kernel has set them; a long form RTI uses its immediate and sets the latch of its kind
module rf_a3(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input [1:0] kind, input short, input [31:0] imm, input gen_w, input [31:0] gen_m, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] lat [0:3];
  wire [31:0] cur = lat[kind];
  wire [31:0] keep = short ? cur : imm;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (gen_w) lat[3] <= gen_m; else if (rti_down) lat[kind] <= keep;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
