// Hole 7: the five sticky floating-point flags
module fp_base(input clk, input [4:0] set, input fswr, input [4:0] fsval, output [4:0] q);
  reg [4:0] f; assign q = f;
  always @(posedge clk) if (fswr) f <= fsval | set; else f <= f | set;
endmodule
// (b) cleared by a write to the address-space number (and, for a guest, by a write of GTBR)
module fp_asid(input clk, input [4:0] set, input fswr, input [4:0] fsval, input asid_wr, input gtbr_wr, output [4:0] q);
  reg [4:0] f; assign q = f;
  always @(posedge clk) if (asid_wr | gtbr_wr) f <= 5'b0; else if (fswr) f <= fsval | set; else f <= f | set;
endmodule
module fp_asid_only(input clk, input [4:0] set, input fswr, input [4:0] fsval, input asid_wr, output [4:0] q);
  reg [4:0] f; assign q = f;
  always @(posedge clk) if (asid_wr) f <= 5'b0; else if (fswr) f <= fsval | set; else f <= f | set;
endmodule
// (c) banked by mode: the kernel's arithmetic sets its own five flags; the user's are untouched by it
module fp_bank(input clk, input kernel, input [4:0] set, input fswr, input [4:0] fsval, output [4:0] q);
  reg [4:0] u, k; assign q = kernel ? k : u;
  always @(posedge clk) begin
    if (kernel) begin if (fswr) k <= fsval | set; else k <= k | set; end
    else begin if (fswr) u <= fsval | set; else u <= u | set; end
  end
endmodule
