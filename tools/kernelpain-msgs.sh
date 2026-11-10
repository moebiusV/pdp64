#!/bin/bash
# Commit-message mining on treeless bare clones, one repository at a time.
# Each clone (commits only: no trees, no blobs, no checkout) is deleted after mining.
# KERNEL_MSGS (default ../kernel-msgs, next to this repository) is where tools/kernelpain.py clonemsgs puts the clones.
# usage: tools/kernelpain-msgs.sh linux linuxold freebsd netbsd openbsd
cd "$(dirname "$0")/.." || exit 1
for r in "$@"; do
  nice -n 10 python3 tools/kernelpain.py clonemsgs "$r" || { echo "clone failed: $r"; continue; }
  nice -n 10 python3 tools/kernelpain.py msgs "$r"
  rm -rf "${KERNEL_MSGS:-$(dirname "$PWD")/kernel-msgs}/$r.git"
done
rmdir "${KERNEL_MSGS:-$(dirname "$PWD")/kernel-msgs}" 2>/dev/null
echo msgs-done
