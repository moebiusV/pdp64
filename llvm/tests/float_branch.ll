; expect: 111  -- branches on floating-point compares in a loop (the Collatz-like steps in double)
define i32 @test() {
entry:
  br label %loop
loop:
  %x = phi double [ 27.0, %entry ], [ %xn, %latch ]
  %n = phi i32 [ 0, %entry ], [ %nn, %latch ]
  %one = fcmp ole double %x, 1.0
  br i1 %one, label %done, label %step
step:
  %h = fmul double %x, 0.5
  %t = fptosi double %h to i64
  %back = sitofp i64 %t to double
  %isint = fcmp oeq double %back, %h
  br i1 %isint, label %halve, label %triple
halve:
  br label %latch
triple:
  %m = fmul double %x, 3.0
  %p = fadd double %m, 1.0
  br label %latch
latch:
  %xn = phi double [ %h, %halve ], [ %p, %triple ]
  %nn = add i32 %n, 1
  br label %loop
done:
  ret i32 %n
}
