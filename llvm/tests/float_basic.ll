; expect: -916  -- double precision add sub mul div neg, abs, sqrt, converted back to integers
declare double @llvm.fabs.f64(double)
declare double @llvm.sqrt.f64(double)
define double @poly(double %x) {
  %a = fmul double %x, %x
  %b = fmul double %a, 0.5
  %c = fsub double %b, %x
  %d = fadd double %c, 3.25
  %e = fdiv double %d, 1.75
  %f = fneg double %e
  ret double %f
}
define i32 @test() {
  %a = call double @poly(double 4.0)
  %b = call double @poly(double -2.5)
  %c = call double @llvm.fabs.f64(double %a)
  %d = fadd double %c, %b
  %e = fmul double %d, 1000.0
  %s = call double @llvm.sqrt.f64(double 144.0)
  %f = fadd double %e, %s
  %i = fptosi double %f to i32
  ret i32 %i
}
