; expect: 6765  -- recursion (fib), with the frame pointer and the callee-saved registers
define i64 @fib(i64 %n) {
  %c = icmp slt i64 %n, 2
  br i1 %c, label %base, label %rec
base:
  ret i64 %n
rec:
  %n1 = sub i64 %n, 1
  %a = call i64 @fib(i64 %n1)
  %n2 = sub i64 %n, 2
  %b = call i64 @fib(i64 %n2)
  %s = add i64 %a, %b
  ret i64 %s
}
define i32 @test() {
  %r = call i64 @fib(i64 20)
  %t = trunc i64 %r to i32
  ret i32 %t
}
