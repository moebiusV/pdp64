; expect: 21004  -- Euclid's algorithm with urem, a loop that exits from the middle
define i64 @gcd(i64 %a, i64 %b) {
entry:
  br label %loop
loop:
  %x = phi i64 [ %a, %entry ], [ %y, %body ]
  %y = phi i64 [ %b, %entry ], [ %r, %body ]
  %z = icmp eq i64 %y, 0
  br i1 %z, label %done, label %body
body:
  %r = urem i64 %x, %y
  br label %loop
done:
  ret i64 %x
}
define i32 @test() {
  %a = call i64 @gcd(i64 1071, i64 462)
  %b = call i64 @gcd(i64 6700417, i64 641)
  %c = call i64 @gcd(i64 1234567890123, i64 9876543210)
  %s1 = mul i64 %a, 1000
  %s2 = add i64 %s1, %b
  %s3 = add i64 %s2, %c
  %t = trunc i64 %s3 to i32
  ret i32 %t
}
