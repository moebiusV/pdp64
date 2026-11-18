// The memory-side blocks of the vector unit for docs/encoding-work/vec-silicon.md (counted with gates2.sh): the 256-bit load alignment with the widening of the lane type, and the store
// merge.  vec-gates.md estimated these as 10,000 ("alignment rotate and store merge of 256 bits: an estimate"); here they are written.

// load: a 64-byte window of the line(s) is shifted down by `off` bytes (0 to 31) to give the 32 bytes of the strip, then each lane is widened (t: 0 none, 1 b to w, 2 b to l, 3 b to q,
// 4 w to l, 5 w to q, 6 l to q; sgn: sign-extended, otherwise zero)
module vmem_ld(input [511:0] win, input [4:0] off, input [2:0] t, input sgn, output reg [255:0] y);
  wire [511:0] sh = win >> (8 * off);
  integer i, tt, S, L, e, k;
  reg [7:0] top;
  always @* begin
    y = sh[255:0];
    for (tt = 1; tt < 7; tt = tt + 1) begin
      S = (tt <= 3) ? 1 : (tt <= 5) ? 2 : 4;
      L = (tt == 1) ? 2 : (tt == 2 || tt == 4) ? 4 : 8;
      if (t == tt)
        for (i = 0; i < 32; i = i + 1) begin
          e = i / L; k = i % L;
          if (k < S) y[8*i +: 8] = sh[8*(e * S + k) +: 8];
          else y[8*i +: 8] = sgn ? {8{sh[8*(e * S + S - 1) + 7]}} : 8'h00;
        end
    end
  end
endmodule
// the same without the widening (alignment only)
module vmem_ld_plain(input [511:0] win, input [4:0] off, output [255:0] y);
  wire [511:0] sh = win >> (8 * off); assign y = sh[255:0];
endmodule
// store: the 32 bytes of the strip placed at byte `off` of a 64-byte window, with the 64 byte-enable bits (the narrowing is in the narrow_* blocks)
module vmem_st(input [255:0] v, input [4:0] off, input [5:0] nbytes, output [511:0] data, output [63:0] be);
  assign data = {256'b0, v} << (8 * off);
  wire [63:0] ones = (64'd1 << nbytes) - 64'd1;
  assign be = ones << off;
endmodule
