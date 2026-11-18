; expect: -887  -- binary32: arithmetic, extension and truncation to double, loads and stores, conversions with integers
define float @f(float %a, float %b) {
  %s = fadd float %a, %b
  %p = fmul float %s, %a
  %d = fdiv float %p, %b
  %m = fsub float %d, 0.125
  ret float %m
}
define i32 @test() {
  %mem = alloca [4 x float], align 4
  %r = call float @f(float 3.5, float 2.25)
  %p1 = getelementptr float, ptr %mem, i64 1
  store float %r, ptr %p1
  %q = load float, ptr %p1
  %d = fpext float %q to double
  %e = fmul double %d, 100.0
  %t = fptrunc double %e to float
  %n = fneg float %t
  %i = fptosi float %n to i32
  %j = sitofp i32 -7 to float
  %k = fadd float %j, 0.5
  %l = fptosi float %k to i32
  %s = add i32 %i, %l
  ret i32 %s
}
