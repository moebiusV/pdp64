; expect: 25577  -- i1 values: icmp results combined with and, or, xor, select, phi and zext/sext; branches on conjunctions
define i32 @f(i32 %a, i32 %b, i32 %c) {
entry:
  %x = icmp sgt i32 %a, %b
  %y = icmp ult i32 %b, %c
  %z = icmp eq i32 %c, 0
  %xy = and i1 %x, %y
  %xz = xor i1 %x, %z
  %o = or i1 %xy, %xz
  br i1 %o, label %t, label %e
t:
  %zt = zext i1 %xy to i32
  %st = sext i1 %xz to i32
  %rt = add i32 %zt, %st
  br label %m
e:
  %ze = zext i1 %z to i32
  %re = shl i32 %ze, 4
  br label %m
m:
  %p = phi i1 [ %xy, %t ], [ %y, %e ]
  %q = phi i32 [ %rt, %t ], [ %re, %e ]
  %pz = zext i1 %p to i32
  %r = add i32 %q, %pz
  %n = xor i1 %p, true
  %sel = select i1 %n, i32 100, i32 200
  %s = add i32 %r, %sel
  ret i32 %s
}
define i32 @test() {
  %a = call i32 @f(i32 5, i32 3, i32 9)
  %b = call i32 @f(i32 1, i32 3, i32 0)
  %c = call i32 @f(i32 5, i32 3, i32 0)
  %d = call i32 @f(i32 -5, i32 -3, i32 -9)
  %e = call i32 @f(i32 0, i32 0, i32 0)
  %s1 = mul i32 %a, 3
  %s2 = add i32 %s1, %b
  %s3 = mul i32 %s2, 5
  %s4 = add i32 %s3, %c
  %s5 = mul i32 %s4, 7
  %s6 = add i32 %s5, %d
  %s7 = xor i32 %s6, %e
  ret i32 %s7
}
