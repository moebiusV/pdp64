# arch-compare -- static size of the 841-file corpus for pdp64 (pcc), pcc amd64 and i386, and GCC/clang for RISC-V, AArch64, x86, Arm, MIPS64.
# usage: make WORK=/some/scratch/dir all       (see README.md for what has to exist first)
WORK     ?= /tmp/arch-compare
PCCENC   ?= $(abspath $(CURDIR)/../../../pcc)   # the pcc branch single-pdp64 (one target)
AS64     ?= $(CURDIR)/../../build/as64
OUT      ?= $(CURDIR)/../../docs/encoding-work/arch-data
FLAGS_A  = -xdmr -xtemps -xdeljumps -xinline -xdce -xssa
FLAGS_C  = -xdmr -xtemps -xdeljumps -xinline -xdce -xccp -xtailcall
J        ?= 2

all: summary

prep:
	for a in aarch64:a64 riscv64:rv amd64:amd64 i386:i386 arm:arm mips64:mips64; do \
	  python3 prep.py $${a%%:*} $(WORK)/i-$${a##*:} -j $(J); done

# ccom builds from the pcc tree PCCENC (a scratch copy per target; the tree itself is not touched)
ccoms:
	sh build-ccoms.sh $(PCCENC) $(WORK)/pcc

pdp64: prep ccoms
	python3 pdp64-static.py $(WORK)/i-a64 $(WORK)/r-pdp64 $(WORK)/pcc/pdp64/cc/ccom/pdp64-unknown-linux-ccom $(AS64) pdp64 -j $(J)
	touch $(WORK)/r-pdp64/done

pccx86: prep ccoms
	python3 pcc-static.py $(WORK)/i-amd64 $(WORK)/r-pcc-amd64-A amd64 $(WORK)/pcc/amd64/cc/ccom/x86_64-unknown-linux-ccom -j $(J) -- $(FLAGS_A) -xabs
	python3 pcc-static.py $(WORK)/i-amd64 $(WORK)/r-pcc-amd64-C amd64 $(WORK)/pcc/amd64/cc/ccom/x86_64-unknown-linux-ccom -j $(J) -- $(FLAGS_C) -xabs
	python3 pcc-static.py $(WORK)/i-i386 $(WORK)/r-pcc-i386-A i386 $(WORK)/pcc/i386/cc/ccom/i386-unknown-linux-ccom -j $(J) -- $(FLAGS_A)
	python3 pcc-static.py $(WORK)/i-i386 $(WORK)/r-pcc-i386-C i386 $(WORK)/pcc/i386/cc/ccom/i386-unknown-linux-ccom -j $(J) -- $(FLAGS_C)
	for d in amd64-A amd64-C i386-A i386-C; do touch $(WORK)/r-pcc-$$d/done; done

refs: prep
	python3 run-refs.py $(WORK)

summary: pdp64 pccx86 refs
	python3 summarize.py $(WORK) $(OUT)
