// Hole 6: the register file of 32 x 64 bits, 3 read ports, 1 write port, and the ways to keep the kernel's values from the user.
module rf_base(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  always @(posedge clk) if (we) r[wa] <= wd;
endmodule
module rf_flash(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1)
    if (rti_down && !keep[i]) r[i] <= 64'b0;
    else if (we && wa == i) r[i] <= wd;
endmodule
module rf_lazy(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] z;
  assign qa = z[ra] ? 64'b0 : r[ra];
  assign qb = z[rb] ? 64'b0 : r[rb];
  assign qc = z[rc] ? 64'b0 : r[rc];
  integer i;
  always @(posedge clk) begin
    if (we) r[wa] <= wd;
    for (i = 0; i < 32; i = i + 1)
      if (rti_down && !keep[i]) z[i] <= 1'b1;
      else if (we && wa == i) z[i] <= 1'b0;
  end
endmodule
module rf_taint(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input user, input uw, input ent, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] t;
  assign qa = (user & t[ra]) ? 64'b0 : r[ra];
  assign qb = (user & t[rb]) ? 64'b0 : r[rb];
  assign qc = (user & t[rc]) ? 64'b0 : r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (ent && t[i]) begin r[i] <= 64'b0; t[i] <= 1'b0; end
    else if (we && wa == i) begin r[i] <= wd; t[i] <= ~user & ~uw; end
  end
endmodule
module rf_bank(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input kernel, input xwe, input [4:0] xa, input [63:0] xwd, output [63:0] qa, qb, qc, output [63:0] xq);
  reg [63:0] u [0:31];
  reg [63:0] k [0:31];
  assign qa = kernel ? k[ra] : u[ra];
  assign qb = kernel ? k[rb] : u[rb];
  assign qc = kernel ? k[rc] : u[rc];
  assign xq = kernel ? u[xa] : k[xa];
  always @(posedge clk) begin
    if (we) begin if (kernel) k[wa] <= wd; else u[wa] <= wd; end
    if (xwe) begin if (kernel) u[xa] <= xwd; else k[xa] <= xwd; end
  end
endmodule
module rf_base2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  assign qa = r[ra]; assign qb = r[rb]; assign qc = r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) if (we && wa == i) r[i] <= wd;
endmodule
module rf_lazy2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input rti_down, input [31:0] keep, output [63:0] qa, qb, qc);
  reg [63:0] r [0:31];
  reg [31:0] z;
  assign qa = z[ra] ? 64'b0 : r[ra];
  assign qb = z[rb] ? 64'b0 : r[rb];
  assign qc = z[rc] ? 64'b0 : r[rc];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (we && wa == i) r[i] <= wd;
    if (rti_down && !keep[i]) z[i] <= 1'b1;
    else if (we && wa == i) z[i] <= 1'b0;
  end
endmodule
module rf_bank2(input clk, input [4:0] ra, rb, rc, wa, input we, input [63:0] wd, input kernel, input xwe, input [4:0] xa, input [63:0] xwd, output [63:0] qa, qb, qc, output [63:0] xq);
  reg [63:0] u [0:31];
  reg [63:0] k [0:31];
  assign qa = kernel ? k[ra] : u[ra];
  assign qb = kernel ? k[rb] : u[rb];
  assign qc = kernel ? k[rc] : u[rc];
  assign xq = kernel ? u[xa] : k[xa];
  integer i;
  always @(posedge clk) for (i = 0; i < 32; i = i + 1) begin
    if (kernel ? (we && wa == i) : (xwe && xa == i)) k[i] <= kernel ? wd : xwd;
    if (kernel ? (xwe && xa == i) : (we && wa == i)) u[i] <= kernel ? xwd : wd;
  end
endmodule
