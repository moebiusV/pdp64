# The instruction semantics and the decoder are not written here: gen/ holds
# copies (qemu/sync.sh in the pdp64 repository) of common/pdp64exec.c, the
# table codec common/pdp64enc.c and its tables generated from
# spec/pdp64/pdp64.hbnf.  They are built as a separate library, with the flags
# the pdp64 tools use, not QEMU's.
pdp64_core = static_library('pdp64core',
  files('gen/pdp64exec.c', 'gen/pdp64enc.c', 'gen/pdp64-tab.c'),
  c_args: ['-w', '-std=gnu11', '-fPIC'],
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
