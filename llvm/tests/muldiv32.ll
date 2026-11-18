; expect: -1687299750  -- i32 division and remainder: signed and unsigned, negative operands
define i32 @f(i32 %a, i32 %b) {
  %d = sdiv i32 %a, %b
  %r = srem i32 %a, %b
  %ud = udiv i32 %a, %b
  %ur = urem i32 %a, %b
  %s1 = add i32 %d, %r
  %s2 = xor i32 %s1, %ud
  %s3 = add i32 %s2, %ur
  ret i32 %s3
}
define i32 @test() {
  %a = call i32 @f(i32 100000, i32 7)
  %b = call i32 @f(i32 -100000, i32 7)
  %c = call i32 @f(i32 -2147483648, i32 3)
  %d = call i32 @f(i32 2147483647, i32 -2)
  %e = call i32 @f(i32 -1, i32 65536)
  %s1 = xor i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = xor i32 %s2, %d
  %s4 = add i32 %s3, %e
  ret i32 %s4
}
