#!/bin/sh
# make-profile.sh -- the profile of encopt: lz4, zlib and three BearSSL programs (hashes, symmetric ciphers, elliptic curves) run under sim64, as a weights file (encopt.5).
#
#   sh programs/make-profile.sh PREP OUT.weights
#
# PREP is the output of tools/arch-compare/prep.py aarch64 (the preprocessed 841-file corpus with its index.tsv); the sources are in the corpora tree
# (CORPORA, default ~/claude/corpora).  The mains and the stand-in libc are the files of this directory; needs build/pcc/ccom, build/as64, build/ld64, build/sim64.
# The sixth program of the earlier study, Lua, is not here: it needs a real C library (setjmp, strtod, printf, stdio) that does not exist for the pdp64 yet.
# Each program prints a checksum; on the host the same mains with gcc give the same checksums (lz4 28819839, zlib 293329, bs_hash 725528908380846452,
# bs_sym 3567240991110834917, bs_ec 2843755488877783253).
set -eu
PREP=$1; OUT=$2
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
C=${CORPORA:-$HOME/claude/corpora}
pick() {	# the .i files of the corpus whose source path matches the extended regular expression
	awk -F'\t' -v re="$1" -v d="$PREP" '$3 ~ re { printf ",%s/%s.i", d, $1 }' "$PREP/index.tsv"
}
F="-nostdinc -std=gnu99 -D__aarch64__ -isystem $C/sysroot/aarch64/include"
BI="-I $C/bearssl/inc -I $C/bearssl/src"
CODEC=$(pick '^bearssl/src/codec/(ccopy|dec|enc)')
python3 -I "$here/../profile.py" -o "$OUT" --summary "$OUT.summary" \
	--cppflags "lz4=$F -I $C/lz4/lib" --cppflags "zlib=$F -I $C/zlib" --cppflags "bs_hash=$F $BI -DBS_HASH" --cppflags "bs_sym=$F $BI" --cppflags "bs_ec=$F $BI" \
	--program "lz4=$here/lz4main.c,$here/libc.c$(pick '^lz4/lib/lz4[.]c$')" \
	--program "zlib=$here/zlibmain.c,$here/libc.c$(pick '^zlib/(adler32|compress|crc32|deflate|inffast|inflate|inftrees|trees|uncompr|zutil)[.]c$')" \
	--program "bs_hash=$here/bearmain.c,$here/libc.c$(pick '^bearssl/src/(hash/(md5|sha1|sha2big|sha2small)|mac/hmac|symcipher/aes_common)[.]c$')$CODEC" \
	--program "bs_sym=$here/bearmain.c,$here/libc.c$(pick '^bearssl/src/symcipher/(aes_common|aes_ct|aes_ct_cbcdec|aes_ct_cbcenc|aes_ct_ctr|aes_ct_dec|aes_ct_enc|chacha20_ct)[.]c$')$CODEC" \
	--program "bs_ec=$here/ecmain.c,$here/libc.c$(pick '^bearssl/src/(ec/ec_p256_m31|ec/ec_c25519_m31|int/i31_[a-z0-9]*|int/i32_div32)[.]c$')$CODEC"
