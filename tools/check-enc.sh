#!/bin/sh
# The prefix-coded encodings: the tables are what the forms say (mkenc --check), the C codec agrees with the Python model (check-enc.py), and every
# mnemonic of each encoding assembles to its own opcode (check-drift-enc.py).
set -e
cd "$(dirname "$0")/.."
tools/build-as64.sh > /dev/null
B=${BUILD:-build}
python3 tools/mkenc.py --check
gcc -O1 -w -Icommon -o "$B/encdrv" tests/enc/encdrv.c common/pdp64enc.c "$B/pdp64-16-tab.c" "$B/pdp64-32-tab.c"
python3 tools/check-enc.py
python3 tools/check-drift-enc.py | tail -n 1
