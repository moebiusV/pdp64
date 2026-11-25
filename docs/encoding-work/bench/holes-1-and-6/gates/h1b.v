// Hole 1, the directory of walked table pages, written the way hardware would have to do it (the earlier model, snoopdir in h1.v, kills by guest tag, which discards every
// translation of the guest: too coarse).  Here each translation-buffer entry carries a bitmap of the directory slots whose table page it was made from, so a store to a
// table page discards exactly the entries made from that page, and a slot that has to be reused discards the entries that depended on its old page (it must: an entry
// whose page is no longer watched could go stale unseen).
//   directory: D slots of {valid, 28-bit page number}; SP store ports (the core's, and DMA's or another core's) each compare their page number with every slot.
//   walker: one table page per read; a page not in the directory takes the next slot round robin (evicting the old one); the slot is added to the bitmap `build` of the entry being made.
//   buffer: 32 entries of {valid, 16-bit guest tag, 28-bit page, 36 bits of result, D-bit dependency bitmap}.
module dirtlb #(parameter D=16, parameter LG=4, parameter SP=1) (
   input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd,
   input inv, input [15:0] inv_tag,                       // today's invalidate by tag (TLBI / TLBIA / register writes)
   input wv, input [27:0] wppn,                           // the walker read a table entry in page wppn
   input [SP-1:0] sv, input [SP*28-1:0] sppn,             // stores
   output [27:0] ppn, output [7:0] fl, output hit);
  reg [63:0] e [0:31]; reg [15:0] t [0:31]; reg [31:0] v; reg [D-1:0] dep [0:31];
  reg [27:0] dp [0:D-1]; reg [D-1:0] dv; reg [LG-1:0] rr; reg [D-1:0] build;
  integer i, j;
  // lookup
  reg [31:0] m; reg [35:0] pf;
  always @* begin
    for (i = 0; i < 32; i = i + 1) m[i] = v[i] & (e[i][63:36] == vpn) & (t[i] == tag);
    pf = 0; for (i = 0; i < 32; i = i + 1) if (m[i]) pf = pf | e[i][35:0];
  end
  assign ppn = pf[35:8]; assign fl = pf[7:0]; assign hit = |m;
  // store side: which slots does a store hit
  reg [D-1:0] sh;
  always @* begin
    sh = 0;
    for (i = 0; i < D; i = i + 1) for (j = 0; j < SP; j = j + 1) if (sv[j] && dv[i] && dp[i] == sppn[j*28 +: 28]) sh[i] = 1'b1;
  end
  // walker side: hit in the directory, or allocate
  reg [D-1:0] wh; reg wmiss; reg [D-1:0] evict;
  always @* begin
    wh = 0;
    for (i = 0; i < D; i = i + 1) if (dv[i] && dp[i] == wppn) wh[i] = 1'b1;
    wmiss = wv & ~|wh;
    evict = 0; if (wmiss && dv[rr]) evict[rr] = 1'b1;
  end
  wire [D-1:0] gone = sh | evict;                          // slots whose dependents must be discarded now
  wire [D-1:0] newslot = wmiss ? (({{(D-1){1'b0}},1'b1}) << rr) : wh;
  always @(posedge clk) begin
    for (i = 0; i < 32; i = i + 1) begin
      if (inv && v[i] && t[i] == inv_tag) v[i] <= 1'b0;
      if (|(dep[i] & gone)) v[i] <= 1'b0;                 // discard what depended on a stored-to or evicted page
      dep[i] <= dep[i] & ~gone;
    end
    if (we) begin e[wi] <= wd; t[wi] <= tag; v[wi] <= 1'b1; dep[wi] <= build | (wv ? newslot : {D{1'b0}}); end
    if (we) build <= 0; else if (wv) build <= (build & ~gone) | newslot;
    dv <= dv & ~sh;
    if (wmiss) begin dp[rr] <= wppn; dv[rr] <= 1'b1; rr <= rr + 1; end
  end
endmodule
module u_dir8_1 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input sv, input [27:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(8,3,1) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
module u_dir16_1 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input sv, input [27:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(16,4,1) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
module u_dir16_2 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(16,4,2) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
module u_dir32_2 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(32,5,2) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
module u_dir64_2 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(64,6,2) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
module u_dir8_2 (input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn, output [27:0] ppn, output [7:0] fl, output hit);
  dirtlb #(8,3,2) x(clk, vpn, tag, we, wi, wd, inv, inv_tag, wv, wppn, sv, sppn, ppn, fl, hit);
endmodule
// the arena with the walker's refusal and a flag, the whole of the proposal, for one translation buffer
module u_arena_full(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag,
   input [27:0] lo, input [27:0] hi, input wv, input [27:0] wppn, input [1:0] sv, input [55:0] sppn, input genter, input hyp_wr,
   output [27:0] ppn, output [7:0] fl, output hit, output walk_bad);
  wire ka;
  arena a(lo, hi, sv, sppn, wv, wppn, ka, walk_bad);
  reg flag; wire enter_flush = genter & flag;
  always @(posedge clk) if (enter_flush) flag <= 1'b0; else if (ka | hyp_wr) flag <= 1'b1;
  tlb32tall b(clk, vpn, tag, we, wi, wd, inv, inv_tag, enter_flush, ppn, fl, hit);
endmodule
module u_base_tag(input clk, input [27:0] vpn, input [15:0] tag, input we, input [4:0] wi, input [63:0] wd, input inv, input [15:0] inv_tag, output [27:0] ppn, output [7:0] fl, output hit);
  tlb32t #(16) b(clk, vpn, tag, we, wi, wd, inv, inv_tag, ppn, fl, hit);
endmodule
