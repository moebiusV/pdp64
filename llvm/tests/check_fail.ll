; expect: fault  -- the check FAILS (index 16 of 16): the program stops with the fault of vector 16 (sim64 without -K: the message "check failed" and exit status 139)
; asm: cthi r[0-9]+, #15
@a = internal global [16 x i32] zeroinitializer
declare void @llvm.ubsantrap(i8 immarg)
@idx = global i64 16

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
  %i = load volatile i64, ptr @idx
  %v = call i32 @get(i64 %i)
  ret i32 %v
}
