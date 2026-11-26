#!/bin/sh
# run-all.sh: the order in which the experiment was run (paths as on the machine of the run: W=/tmp/flags-work, the pdp64 worktree /tmp/flags-pdp64 with
# its own build/as64, ld64, sim64 and encdis; the pcc copies /tmp/flags-pcc-base and /tmp/flags-pcc).  Edit the paths at the top of corpus.py and run_progs.py.
set -e
# 1. the tools, in a worktree of HEAD (HBNF=/tmp/hbnf with the templates of a matching hbnf, see tools/build-as64.sh)
#    git worktree add /tmp/flags-pdp64 HEAD ; (cd /tmp/flags-pdp64 && tools/build-sim64.sh)
#    gcc -w -Icommon -Ias64 -Ibuild -o build/encdis tools/encdis.c common/pdp64enc.c build/pdp64-tab.c
# 2. the two compilers: the 32-register build (-DPDP64_REGS32, target -m pdp64/32) of pcc, as it is and with noflags-peep.patch applied
#    (cd /tmp/flags-pcc && ./configure --target=pdp64-unknown-linux && cd cc/ccom && make CFLAGS="-g -O1 -std=gnu89 -w -fcommon -DPDP64_REGS32")
# 3. static corpus
python3 corpus.py base pcc /tmp/flags-work/ccom32-base
PDP64_NOFLAGS=1 PDP64_NOFLAGS_LOG=1 python3 corpus.py nf pcc /tmp/flags-work/ccom32-nf       # the variant (one binary, the environment variable turns it on)
CCOM_EXTRA="-xno-setcc" python3 corpus.py nosetcc pcc /tmp/flags-work/ccom32-nf              # only the SET idiom given up
python3 corpus.py llvm llvm
for l in base nf nosetcc llvm; do python3 relax_sizes.py $l; done
# 4. dynamic
python3 run_progs.py base pcc /tmp/flags-work/ccom32-base
PDP64_NOFLAGS=1 python3 run_progs.py nf pcc /tmp/flags-work/ccom32-nf
python3 run_progs.py llvm llvm
python3 dynmix.py
# 5. tables
python3 summarize.py ; python3 flagsites.py out/nf ; python3 carrysites.py out/base out/nf out/llvm
