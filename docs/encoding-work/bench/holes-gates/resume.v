// Blocks of the resume study (docs/encoding-work/vector-resume-design.md, appendix), written to be counted, not to be used; same method as tools/gates/blocks.v

// ---- today: the hidden copy vrun/vrst and the naming register (common/pdp64exec_vec.inc:819-821, 927-935, 1004; pdp64exec.c:364,418,435,616)
module today(input clk, input rst, input vec_start, input [63:0] start, input hidden, input blk_end, input clear_ev,
             input set_clr, input [15:0] clr_bits,
             output reg [15:0] vacc, output restore);
  reg [63:0] vrun_pc, vrst_pc; reg [15:0] vrun_acc, vrst_acc; reg vrun_valid, vrst_valid;
  assign restore = vec_start & vrst_valid & (vrst_pc == start);
  always @(posedge clk) begin
    if (rst) begin vrun_valid <= 0; vrst_valid <= 0; vacc <= 0; end
    else begin
      if (vec_start) begin
        if (vrun_valid) begin vrst_pc <= vrun_pc; vrst_acc <= vrun_acc; vrst_valid <= 1; end
        vrun_valid <= 0;
        if (vrst_valid & (vrst_pc == start)) begin vacc <= vrst_acc; vrst_valid <= 0; end
        if (hidden) begin vrun_valid <= 1; vrun_pc <= start; vrun_acc <= vacc; end
      end
      if (set_clr) vacc <= vacc | clr_bits;
      if (blk_end) begin vacc <= 0; vrun_valid <= 0; end
      if (clear_ev) vacc <= 0;
    end
  end
endmodule

// ---- the naming register alone (what option 1 keeps: a variable of the running block)
module naming(input clk, input rst, input set_clr, input [15:0] clr_bits, input blk_end, output reg [15:0] vacc);
  always @(posedge clk) if (rst | blk_end) vacc <= 0; else if (set_clr) vacc <= vacc | clr_bits;
endmodule

// ---- A: the resume record with its binding (NW = 4 entries; E compare and P write-back one entry at a time through the existing register-file ports)
module rrec(input clk, input rst,
            input susp, input [63:0] s_pc, input [34:0] s_tag, input [63:0] s_E, input [63:0] s_P, input [1:0] s_idx, input [2:0] s_n,
            input ret, input [31:0] r_tok, input [63:0] r_pc, input [34:0] c_tag,
            input chk_start, input [1:0] chk_idx, input [63:0] rd_val,
            input ev_vecuse, input ev_ctxwrite, input ev_genter_other, input ev_icinv, input ev_mcheck, input retire_other,
            input [47:0] key_in, input key_load,
            output [31:0] tok_out, output [63:0] P_out, output resume_ok, output armed_o, output valid_o);
  reg valid, armed, ok; reg [31:0] tok, cnt; reg [47:0] key; reg [63:0] pc; reg [34:0] tag; reg [2:0] n;
  reg [63:0] E0, E1, E2, E3, P0, P1, P2, P3;
  // the token: the counter through a keyed 3-round Feistel network on 16-bit halves
  wire [15:0] l0 = cnt[31:16], r0 = cnt[15:0];
  wire [15:0] f0 = (r0 + key[15:0]) ^ {r0[10:0], r0[15:11]};
  wire [15:0] l1 = r0, r1 = l0 ^ f0;
  wire [15:0] f1 = (r1 + key[31:16]) ^ {r1[10:0], r1[15:11]};
  wire [15:0] l2 = r1, r2 = l1 ^ f1;
  wire [15:0] f2 = (r2 + key[47:32]) ^ {r2[10:0], r2[15:11]};
  wire [15:0] l3 = r2, r3 = l2 ^ f2;
  wire [31:0] newtok = {l3, r3};
  assign tok_out = tok;
  wire match = valid & ret & (r_tok == tok) & (r_pc == pc) & (c_tag == tag);
  wire [63:0] Esel = chk_idx == 0 ? E0 : chk_idx == 1 ? E1 : chk_idx == 2 ? E2 : E3;
  assign P_out = chk_idx == 0 ? P0 : chk_idx == 1 ? P1 : chk_idx == 2 ? P2 : P3;
  assign resume_ok = armed & ok;
  assign armed_o = armed; assign valid_o = valid;
  wire kill = ev_vecuse | ev_ctxwrite | ev_genter_other | ev_icinv | ev_mcheck;
  always @(posedge clk) begin
    if (key_load) key <= key_in;
    if (rst | kill) begin valid <= 0; armed <= 0; end
    else begin
      if (susp) begin valid <= 1; armed <= 0; pc <= s_pc; tag <= s_tag; n <= s_n; tok <= newtok; cnt <= cnt + 1; ok <= 1;
        case (s_idx) 0: begin E0 <= s_E; P0 <= s_P; end 1: begin E1 <= s_E; P1 <= s_P; end 2: begin E2 <= s_E; P2 <= s_P; end default: begin E3 <= s_E; P3 <= s_P; end endcase end
      if (match) armed <= 1;
      else if (ret & valid) valid <= 0;   // a return that does not match leaves the record unless it presents the token (simplified: discard)
      if (retire_other) armed <= 0;
      if (chk_start) ok <= 1;
      else if (armed & (rd_val != Esel)) ok <= 0;
    end
  end
endmodule

// ---- the admission checks at vec (decode of the body, one instruction a cycle): the written-register count against NW, and a load and a store with one base register
module admit(input clk, input clear, input valid_i, input is_load, input is_store, input [4:0] base, input is_written, input [4:0] wreg,
             output inplace, output too_many);
  reg [31:0] ldset, stset, wmask; reg [2:0] cnt;
  wire [31:0] dbase = 32'd1 << base, dw = 32'd1 << wreg;
  assign inplace = |(ldset & stset);
  assign too_many = cnt > 4;
  always @(posedge clk) begin
    if (clear) begin ldset <= 0; stset <= 0; wmask <= 0; cnt <= 0; end
    else if (valid_i) begin
      if (is_load) ldset <= ldset | dbase;
      if (is_store) stset <= stset | dbase;
      if (is_written & ~wmask[wreg]) begin wmask <= wmask | dw; if (cnt != 7) cnt <= cnt + 1; end
    end
  end
endmodule

// ---- the block bound: the first stream's length against NMAX = 256 strips (unit = bytes of one element step, up to 255)
module nmax(input [63:0] rs, input [63:0] re, input [7:0] unit, output over);
  wire [63:0] d = re - rs;
  assign over = d > {48'b0, unit, 8'b0};
endmodule

// ---- B: architectural state (the OS saves it): owner tag, status, the address of the vec, the read path of 36 words, the write path into the accumulators
module bstate(input clk, input rst, input susp, input [63:0] s_pc, input [34:0] s_tag, input [34:0] c_tag, input vecuse, input sw_write, input [63:0] wd,
              input restore_clean, output trap, output reg [63:0] pc, output reg [1:0] status);
  reg [34:0] tag;
  // status: 0 off, 1 initial, 2 clean, 3 dirty
  wire foreign = vecuse & (c_tag != tag);
  assign trap = foreign & (status != 0);
  always @(posedge clk) begin
    if (rst) status <= 0;
    else begin
      if (susp) begin pc <= s_pc; tag <= s_tag; status <= 3; end
      if (sw_write) begin status <= 3; tag <= c_tag; end
      if (restore_clean) status <= 2;
    end
  end
endmodule
module bread(input [255:0] w0, input [255:0] w1, input [255:0] w2, input [255:0] w3, input [255:0] w4, input [255:0] w5, input [255:0] w6, input [255:0] w7,
             input [255:0] w8, input [63:0] pcw, input [63:0] stw, input [5:0] sel, output reg [63:0] y);
  // 32 accumulator words (8 x 256 bits here = 32 words of 64), then pc and status: 34 words
  wire [63:0] a [0:33];
  genvar i;
  generate for (i = 0; i < 4; i = i + 1) begin : g
    assign a[i] = w0[64*i +: 64]; assign a[4+i] = w1[64*i +: 64]; assign a[8+i] = w2[64*i +: 64]; assign a[12+i] = w3[64*i +: 64];
    assign a[16+i] = w4[64*i +: 64]; assign a[20+i] = w5[64*i +: 64]; assign a[24+i] = w6[64*i +: 64]; assign a[28+i] = w7[64*i +: 64];
  end endgenerate
  assign a[32] = pcw; assign a[33] = stw;
  always @* y = (sel < 34) ? a[sel] : 64'b0;
endmodule
// the write path: each of the 16 accumulator registers (128 bits: the least strip) gets a second source (the system register word) and an enable
module bwrite(input [2047:0] wd_normal, input [63:0] sw_word, input [5:0] sel, input sw_we, input [2047:0] q_old, output [2047:0] d_new);
  genvar i;
  generate for (i = 0; i < 32; i = i + 1) begin : g
    wire hit = sw_we & (sel == i);
    assign d_new[64*i +: 64] = hit ? sw_word : wd_normal[64*i +: 64];
  end endgenerate
endmodule
