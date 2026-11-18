; expect: 14007  -- a dense switch (a jump table) in a loop, with a default and cases that share a target
define i32 @f(i32 %x) {
entry:
  switch i32 %x, label %def [
    i32 0, label %a
    i32 1, label %b
    i32 2, label %c
    i32 3, label %a
    i32 4, label %d
    i32 5, label %e
    i32 6, label %b
    i32 7, label %f
    i32 8, label %c
  ]
a: ret i32 100
b: ret i32 211
c: ret i32 322
d: ret i32 433
e: ret i32 544
f: ret i32 655
def: ret i32 -1
}
define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i32 [ -2, %entry ], [ %in, %loop ]
  %s = phi i32 [ 0, %entry ], [ %sn, %loop ]
  %v = call i32 @f(i32 %i)
  %w = mul i32 %v, %i
  %sn = add i32 %s, %w
  %in = add i32 %i, 1
  %c = icmp slt i32 %in, 12
  br i1 %c, label %loop, label %exit
exit:
  ret i32 %sn
}
