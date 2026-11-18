; expect: 1723936483  -- sitofp, uitofp, fptosi, fptoui between i32/i64 and float/double
define i32 @test() {
  %a = sitofp i64 -123456789012 to double
  %b = uitofp i64 -1 to double
  %c = sitofp i32 -5 to double
  %d = uitofp i32 -5 to double
  %e = fptosi double -1.0e10 to i64
  %f = fptoui double 1.8e19 to i64
  %g = fptosi double 3.99 to i32
  %h = fptoui double 4000000000.5 to i32
  %i = sitofp i64 123456789 to float
  %j = fptosi float %i to i64
  %fa = fdiv double %a, 1.0e6
  %fi = fptosi double %fa to i64
  %fb = fdiv double %b, 1.0e18
  %fbi = fptosi double %fb to i64
  %fc = fadd double %c, %d
  %fci = fptosi double %fc to i64
  %h64 = zext i32 %h to i64
  %g64 = sext i32 %g to i64
  %s1 = add i64 %fi, %fbi
  %s2 = add i64 %s1, %fci
  %s3 = add i64 %s2, %e
  %s4 = add i64 %s3, %f
  %s5 = add i64 %s4, %g64
  %s6 = add i64 %s5, %h64
  %s7 = add i64 %s6, %j
  %t = trunc i64 %s7 to i32
  ret i32 %t
}
