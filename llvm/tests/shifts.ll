; expect: 876221226  -- shifts by constants and by variables, 64 and 32 bits
define i64 @sh(i64 %x, i64 %n) {
  %a = shl i64 %x, %n
  %b = lshr i64 %x, %n
  %c = ashr i64 %x, %n
  %d = xor i64 %a, %b
  %e = add i64 %d, %c
  ret i64 %e
}
define i32 @sh32(i32 %x, i32 %n) {
  %a = shl i32 %x, %n
  %b = lshr i32 %x, %n
  %c = ashr i32 %x, %n
  %d = xor i32 %a, %b
  %e = add i32 %d, %c
  ret i32 %e
}
define i32 @test() {
  %a = call i64 @sh(i64 -81985529216486896, i64 13)
  %b = call i64 @sh(i64 123456789, i64 0)
  %c = call i32 @sh32(i32 -123456, i32 5)
  %d = call i32 @sh32(i32 -2147483648, i32 31)
  %k1 = shl i64 %a, 3
  %k2 = lshr i64 %b, 2
  %k3 = ashr i64 %a, 60
  %x1 = xor i64 %k1, %k2
  %x2 = add i64 %x1, %k3
  %x3 = trunc i64 %x2 to i32
  %y = add i32 %x3, %c
  %z = xor i32 %y, %d
  ret i32 %z
}
