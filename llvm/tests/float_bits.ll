; expect: -1073479679  -- bitcasts between i32/f32 and i64/f64, fabs/fneg on the integer view, copysign
declare float @llvm.copysign.f32(float, float)
declare double @llvm.copysign.f64(double, double)
define i32 @test() {
  %a = bitcast float 1.5 to i32
  %b = bitcast i32 -1082130432 to float
  %c = bitcast double -2.5 to i64
  %d = bitcast i64 4611686018427387904 to double
  %e = call float @llvm.copysign.f32(float 3.0, float -1.0)
  %f = call double @llvm.copysign.f64(double 5.0, double -0.0)
  %ei = bitcast float %e to i32
  %fi = bitcast double %f to i64
  %bi = fptosi float %b to i32
  %di = fptosi double %d to i32
  %t1 = add i32 %a, %ei
  %t2 = add i32 %t1, %bi
  %t3 = add i32 %t2, %di
  %c32 = trunc i64 %c to i32
  %f32 = trunc i64 %fi to i32
  %t4 = xor i32 %t3, %c32
  %t5 = xor i32 %t4, %f32
  %c2 = lshr i64 %c, 32
  %c3 = trunc i64 %c2 to i32
  %t6 = add i32 %t5, %c3
  ret i32 %t6
}
