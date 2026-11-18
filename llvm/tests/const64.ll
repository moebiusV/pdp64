; expect: -32769  -- 64-bit constants: small, 32-bit and wide (the literal pool), as operands and as results
define i64 @k(i64 %x) {
  %a = add i64 %x, 2147483647
  %b = add i64 %a, 2147483648
  %c = xor i64 %b, 1311768467294899695
  %d = add i64 %c, -9223372036854775808
  %e = and i64 %d, 72057594037927935
  %f = or i64 %e, -2147483649
  ret i64 %f
}
define i32 @test() {
  %a = call i64 @k(i64 0)
  %b = call i64 @k(i64 -1)
  %c = call i64 @k(i64 4294967296)
  %s1 = xor i64 %a, %b
  %s2 = add i64 %s1, %c
  %s3 = lshr i64 %s2, 16
  %t = trunc i64 %s3 to i32
  ret i32 %t
}
