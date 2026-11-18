; expect: 11184810  -- 64-bit add sub mul and or xor not neg with constants of every size
define i32 @test() {
  %a = add i64 1000000007, 5
  %b = sub i64 %a, 123456789012
  %c = mul i64 %b, -3
  %d = and i64 %c, 1311768467294899695
  %e = or i64 %d, 255
  %f = xor i64 %e, -6148914691236517206
  %g = xor i64 %f, -1
  %h = sub i64 0, %g
  %s = lshr i64 %h, 40
  %r = trunc i64 %s to i32
  ret i32 %r
}
