// The shared multiplier array of the revised vector family (docs/encoding-work/vec-silicon.md), and the sliding window with its products supplied from outside (counted with gates2.sh).

// 16 lanes of 16 x 16 as one multiplier each (monolithic), shared by the modes enabled by the parameters.  m: 0 vmul lo, 1 vmulh, 2 vmulhu, 3 vmulhr (Q15, rounding, saturating),
// 4 vmla (lo + c, vector by vector), 5 vdot.w (8 lanes of two products and a 32-bit accumulator c).  HI = 0 leaves out modes 1 to 3, MLA = 0 mode 4, DOT = 0 mode 5.
module ms16_core #(parameter HI = 1, parameter MLA = 1, parameter DOT = 1) (input [255:0] a, input [255:0] b, input [255:0] c, input [2:0] m, output reg [255:0] y);
  integer i; reg signed [33:0] p [0:15]; reg signed [33:0] r; reg signed [16:0] xa, xb; reg signed [31:0] d;
  always @* begin
    y = 0;
    for (i = 0; i < 16; i = i + 1) begin
      xa = (HI != 0 && m == 2) ? {1'b0, a[16*i +: 16]} : {a[16*i + 15], a[16*i +: 16]};
      xb = (HI != 0 && m == 2) ? {1'b0, b[16*i +: 16]} : {b[16*i + 15], b[16*i +: 16]};
      p[i] = xa * xb;
    end
    for (i = 0; i < 16; i = i + 1) begin
      r = (p[i] + 34'sd16384) >>> 15;
      case (m)
        1, 2: if (HI != 0) y[16*i +: 16] = p[i][31:16];
        3: if (HI != 0) y[16*i +: 16] = (r > 32767) ? 16'h7fff : r[15:0];
        4: if (MLA != 0) y[16*i +: 16] = p[i][15:0] + c[16*i +: 16];
        5: if (DOT != 0 && i % 2 == 0) begin d = c[16*i +: 32] + p[i][31:0] + p[i + 1][31:0]; y[16*i +: 32] = d; end
        default: y[16*i +: 16] = p[i][15:0];
      endcase
    end
  end
endmodule
module ms16_lo(input [255:0] a, input [255:0] b, input [255:0] c, input [2:0] m, output [255:0] y); ms16_core #(0, 0, 0) u(a, b, c, m, y); endmodule		// = vmul16_lo
module ms16_hi(input [255:0] a, input [255:0] b, input [255:0] c, input [2:0] m, output [255:0] y); ms16_core #(1, 0, 0) u(a, b, c, m, y); endmodule		// + vmulh, vmulhu, vmulhr
module ms16_hi_mla(input [255:0] a, input [255:0] b, input [255:0] c, input [2:0] m, output [255:0] y); ms16_core #(1, 1, 0) u(a, b, c, m, y); endmodule	// + vmla
module ms16_all(input [255:0] a, input [255:0] b, input [255:0] c, input [2:0] m, output [255:0] y); ms16_core #(1, 1, 1) u(a, b, c, m, y); endmodule	// + vdot.w
module vmul16_full(input [255:0] a, input [255:0] b, output [511:0] y);			// the widening product, the form that vec-gates.md counted as the 16-bit multipliers
  genvar i; generate for (i = 0; i < 16; i = i + 1) begin: g
    wire signed [31:0] p = $signed(a[16*i +: 16]) * $signed(b[16*i +: 16]);
    assign y[32*i +: 32] = p;
  end endgenerate
endmodule

// the array built of four 8 x 8 products a lane (9 x 9 signed, so that each can be signed or unsigned), shared by all the modes of ms16_core and by vdot.b, .bu, .bsu:
// m: 0 lo, 1 hs, 2 hu, 3 hr, 4 vmla, 5 vdot.w, 6 vdot.b (sa, sb: the byte operands are signed), and the output r: the 8 lanes of y summed into the scalar accumulate (vdacc: c = 0)
module ms8x8(input [255:0] a, input [255:0] b, input [255:0] c, input [3:0] m, input sa, input sb, input [63:0] sacc, output reg [255:0] y, output reg [63:0] r);
  integer i;
  reg sah, sal, sbh, sbl;
  reg signed [17:0] hh [0:15]; reg signed [17:0] hl [0:15]; reg signed [17:0] lh [0:15]; reg signed [17:0] ll [0:15];
  reg signed [33:0] full [0:15]; reg signed [33:0] rr; reg signed [31:0] d;
  reg signed [63:0] s;
  always @* begin
    y = 0; r = 0;
    sah = (m == 6) ? sa : (m != 2); sal = (m == 6) ? sa : 1'b0;
    sbh = (m == 6) ? sb : (m != 2); sbl = (m == 6) ? sb : 1'b0;
    for (i = 0; i < 16; i = i + 1) begin
      hh[i] = $signed({sah & a[16*i + 15], a[16*i + 8 +: 8]}) * $signed({sbh & b[16*i + 15], b[16*i + 8 +: 8]});
      hl[i] = $signed({sah & a[16*i + 15], a[16*i + 8 +: 8]}) * $signed({sbl & b[16*i + 7], b[16*i +: 8]});
      lh[i] = $signed({sal & a[16*i + 7], a[16*i +: 8]}) * $signed({sbh & b[16*i + 15], b[16*i + 8 +: 8]});
      ll[i] = $signed({sal & a[16*i + 7], a[16*i +: 8]}) * $signed({sbl & b[16*i + 7], b[16*i +: 8]});
      full[i] = (hh[i] <<< 16) + ((hl[i] + lh[i]) <<< 8) + ll[i];
    end
    for (i = 0; i < 16; i = i + 1) begin
      rr = (full[i] + 34'sd16384) >>> 15;
      case (m)
        0: y[16*i +: 16] = full[i][15:0];
        1, 2: y[16*i +: 16] = full[i][31:16];
        3: y[16*i +: 16] = (rr > 32767) ? 16'h7fff : rr[15:0];
        4: y[16*i +: 16] = full[i][15:0] + c[16*i +: 16];
        5: if (i % 2 == 0) begin d = c[16*i +: 32] + full[i][31:0] + full[i + 1][31:0]; y[16*i +: 32] = d; end
        default: if (i % 2 == 0) begin d = $signed(c[16*i +: 32]) + hh[i] + ll[i] + hh[i + 1] + ll[i + 1]; y[16*i +: 32] = d; end
      endcase
    end
    s = sacc;
    for (i = 0; i < 8; i = i + 1) s = s + $signed(y[32*i +: 32]);
    r = s;
  end
endmodule
// the same without the reduction tree (r left out): the difference of the two is the vdacc tree
module ms8x8_notree(input [255:0] a, input [255:0] b, input [255:0] c, input [3:0] m, input sa, input sb, output [255:0] y);
  wire [63:0] r; ms8x8 u(a, b, c, m, sa, sb, 64'd0, y, r); endmodule

// the sliding window with the products supplied (from the shared multipliers): the window select, the tap select, the accumulators (32 bits a lane, 16 lanes = 512 flops)
module vfir_added(input clk, input [255:0] s, input [111:0] halo, input [127:0] taps, input [2:0] k, input first, input [511:0] prod,
                  output [255:0] xo, output [15:0] tapo, output [511:0] accq);
  reg [511:0] acc; wire [367:0] win = {s, halo};
  integer i; reg [511:0] nx; reg [255:0] x;
  always @* begin
    for (i = 0; i < 16; i = i + 1) x[16*i +: 16] = win[16*(i + 7 - k) +: 16];
    for (i = 0; i < 16; i = i + 1) nx[32*i +: 32] = (first ? 32'd0 : acc[32*i +: 32]) + prod[32*i +: 32];
  end
  always @(posedge clk) acc <= nx;
  assign xo = x; assign tapo = taps[16*k +: 16]; assign accq = acc;
endmodule

// one 32 x 32 signed multiplier (the lane of a vmulh.l or vmul.l with a full product, not in the proposal), for scale
module mul32s(input signed [31:0] a, input signed [31:0] b, output signed [63:0] y); assign y = a * b; endmodule
