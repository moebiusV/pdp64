; expect: -769802940  -- calls with nine arguments (six in registers, three on the stack), mixed widths, and a double
define i64 @f(i64 %a, i32 %b, i16 %c, i8 %d, i64 %e, i32 %f, i64 %g, i32 %h, i64 %i) {
  %b64 = sext i32 %b to i64
  %c64 = sext i16 %c to i64
  %d64 = sext i8 %d to i64
  %f64 = sext i32 %f to i64
  %h64 = sext i32 %h to i64
  %t1 = mul i64 %a, 1
  %t2 = mul i64 %b64, 2
  %t3 = mul i64 %c64, 3
  %t4 = mul i64 %d64, 4
  %t5 = mul i64 %e, 5
  %t6 = mul i64 %f64, 6
  %t7 = mul i64 %g, 7
  %t8 = mul i64 %h64, 8
  %t9 = mul i64 %i, 9
  %s1 = add i64 %t1, %t2
  %s2 = add i64 %s1, %t3
  %s3 = add i64 %s2, %t4
  %s4 = add i64 %s3, %t5
  %s5 = add i64 %s4, %t6
  %s6 = add i64 %s5, %t7
  %s7 = add i64 %s6, %t8
  %s8 = add i64 %s7, %t9
  ret i64 %s8
}
define double @g(double %x, i64 %a, double %y, i64 %b, double %z, i64 %c, double %w, i64 %d) {
  %p = fmul double %x, %y
  %q = fadd double %p, %z
  %r = fadd double %q, %w
  %ai = sitofp i64 %a to double
  %bi = sitofp i64 %b to double
  %ci = sitofp i64 %c to double
  %di = sitofp i64 %d to double
  %s1 = fadd double %r, %ai
  %s2 = fadd double %s1, %bi
  %s3 = fadd double %s2, %ci
  %s4 = fadd double %s3, %di
  ret double %s4
}
define i32 @test() {
  %a = call i64 @f(i64 -1, i32 -2, i16 -3, i8 -4, i64 5000000000, i32 -6, i64 7, i32 -8, i64 90)
  %b = call double @g(double 1.5, i64 10, double 2.0, i64 20, double 0.25, i64 30, double 4.0, i64 40)
  %bi = fptosi double %b to i64
  %s = add i64 %a, %bi
  %t = trunc i64 %s to i32
  ret i32 %t
}
