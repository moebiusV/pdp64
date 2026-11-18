; expect: 136  -- a bounds check (ubsantrap 18, as clang -fsanitize=bounds -fsanitize-trap=bounds writes it): icmp ult + branch to a block that traps -> one ctcc with an immediate bound, no failure block
; asm: cthi r[0-9]+, #15
; asm: \.chk	1,
; noasm: ctcc r0, #0
@a = internal global [16 x i32] [i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 16]
declare void @llvm.ubsantrap(i8 immarg)

define internal i32 @get(i64 %i) noinline {
entry:
  %c = icmp ult i64 %i, 16
  br i1 %c, label %ok, label %bad
ok:
  %p = getelementptr [16 x i32], ptr @a, i64 0, i64 %i
  %v = load i32, ptr %p
  ret i32 %v
bad:
  call void @llvm.ubsantrap(i8 18)
  unreachable
}

define i32 @test() {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %in, %loop ]
  %s = phi i32 [ 0, %entry ], [ %sn, %loop ]
  %g = call i32 @get(i64 %i)
  %sn = add i32 %s, %g
  %in = add i64 %i, 1
  %d = icmp ult i64 %in, 16
  br i1 %d, label %loop, label %exit
exit:
  ret i32 %sn
}
