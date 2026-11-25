// Hole 1: the 32-entry translation buffer with a guest tag, and the ways to discard a guest's entries.
// tlb32: the repository's reference buffer (tools/gates/core.v), no tag.
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

// tlb32t: valid bit, a tag of TW bits in each entry, match on tag, invalidate of every entry whose tag equals inv_tag
module tlb32t #(parameter TW=16) (input clk, input [27:0] vpn, input [TW-1:0] tag, input we, input [4:0] wi, input [63:0] wd,
   input inv, input [TW-1:0] inv_tag, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31];
  reg [TW-1:0] t [0:31];
  reg [31:0] v;
  reg [31:0] m;
  integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = v[i] & (e[i][63:36] == vpn) & (t[i] == tag);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) begin
    for (i = 0; i < 32; i = i + 1) if (inv && v[i] && t[i] == inv_tag) v[i] <= 1'b0;
    if (we) begin e[wi] <= wd; t[wi] <= tag; v[wi] <= 1'b1; end
  end
endmodule

// the control that today drives the invalidate: TLBIA and the writes of PTBR/ASID/MMUCTL discard the tag in use; a write of GTBR that changes the root or the enable discards the tag written (rule G-c)
module ctl_base(input tlbia_or_wr, input gtbr_wr, input [28:0] gtbr_old_rooten, input [28:0] gtbr_new_rooten, input [15:0] cur_tag, input [15:0] new_tag,
   output inv, output [15:0] inv_tag);
  wire gc = gtbr_wr & (gtbr_old_rooten != gtbr_new_rooten);
  assign inv = tlbia_or_wr | gc;
  assign inv_tag = gc ? new_tag : cur_tag;
endmodule
// (d) the flush flag of GTBR: a write with the flag set discards the tag written whether or not the root changed
module ctl_d(input tlbia_or_wr, input gtbr_wr, input gtbr_flag, input [28:0] gtbr_old_rooten, input [28:0] gtbr_new_rooten, input [15:0] cur_tag, input [15:0] new_tag,
   output inv, output [15:0] inv_tag);
  wire gc = gtbr_wr & ((gtbr_old_rooten != gtbr_new_rooten) | gtbr_flag);
  assign inv = tlbia_or_wr | gc;
  assign inv_tag = gc ? new_tag : cur_tag;
endmodule
// (a) every GENTER discards the tag about to run (it is the tag in GTBR, which is cur_tag when H = 0 and is read at the GENTER)
module ctl_a(input tlbia_or_wr, input gtbr_wr, input genter, input [28:0] gtbr_old_rooten, input [28:0] gtbr_new_rooten, input [15:0] cur_tag, input [15:0] new_tag,
   output inv, output [15:0] inv_tag);
  wire gc = gtbr_wr & (gtbr_old_rooten != gtbr_new_rooten);
  assign inv = tlbia_or_wr | gc | genter;
  assign inv_tag = gc ? new_tag : cur_tag;
endmodule

// the three whole units
module u_base(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire inv; wire [15:0] it;
  ctl_base c(tlbia_or_wr, gtbr_wr, go, gn, tag, new_tag, inv, it);
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
module u_a(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input genter, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire inv; wire [15:0] it;
  ctl_a c(tlbia_or_wr, gtbr_wr, genter, go, gn, tag, new_tag, inv, it);
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
module u_d(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input flag, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire inv; wire [15:0] it;
  ctl_d c(tlbia_or_wr, gtbr_wr, flag, go, gn, tag, new_tag, inv, it);
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
// (b) a generation of 8 bits in the tag (software writes it; the control is the base's): the buffer's tag is 24 bits
module u_b(input clk, input [27:0] vpn, input [23:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input [28:0] go, input [28:0] gn, input [23:0] new_tag,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire gc = gtbr_wr & (go != gn);
  wire inv = tlbia_or_wr | gc;
  wire [23:0] it = gc ? new_tag : tag;
  tlb32t #(24) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
// (b2) the generation is a counter of the hardware: it counts up at every GENTER of a guest whose entry flag... [see text]; here the hardware counter alone (8 bits, increments on a request) and the tag is 24 bits
module u_b2(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input bump, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   output [27:0] ppn, output [7:0] fl, output hit);
  reg [7:0] gen; always @(posedge clk) if (bump) gen <= gen + 1;
  wire gc = gtbr_wr & (go != gn);
  wire inv = tlbia_or_wr | gc;
  wire [23:0] it = {gc ? new_tag : tag, gen};
  tlb32t #(24) b(clk, vpn, {tag, gen}, we, wi, wd, inv, it, ppn, fl, hit);
endmodule

// (c1) a directory of D table pages that the walker has read (28-bit page number, a valid bit, the tag of the walk); a store (the core's, and DMA's) whose page matches an entry discards the tag of that entry; more
// than one match discards every tag; a walk of a page not in the directory takes an entry round robin and discards the tag of the entry it replaces
module snoopdir #(parameter D=16, parameter LG=4, parameter SP=2) (input clk, input wv, input [27:0] wppn, input [15:0] wtag, input [SP-1:0] sv, input [SP*28-1:0] sppn,
   output reg kill, output reg [15:0] kill_tag, output reg kill_all);
  reg [27:0] p [0:D-1]; reg [15:0] t [0:D-1]; reg [D-1:0] v; reg [LG-1:0] rr;
  reg [D-1:0] wh; reg [D-1:0] sh; integer i, j;
  reg [LG:0] cnt; reg [15:0] ft;
  reg wmiss; reg [15:0] evt; reg evv;
  always @* begin
    sh = 0;
    for (i = 0; i < D; i = i + 1) for (j = 0; j < SP; j = j + 1) if (sv[j] && v[i] && p[i] == sppn[j*28 +: 28]) sh[i] = 1'b1;
    wh = 0;
    for (i = 0; i < D; i = i + 1) if (v[i] && p[i] == wppn && t[i] == wtag) wh[i] = 1'b1;
    wmiss = wv & ~|wh;
    cnt = 0; ft = 0;
    for (i = 0; i < D; i = i + 1) begin cnt = cnt + sh[i]; if (sh[i]) ft = ft | t[i]; end
    evv = wmiss & v[rr]; evt = t[rr];
    kill_all = (cnt > 1);
    kill = (cnt != 0) | evv;
    kill_tag = (cnt != 0) ? ft : evt;
  end
  always @(posedge clk) begin
    if (wmiss) begin p[rr] <= wppn; t[rr] <= wtag; v[rr] <= 1'b1; rr <= rr + 1; end
    for (i = 0; i < D; i = i + 1) if (sh[i]) v[i] <= 1'b0;
  end
endmodule
module u_c1_16(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire inv0; wire [15:0] it0; wire k, ka; wire [15:0] kt;
  ctl_base c(tlbia_or_wr, gtbr_wr, go, gn, tag, new_tag, inv0, it0);
  snoopdir #(16,4,2) d(clk, wv, wppn, tag, sv, sppn, k, kt, ka);
  wire inv = inv0 | k;
  wire [15:0] it = k ? kt : it0;
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
module u_c1_32(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn,
   output [27:0] ppn, output [7:0] fl, output hit);
  wire inv0; wire [15:0] it0; wire k, ka; wire [15:0] kt;
  ctl_base c(tlbia_or_wr, gtbr_wr, go, gn, tag, new_tag, inv0, it0);
  snoopdir #(32,5,2) d(clk, wv, wppn, tag, sv, sppn, k, kt, ka);
  wire inv = inv0 | k;
  wire [15:0] it = k ? kt : it0;
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, it, ppn, fl, hit);
endmodule
// (c3) the arena: the stage-2 tables must lie in one physical range [lo, hi) (two 28-bit page registers); a store of the core or of DMA into the range discards every guest tag; the walker refuses a table outside
module arena(input [27:0] lo, input [27:0] hi, input [1:0] sv, input [55:0] sppn, input wv, input [27:0] wppn, output kill_all, output walk_bad);
  wire [1:0] h;
  assign h[0] = sv[0] & (sppn[27:0] >= lo) & (sppn[27:0] < hi);
  assign h[1] = sv[1] & (sppn[55:28] >= lo) & (sppn[55:28] < hi);
  assign kill_all = |h;
  assign walk_bad = wv & ~((wppn >= lo) & (wppn < hi));
endmodule
module u_c3(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input tlbia_or_wr, input gtbr_wr, input [28:0] go, input [28:0] gn, input [15:0] new_tag,
   input [27:0] lo, input [27:0] hi, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn,
   output [27:0] ppn, output [7:0] fl, output hit, output walk_bad);
  wire inv0; wire [15:0] it0; wire ka;
  ctl_base c(tlbia_or_wr, gtbr_wr, go, gn, tag, new_tag, inv0, it0);
  arena a(lo, hi, sv, sppn, wv, wppn, ka, walk_bad);
  // discarding every tag: the buffer needs a clear-all input: modelled as an invalidate of the entry's own tag, i.e. the base buffer with a second input
  tlb32tall b(clk, vpn, tag, we, wi, wd, inv0, it0, ka, ppn, fl, hit);
endmodule
module tlb32tall #(parameter TW=16) (input clk, input [27:0] vpn, input [TW-1:0] tag, input we, input [4:0] wi, input [63:0] wd,
   input inv, input [TW-1:0] inv_tag, input inv_all, output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31];
  reg [TW-1:0] t [0:31];
  reg [31:0] v;
  reg [31:0] m;
  integer i;
  always @* for (i = 0; i < 32; i = i + 1) m[i] = v[i] & (e[i][63:36] == vpn) & (t[i] == tag);
  reg [35:0] pf;
  always @* begin pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0]; end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  always @(posedge clk) begin
    for (i = 0; i < 32; i = i + 1) if (inv_all || (inv && v[i] && t[i] == inv_tag)) v[i] <= 1'b0;
    if (we) begin e[wi] <= wd; t[wi] <= tag; v[wi] <= 1'b1; end
  end
endmodule
module d16s1(input clk, input wv, input [27:0] wppn, input [15:0] wtag, input sv, input [27:0] sppn, output kill, output [15:0] kill_tag, output kill_all);
  snoopdir #(16,4,1) d(clk, wv, wppn, wtag, sv, sppn, kill, kill_tag, kill_all);
endmodule
module d8s1(input clk, input wv, input [27:0] wppn, input [15:0] wtag, input sv, input [27:0] sppn, output kill, output [15:0] kill_tag, output kill_all);
  snoopdir #(8,3,1) d(clk, wv, wppn, wtag, sv, sppn, kill, kill_tag, kill_all);
endmodule
