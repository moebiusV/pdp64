; expect: 498500  -- a counted loop with a phi, a loop-carried sum and a conditional inside
define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %in, %latch ]
  %s = phi i32 [ 0, %entry ], [ %sn, %latch ]
  %odd = and i32 %i, 1
  %c = icmp eq i32 %odd, 0
  br i1 %c, label %even, label %oddb
even:
  %t1 = mul i32 %i, 3
  br label %latch
oddb:
  %t2 = sub i32 0, %i
  br label %latch
latch:
  %t = phi i32 [ %t1, %even ], [ %t2, %oddb ]
  %sn = add i32 %s, %t
  %in = add i32 %i, 1
  %d = icmp slt i32 %in, 1000
  br i1 %d, label %loop, label %exit
exit:
  ret i32 %sn
}
