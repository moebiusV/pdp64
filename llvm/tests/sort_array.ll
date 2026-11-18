; expect: 348968  -- a local array filled by a recurrence, sorted by insertion sort, then a weighted checksum; nested loops with indexed addressing
define i32 @test() {
entry:
  %a = alloca [32 x i32], align 4
  br label %fill
fill:
  %i = phi i64 [ 0, %entry ], [ %in, %fill ]
  %x = phi i32 [ 12345, %entry ], [ %xn, %fill ]
  %m = mul i32 %x, 1103515245
  %xn = add i32 %m, 12345
  %v = lshr i32 %xn, 16
  %w = and i32 %v, 1023
  %p = getelementptr i32, ptr %a, i64 %i
  store i32 %w, ptr %p
  %in = add i64 %i, 1
  %c = icmp ult i64 %in, 32
  br i1 %c, label %fill, label %sort
sort:
  br label %outer
outer:
  %o = phi i64 [ 1, %sort ], [ %on, %outer.latch ]
  %po = getelementptr i32, ptr %a, i64 %o
  %key = load i32, ptr %po
  br label %inner
inner:
  %j = phi i64 [ %o, %outer ], [ %jn, %shift ]
  %zero = icmp eq i64 %j, 0
  br i1 %zero, label %place, label %cmp
cmp:
  %jm = add i64 %j, -1
  %pj = getelementptr i32, ptr %a, i64 %jm
  %vj = load i32, ptr %pj
  %gt = icmp ugt i32 %vj, %key
  br i1 %gt, label %shift, label %place
shift:
  %pj1 = getelementptr i32, ptr %a, i64 %j
  store i32 %vj, ptr %pj1
  %jn = add i64 %j, -1
  br label %inner
place:
  %jj = phi i64 [ %j, %inner ], [ %j, %cmp ]
  %pk = getelementptr i32, ptr %a, i64 %jj
  store i32 %key, ptr %pk
  br label %outer.latch
outer.latch:
  %on = add i64 %o, 1
  %oc = icmp ult i64 %on, 32
  br i1 %oc, label %outer, label %sum
sum:
  br label %sloop
sloop:
  %k = phi i64 [ 0, %sum ], [ %kn, %sloop ]
  %s = phi i32 [ 0, %sum ], [ %sn, %sloop ]
  %pk2 = getelementptr i32, ptr %a, i64 %k
  %vk = load i32, ptr %pk2
  %k32 = trunc i64 %k to i32
  %wk = mul i32 %vk, %k32
  %sn = add i32 %s, %wk
  %kn = add i64 %k, 1
  %kc = icmp ult i64 %kn, 32
  br i1 %kc, label %sloop, label %done
done:
  ret i32 %sn
}
