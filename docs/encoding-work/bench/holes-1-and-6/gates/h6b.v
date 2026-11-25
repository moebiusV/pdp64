// Hole 6, the spellings of the mask, and the stash, written in the same style as h6.v (rf_base2, rf_flash, rf_lazy2: one register at a time, so that the differences are comparable).
// Register file: 32 x 64 bits, 3 read ports, 1 write port.
// rf_flash_reg: the mask comes from a 32-bit system register that the kernel writes (mtsr), instead of from the instruction.
module rf_flash_reg(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input kw, input [31:0] kd, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] keepr;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (kw) keepr <= kd;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keepr[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// the same, but the register is one-shot: every return to a lesser mode resets it to zero ("clear everything" unless the kernel wrote it again)
module rf_flash_reg1(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input kw, input [31:0] kd, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] keepr;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (kw) keepr <= kd; else if (rti_down) keepr <= 32'b0;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keepr[i]) r[i] <= 64'b0;
      else if (we && wa == i) r[i] <= wd;
  end
endmodule
// rf_flash_imm = rf_flash of h6.v (the mask is an input from the decoder; the 32 bits travel with the instruction)
// rf_stash: L levels of a hidden copy of the registers r0..r13, r15..r31 (31 of them), made at every entry from a lesser mode (enter) and put back by the return (ret_down) into every register
// whose bit in the mask is zero; the registers named in the mask keep what the kernel wrote.
module rf_stash #(parameter L=1, parameter LG=1) (input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input ret_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [63:0] s [0:L*32-1];
  reg [LG-1:0] lvl;
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) begin
    if (enter) lvl <= lvl + 1; else if (ret_down) lvl <= lvl - 1;
    for (i = 0; i < 32; i = i + 1) begin
      if (enter) s[lvl*32 + i] <= r[i];
      if (ret_down && !keep[i]) r[i] <= s[(lvl-1)*32 + i];
      else if (we && wa == i) r[i] <= wd;
    end
  end
endmodule
module rf_stash1(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input ret_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [63:0] s [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (enter) s[i] <= r[i];
    if (ret_down && !keep[i]) r[i] <= s[i];
    else if (we && wa == i) r[i] <= wd;
  end
endmodule
// the stash of only the caller-saved subset r1-r7, r12, r16-r23 (16 registers), one level
module rf_stash16(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input ret_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [63:0] s [0:31];
  wire [31:0] sub = 32'h00ff10fe;           // r1-r7, r12, r16-r23
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (enter && sub[i]) s[i] <= r[i];
    if (ret_down && !keep[i]) r[i] <= sub[i] ? s[i] : 64'b0;
    else if (we && wa == i) r[i] <= wd;
  end
endmodule
module rf_stash2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input ret_down, input [31:0] keep, output [63:0] qa, qb, qc);
  rf_stash #(2,2) x(clk, ra, rb, rc, wa, we, wd, enter, ret_down, keep, qa, qb, qc);
endmodule
module rf_stash4(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input enter, input ret_down, input [31:0] keep, output [63:0] qa, qb, qc);
  rf_stash #(4,3) x(clk, ra, rb, rc, wa, we, wd, enter, ret_down, keep, qa, qb, qc);
endmodule
