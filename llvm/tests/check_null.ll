; expect: 42  -- a null check (ubsantrap 22, the type-mismatch handler: a null pointer) -> cteq rs (trap if zero), and llvm.trap in a block reached when p == 0
; asm: cteq r[0-9]+$
; asm: \.chk	2,
@x = internal global i32 42
declare void @llvm.ubsantrap(i8 immarg)

define internal i32 @deref(ptr %p) noinline {
entry:
  %c = icmp eq ptr %p, null
  br i1 %c, label %bad, label %ok
ok:
  %v = load i32, ptr %p
  ret i32 %v
bad:
  call void @llvm.ubsantrap(i8 22)
  unreachable
}
define i32 @test() {
entry:
  %v = call i32 @deref(ptr @x)
  ret i32 %v
}
