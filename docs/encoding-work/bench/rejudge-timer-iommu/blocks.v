// Blocks for the re-judging of the timer, interrupt and atomics decisions; counted by count.sh (the method of tools/gates/gates.sh).
// 1. take the highest eligible pending interrupt: level derived from the vector (vector/32) against a level stored for each vector
module irq_derived(input [223:0] pend, input [2:0] pri, output any, output [7:0] vec);
  // vectors 32..255 are bit 0..223; level of bit i is (i+32)/32 = i/32+1
  wire [223:0] elig;
  genvar i;
  generate for (i=0;i<224;i=i+1) begin: g
    assign elig[i] = pend[i] & ((i/32+1) > pri);
  end endgenerate
  reg [7:0] v; reg a; integer k;
  always @* begin a=0; v=0; for (k=0;k<224;k=k+1) if (elig[k]) begin a=1; v=k+32; end end
  assign any=a; assign vec=v;
endmodule
module irq_stored(input [223:0] pend, input [671:0] lvl, input [2:0] pri, output any, output [7:0] vec);
  wire [223:0] elig;
  genvar i;
  generate for (i=0;i<224;i=i+1) begin: g
    assign elig[i] = pend[i] & (lvl[3*i+:3] > pri);
  end endgenerate
  reg [2:0] L; integer k;
  always @* begin L=0; for (k=0;k<224;k=k+1) if (elig[k] && lvl[3*k+:3] > L) L=lvl[3*k+:3]; end
  reg [7:0] v; reg a;
  always @* begin a=0; v=0; for (k=0;k<224;k=k+1) if (elig[k] && lvl[3*k+:3]==L) begin a=1; v=k+32; end end
  assign any=a; assign vec=v;
endmodule
// 2. atomics: address path
module addr_reg(input [63:0] a, output [63:0] y); assign y=a; endmodule
module addr_off(input [63:0] a, input [3:0] off, output [63:0] y); assign y=a+({60'b0,off}<<3); endmodule
module align8(input [63:0] a, output fault); assign fault = |a[2:0]; endmodule
module align48(input [63:0] a, input sz8, output fault); assign fault = sz8 ? |a[2:0] : |a[1:0]; endmodule
// 3. timer shapes (logic of the compare; registers are counted as flip-flops)
module t_abs(input [63:0] cnt, input [63:0] cmp, output irq); assign irq = (cnt >= cmp) & ~(&cmp); endmodule
module t_enable(input [63:0] cnt, input [63:0] cmp, input en, output irq); assign irq = (cnt >= cmp) & en; endmodule
module t_rel(input [63:0] cnt, input [31:0] tval, input [63:0] cmp, output irq, output [63:0] nxt);
  assign nxt = cnt + {32'b0,tval}; assign irq = (cnt >= cmp); endmodule
// 4. CAS operand layouts: the register file read ports are the same (three reads, one write); the only difference is the decode of the register-field roles
module casA(input [4:0] rd, rs, ra, output [4:0] r0, r1, r2, w); assign r0=rd; assign r1=rs; assign r2=ra; assign w=rd; endmodule
module casB(input [4:0] re, rn, ra, rd, output [4:0] r0, r1, r2, w); assign r0=re; assign r1=rn; assign r2=ra; assign w=rd; endmodule
// 5. LL/SC reservation compare: the store address against the reserved address, for three sizes of the marked piece (8 bytes fixed, 128 bytes fixed, 8 to 128 bytes reported: a granule field of 3 bits)
module resv8(input [63:0] a, input [63:0] r, output hit); assign hit = (a[63:3] == r[63:3]); endmodule
module resv128(input [63:0] a, input [63:0] r, output hit); assign hit = (a[63:7] == r[63:7]); endmodule
module resvvar(input [63:0] a, input [63:0] r, input [2:0] g, output hit);
  wire [63:0] x = a ^ r;
  reg [63:0] mask; always @* mask = ~((64'h8 << g) - 64'h1);   // g=0: 8 bytes ... g=4: 128 bytes
  assign hit = ~|(x & mask); endmodule
// 6. the number of requests accepted and not completed in the IOMMU (promise of a point in time): 16-bit up-down counter with a zero test
module inflight(input clk, input rst, input acc, input done, output zero);
  reg [15:0] n; always @(posedge clk) if (rst) n<=0; else n <= n + {15'b0,acc} - {15'b0,done};
  assign zero = (n==0); endmodule
// 7. the IOMMU's cache of interrupt-table entries: 4 entries, tag = 16-bit device + 11-bit index, data 40 bits (valid, core, vector); lookup logic only
module itcache4(input [26:0] tag, input [107:0] tags, input [3:0] valid, input [159:0] data, output hit, output [39:0] d);
  wire [3:0] m;
  genvar i; generate for (i=0;i<4;i=i+1) begin: g assign m[i] = valid[i] & (tags[27*i+:27]==tag); end endgenerate
  assign hit = |m;
  assign d = ({40{m[0]}} & data[39:0]) | ({40{m[1]}} & data[79:40]) | ({40{m[2]}} & data[119:80]) | ({40{m[3]}} & data[159:120]);
endmodule
// 8. the timer: the user-clock rounding by a kernel-set granule (6 bits), and the guest comparator's difference (subtract)
module tround(input [63:0] t, input [5:0] g, output [63:0] y); assign y = t & ~((64'h1 << g) - 64'h1); endmodule
module tsub(input [63:0] t, input [63:0] off, output [63:0] y); assign y = t - off; endmodule
// 9. one interrupt-file lookup for a core: highest pending and enabled vector above the priority (level derived) with its enable bits
module irq_file(input [223:0] pend, input [223:0] en, input [2:0] pri, output any, output [7:0] vec);
  wire [223:0] p = pend & en; irq_derived d(.pend(p), .pri(pri), .any(any), .vec(vec)); endmodule
// 10. the deadline when zero means "never" (and a deadline of zero is never wanted: the counter is past it from the first tick)
module t_zero(input [63:0] cnt, input [63:0] cmp, output irq); assign irq = (cnt >= cmp) & (|cmp); endmodule
