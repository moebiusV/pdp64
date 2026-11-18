; expect: 1683271665  -- i128: add, sub, mul (the high half comes from mulhu), shifts, comparison, passed and returned in two registers
define i128 @f(i128 %a, i128 %b) {
  %s = add i128 %a, %b
  %d = sub i128 %s, 12345678901234567890
  %m = mul i128 %d, %b
  %x = lshr i128 %m, 17
  %y = shl i128 %x, 3
  ret i128 %y
}
define i32 @test() {
  %a = call i128 @f(i128 18446744073709551615, i128 1)
  %b = call i128 @f(i128 340282366920938463463374607431768211455, i128 987654321987654321)
  %c = icmp ugt i128 %a, %b
  %z = zext i1 %c to i128
  %s = add i128 %a, %b
  %t = add i128 %s, %z
  %h = lshr i128 %t, 64
  %x = xor i128 %h, %t
  %r = trunc i128 %x to i32
  ret i32 %r
}
