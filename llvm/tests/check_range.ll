; expect: 7  -- lo <= x && x < hi with llvm.trap on failure -> one chk2 (kind 3, range); the second compare is in its own block
; asm: chk2 r[0-9]+, r[0-9]+, r[0-9]+
; noasm: ctcc r0, #0
declare void @llvm.trap()

define internal i32 @inrange(i32 %x, i32 %lo, i32 %hi) noinline {
entry:
  %a = icmp slt i32 %x, %lo
  br i1 %a, label %bad, label %second
second:
  %b = icmp sge i32 %x, %hi
  br i1 %b, label %bad, label %ok
ok:
  %r = sub i32 %x, %lo
  ret i32 %r
bad:
  call void @llvm.trap()
  unreachable
}
define i32 @test() {
entry:
  %v = call i32 @inrange(i32 10, i32 3, i32 11)
  ret i32 %v
}
