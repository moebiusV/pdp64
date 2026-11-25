#!/bin/sh
# run-all.sh: reproduce the proofs (needs /tmp/nest/pdp = HEAD copy of the manual files, /tmp/nest/bab2/buildabook = prototype build)
set -e
cd /tmp/nest/work
python3 convert.py /tmp/nest/pdp out
./runbook.sh out /tmp/nest/bab2/buildabook
python3 proof.py out || true
rm -rf out2; mkdir out2; cp -r out/src out/outline.txt out2/
sed 's#docs/manual/##' /tmp/nest/pdp/book/sources.txt | grep -E '^[nca]:' | sed 's/^[nca]://' > out2/sources.txt
python3 sync.py --check out2
