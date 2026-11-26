// flagunit: the incremental logic a flag register costs an in-order integer core: the four flag flip-flops with their per-flag
// write enable and source mux (arithmetic: N Z V C from the adder; logic: N Z, V cleared, C kept; shift: C from the shifter), the
// 64-input zero detect on the result, and the evaluation of the 14 conditions (eq ne pl mi vc vs cc cs ge lt gt le hi los).
// The adder, the shifter and the result bus exist without flags and are not counted.
module flagunit(input clk, input [63:0] res, input cout, input cin63, input shc, input [1:0] kind /*0 arith 1 logic 2 shift 3 none*/,
                input sub, input [3:0] cond, output taken);
  reg n, z, v, c;
  wire zr = ~|res;
  wire arith = kind == 0, logic_ = kind == 1, shift = kind == 2;
  wire wn = arith | logic_ | shift, wz = wn, wv = arith | logic_ | shift, wc = arith | shift;
  wire nv = arith ? (cin63 ^ cout) : 1'b0;
  wire nc = arith ? (cout ^ sub) : shc;
  always @(posedge clk) begin
    if (wn) n <= res[63];
    if (wz) z <= zr;
    if (wv) v <= nv;
    if (wc) c <= nc;
  end
  reg t;
  always @* case (cond)
    0: t = z;            // eq
    1: t = ~z;           // ne
    2: t = ~n;           // pl
    3: t = n;            // mi
    4: t = ~v;           // vc
    5: t = v;            // vs
    6: t = ~c;           // cc
    7: t = c;            // cs
    8: t = ~(n ^ v);     // ge
    9: t = n ^ v;        // lt
    10: t = ~z & ~(n ^ v);   // gt
    11: t = z | (n ^ v);     // le
    12: t = c & ~z;      // hi
    13: t = ~c | z;      // los
    default: t = 1'b1;   // br
  endcase
  assign taken = t;
endmodule
// the comparator of a compare-and-branch (cbCC ra,rb): kept in the no-flags machine, and in the flags machine too (the pdp64 has both).
module cbcompare(input [63:0] a, input [63:0] b, input [3:0] cond, output taken);
  wire [64:0] d = {1'b0, a} - {1'b0, b};
  wire eq = ~|(a ^ b);
  wire ltu = d[64];
  wire lts = (a[63] ^ b[63]) ? a[63] : d[63];
  reg t;
  always @* case (cond)
    0: t = eq; 1: t = ~eq; 2: t = 1'b0; 3: t = 1'b0; 4: t = 1'b0; 5: t = 1'b0;
    6: t = ~ltu; 7: t = ltu; 8: t = ~lts; 9: t = lts; 10: t = ~lts & ~eq; 11: t = lts | eq; 12: t = ~ltu & ~eq; 13: t = ltu | eq;
    default: t = 1'b1;
  endcase
  assign taken = t;
endmodule
module adder64(input [63:0] a, input [63:0] b, output [64:0] s); assign s = {1'b0,a} + {1'b0,b}; endmodule
