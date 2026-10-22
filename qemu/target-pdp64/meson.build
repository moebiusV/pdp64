# The instruction semantics and the decoder are not written here: gen/ holds
# copies (qemu/sync.sh in the pdp64 repository) of common/pdp64exec.c and the
# decoder generated from spec/pdp64.hbnf.  They are built as a separate
# library, with the flags the pdp64 tools use, not QEMU's.
pdp64_core = static_library('pdp64core',
  files('gen/pdp64exec.c', 'gen/calib.c', 'gen/p2.c', 'gen/fmtp.c'),
  c_args: ['-w', '-std=gnu11', '-fPIC',
           '-Demit_bits=fmt_emit_bits', '-Demit_bytes=fmt_emit_bytes',
           '-Dparse_bits=fmt_parse_bits', '-Dparse_bytes=fmt_parse_bytes',
           '-Dfree_arena=fmt_free_arena'],
  include_directories: include_directories('gen'),
  dependencies: [dependency('threads', required: false)],
  build_by_default: false)
pdp64_core_dep = declare_dependency(link_with: pdp64_core,
  dependencies: cc.find_library('m', required: false))

pdp64_ss = ss.source_set()
pdp64_ss.add(files(
  'cpu.c',
  'helper.c',
  'mmu.c',
  'op_helper.c',
  'translate.c'))
pdp64_ss.add(pdp64_core_dep)

target_arch += {'pdp64': pdp64_ss}
