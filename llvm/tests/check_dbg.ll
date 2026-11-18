; expect: 5  -- the debug location of the trap gives the file and line of the record of the check site: .chk 1, "dbg.c", 7
; asm: \.chk	1, "dbg\.c", 7$
declare void @llvm.ubsantrap(i8 immarg)
define internal i32 @f(i64 %i) noinline !dbg !6 {
entry:
  %c = icmp ult i64 %i, 8, !dbg !9
  br i1 %c, label %ok, label %bad, !dbg !9
ok:
  %t = trunc i64 %i to i32
  ret i32 %t, !dbg !9
bad:
  call void @llvm.ubsantrap(i8 18), !dbg !10
  unreachable
}
define i32 @test() {
entry:
  %v = call i32 @f(i64 5)
  ret i32 %v
}
!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3}
!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "t", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "dbg.c", directory: "/tmp")
!3 = !{i32 2, !"Debug Info Version", i32 3}
!6 = distinct !DISubprogram(name: "f", scope: !1, file: !1, line: 5, type: !7, scopeLine: 5, spFlags: DISPFlagDefinition | DISPFlagLocalToUnit, unit: !0)
!7 = !DISubroutineType(types: !8)
!8 = !{null}
!9 = !DILocation(line: 6, column: 3, scope: !6)
!10 = !DILocation(line: 7, column: 3, scope: !6)
