; expect: 41464  -- floating-point comparisons: every predicate, with ordered and unordered (NaN) operands; the result is a bit string
define i32 @bits(double %a, double %b) {
  %c0 = fcmp oeq double %a, %b
  %c1 = fcmp one double %a, %b
  %c2 = fcmp ogt double %a, %b
  %c3 = fcmp oge double %a, %b
  %c4 = fcmp olt double %a, %b
  %c5 = fcmp ole double %a, %b
  %c6 = fcmp ueq double %a, %b
  %c7 = fcmp une double %a, %b
  %c8 = fcmp ugt double %a, %b
  %c9 = fcmp uge double %a, %b
  %c10 = fcmp ult double %a, %b
  %c11 = fcmp ule double %a, %b
  %c12 = fcmp ord double %a, %b
  %c13 = fcmp uno double %a, %b
  %z0 = zext i1 %c0 to i32
  %z1 = zext i1 %c1 to i32
  %z2 = zext i1 %c2 to i32
  %z3 = zext i1 %c3 to i32
  %z4 = zext i1 %c4 to i32
  %z5 = zext i1 %c5 to i32
  %z6 = zext i1 %c6 to i32
  %z7 = zext i1 %c7 to i32
  %z8 = zext i1 %c8 to i32
  %z9 = zext i1 %c9 to i32
  %z10 = zext i1 %c10 to i32
  %z11 = zext i1 %c11 to i32
  %z12 = zext i1 %c12 to i32
  %z13 = zext i1 %c13 to i32
  %s1 = shl i32 %z1, 1
  %s2 = shl i32 %z2, 2
  %s3 = shl i32 %z3, 3
  %s4 = shl i32 %z4, 4
  %s5 = shl i32 %z5, 5
  %s6 = shl i32 %z6, 6
  %s7 = shl i32 %z7, 7
  %s8 = shl i32 %z8, 8
  %s9 = shl i32 %z9, 9
  %s10 = shl i32 %z10, 10
  %s11 = shl i32 %z11, 11
  %s12 = shl i32 %z12, 12
  %s13 = shl i32 %z13, 13
  %o1 = or i32 %z0, %s1
  %o2 = or i32 %o1, %s2
  %o3 = or i32 %o2, %s3
  %o4 = or i32 %o3, %s4
  %o5 = or i32 %o4, %s5
  %o6 = or i32 %o5, %s6
  %o7 = or i32 %o6, %s7
  %o8 = or i32 %o7, %s8
  %o9 = or i32 %o8, %s9
  %o10 = or i32 %o9, %s10
  %o11 = or i32 %o10, %s11
  %o12 = or i32 %o11, %s12
  %o13 = or i32 %o12, %s13
  ret i32 %o13
}
define i32 @test() {
  %nan = fdiv double 0.0, 0.0
  %a = call i32 @bits(double 1.0, double 2.0)
  %b = call i32 @bits(double 2.0, double 2.0)
  %c = call i32 @bits(double 3.0, double 2.0)
  %d = call i32 @bits(double %nan, double 2.0)
  %e = call i32 @bits(double 2.0, double %nan)
  %f = call i32 @bits(double -0.0, double 0.0)
  %s1 = xor i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = xor i32 %s2, %d
  %s4 = add i32 %s3, %e
  %s5 = xor i32 %s4, %f
  %m1 = mul i32 %a, 3
  %m2 = mul i32 %c, 7
  %m3 = add i32 %m1, %m2
  %m4 = xor i32 %m3, %s5
  ret i32 %m4
}
