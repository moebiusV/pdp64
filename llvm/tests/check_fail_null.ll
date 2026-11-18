; expect: fault  -- a null pointer reaches cteq: the program stops with the check fault (an unconditional llvm.trap too: ctcc r0, #0)
; asm: cteq r[0-9]+$
declare void @llvm.ubsantrap(i8 immarg)
@p = global ptr null
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
  %q = load volatile ptr, ptr @p
  %v = call i32 @deref(ptr %q)
  ret i32 %v
}
