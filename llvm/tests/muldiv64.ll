; expect: -1095157447  -- 64-bit mul, sdiv, udiv, srem, urem with positive and negative operands
define i64 @f(i64 %a, i64 %b) {
  %m = mul i64 %a, %b
  %d = sdiv i64 %a, %b
  %r = srem i64 %a, %b
  %ud = udiv i64 %a, %b
  %ur = urem i64 %a, %b
  %s1 = add i64 %m, %d
  %s2 = add i64 %s1, %r
  %s3 = xor i64 %s2, %ud
  %s4 = add i64 %s3, %ur
  ret i64 %s4
}
define i32 @test() {
  %a = call i64 @f(i64 1000003, i64 7)
  %b = call i64 @f(i64 -1000003, i64 7)
  %c = call i64 @f(i64 1000003, i64 -7)
  %d = call i64 @f(i64 -1000003, i64 -7)
  %e = call i64 @f(i64 9223372036854775807, i64 1000000007)
  %s1 = xor i64 %a, %b
  %s2 = add i64 %s1, %c
  %s3 = xor i64 %s2, %d
  %s4 = add i64 %s3, %e
  %s5 = lshr i64 %s4, 7
  %r = trunc i64 %s5 to i32
  ret i32 %r
}
