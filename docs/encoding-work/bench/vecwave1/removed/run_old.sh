#!/bin/sh
# run_old.sh KIND [param]: generate, assemble, link and run on the pre-wave-1 sim64 (OLD=dir with as64 ld64 sim64); prints PASS/FAIL and the counters
set -e
OLD=${OLD:?directory of the old as64 ld64 sim64}; D=$(dirname "$0"); T=$(mktemp -d)
python3 "$D/gen.py" "$@" > $T/p.s 2> $T/exp
$OLD/as64 -o $T/p.o $T/p.s; $OLD/ld64 -o $T/p.x $T/p.o
$OLD/sim64 -V -P $T/prof $T/p.x > $T/out 2> $T/err || true
got=$(od -An -v -tx1 $T/out | tr -d ' \n'); want=$(sed 's/EXPECT //' $T/exp)
[ "$got" = "$want" ] && r=PASS || r=FAIL
echo "$r $* $(grep -h 'vec blocks' $T/err | tail -1) $(grep -h -i '^#instr' $T/prof | head -1)"
