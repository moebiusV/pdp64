#!/bin/sh
# movql.sh: how often MOVQL (the ten-byte move of a 64-bit literal) is executed in compiled programs.  Runs every test of tests/c and tests/c-new (compiled by pcc, as the repository's
# pdp64test.sh does) under sim64 -t, through a wrapper that keeps the trace (one line per executed instruction: address, then the parcels of the instruction).  A line of five parcels is a MOVQL.
# usage: sh movql.sh SCRATCHDIR   (needs build/as64, build/ld64, build/sim64, build/pcc/ccom)
R=$(cd "$(dirname "$0")/../../../.." && pwd); S=$1; mkdir -p $S/shim; B=$R/build
ln -sf $B/as64 $S/shim/as64; ln -sf $B/ld64 $S/shim/ld64
cat > $S/shim/sim64 <<EOT
#!/bin/sh
$B/sim64 -t "\$@" > $S/shim/o 2> $S/shim/e
cat $S/shim/o $S/shim/e | grep -E '^[0-9a-f]{8}: ' > $S/shim/last.trace
grep -v -E '^[0-9a-f]{8}: ' $S/shim/o | tail -1
EOT
chmod +x $S/shim/sim64
printf "test\tinstructions\tmovql\tbytes_fetched\tmovql_bytes\ttop_movql_site_count\n"
for f in $R/tests/c/*.c $R/tests/c-new/*.c; do
  PDP64TOOLS=$S/shim $R/tools/pdp64test.sh $f > /dev/null 2>&1
  awk -v n=$(basename $f .c) '{ np=0; for (i=2;i<=NF;i++) if ($i ~ /^[0-9a-f]{4}$/) np++; ins++; by+=2*np; if (np==5) { mq++; mqb+=10; c[$1]++ } }
    END { top=0; for (a in c) if (c[a]>top) top=c[a]; printf "%s\t%d\t%d\t%d\t%d\t%d\n", n, ins, mq, by, mqb, top }' $S/shim/last.trace
done
