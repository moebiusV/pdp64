; expect: 1727144466  -- nested calls, values kept across calls (callee-saved registers), results used as arguments
define i64 @add3(i64 %a, i64 %b, i64 %c) {
  %x = add i64 %a, %b
  %y = add i64 %x, %c
  ret i64 %y
}
define i64 @mix(i64 %a, i64 %b) {
  %p = call i64 @add3(i64 %a, i64 %b, i64 1)
  %q = call i64 @add3(i64 %p, i64 %a, i64 %b)
  %r = call i64 @add3(i64 %q, i64 %p, i64 %a)
  %s = mul i64 %r, %p
  %t = add i64 %s, %q
  ret i64 %t
}
define i32 @test() {
  %a = call i64 @mix(i64 3, i64 4)
  %b = call i64 @mix(i64 %a, i64 5)
  %c = call i64 @mix(i64 7, i64 %b)
  %d = add i64 %a, %b
  %e = xor i64 %d, %c
  %t = trunc i64 %e to i32
  ret i32 %t
}
