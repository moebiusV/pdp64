// the repository's tlb32 (tools/gates/core.v), reproduced for a check
module tlb32(input clk, input [27:0] vpn, input we, input [4:0] wi, input [63:0] wd, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31];
  reg [31:0] m;
  integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = (e[i][63:36] == vpn);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) if (we) e[wi] <= wd;
endmodule
// the same with a valid bit and one 16-bit tag in each entry, a hit needing the tag, and an invalidate by tag (the accepted design's guest tag)
module tlb32_t16(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] itag, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31]; reg [15:0] t [0:31]; reg [31:0] v;
  reg [31:0] m; integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = v[i] & (e[i][63:36] == vpn) & (t[i] == tag);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) begin
    if (we) begin e[wi] <= wd; t[wi] <= tag; v[wi] <= 1'b1; end
    if (inv) for (i = 0; i < 32; i = i + 1) if (t[i] == itag) v[i] <= 1'b0;
  end
endmodule
// the same with two 16-bit tags (level-1 guest, level-2 guest): a hit needs both; an invalidate names the level-2 tag, or the level-1 tag alone (mask)
module tlb32_t32(input clk, input [27:0] vpn, input [15:0] tag1, input [15:0] tag2, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] itag1, input [15:0] itag2, input all2, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31]; reg [15:0] t1 [0:31]; reg [15:0] t2 [0:31]; reg [31:0] v;
  reg [31:0] m; integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = v[i] & (e[i][63:36] == vpn) & (t1[i] == tag1) & (t2[i] == tag2);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) begin
    if (we) begin e[wi] <= wd; t1[wi] <= tag1; t2[wi] <= tag2; v[wi] <= 1'b1; end
    if (inv) for (i = 0; i < 32; i = i + 1) if (t1[i] == itag1 && (all2 || t2[i] == itag2)) v[i] <= 1'b0;
  end
endmodule
// NEVE-like redirection of hypervisor-register moves to a page: the decision and the address
module nv_redirect(input [7:0] n, input wr, input h, input hve, input en, input [27:0] base,
                   output hvreg, output redirect, output exit18, output [39:0] addr);
  wire inblk = (n >= 8'd128) && (n <= 8'd147);
  wire ro = (n == 8'd129) || (n == 8'd132) || (n == 8'd133) || (n == 8'd134) || (n == 8'd135);
  assign hvreg = inblk;
  assign redirect = hve & ~h & inblk & en & ~(wr & ro);
  assign exit18 = hve & ~h & inblk & ~redirect;
  assign addr = {base, 1'b0, n, 3'b000};
endmodule
// the accepted design's decision alone (no redirection): an exit when a guest uses a hypervisor register
module hv_exit_only(input [7:0] n, input h, input hve, output hvreg, output exit18);
  wire inblk = (n >= 8'd128) && (n <= 8'd147);
  assign hvreg = inblk; assign exit18 = hve & ~h & inblk;
endmodule
// a "virtual hypervisor" bit: while set, the instructions of the hypervisor that mean something else at H = 1 exit
module vh_trap(input vh, input h, input is_rti, input is_rtt, input is_pushx, input is_popx, input is_mfsr_mmuctl, input exc_entry, output exitvh, output [2:0] why);
  assign exitvh = vh & ~h & (is_rti | is_rtt | is_pushx | is_popx | is_mfsr_mmuctl | exc_entry);
  assign why = exc_entry ? 3'd1 : (is_mfsr_mmuctl ? 3'd2 : 3'd3);
endmodule
