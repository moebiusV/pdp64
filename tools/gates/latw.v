// Wrapper modules for the depth measurement of docs/encoding-work/vec-latency.md (read after vecw.v; SNB as there).  Blocks that are already clean single-class modules
// (vecw.v, vec3.v, core.v, fp2.v) are measured as they are; these two chain two classes, to show what fusing them would cost in depth.
// lat_cmpsel: a compare followed by the select it feeds (vceq / vcgt then vbsl; w_vcmp2, the comparators without the dynamic shift, because vcmp_mw maps to 90,000 LUT6 in the xc7 flow): the depth if the two were one instruction.
module lat_cmpsel(input [`SW-1:0] a, input [`SW-1:0] b, input [`SW-1:0] x, input [`SW-1:0] z, input [1:0] sz, input [1:0] op, output [`SW-1:0] y);
  wire [`SW-1:0] m; w_vcmp2 c(a, b, sz, op, m); w_vbsl s(m, x, z, y);
endmodule
// lat_alushift: the lane ALU followed by the shift with rounding (an add then a shift: the shape of a halving or a fixed-point scale), as one instruction.
module lat_alushift(input [`SW-1:0] a, input [`SW-1:0] b, input [1:0] sz, input [4:0] op, input [5:0] n, input [1:0] sop, output [`SW-1:0] y);
  wire [`SW-1:0] t; w_lanealu_mw u(a, b, sz, op, t); w_shiftround_mw s(t, n, sz, sop, y);
endmodule
