#!/bin/sh
# Generate the feedback form, simulate an edit, ingest it, check the report.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$(dirname "$here")")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 "$here/mkfeedback.py" --root "$root" --output "$tmp/form.txt"
python3 "$here/mkfeedback.py" --root "$root" --output "$tmp/form2.txt"
cmp "$tmp/form.txt" "$tmp/form2.txt" || { echo "FAIL: generator not deterministic"; exit 1; }
cp "$tmp/form.txt" "$tmp/edited.txt"

python3 - "$tmp" <<'PY'
import re, sqlite3, sys, os
tmp = sys.argv[1]
form = open(tmp + "/form.txt", encoding="utf-8").read()
lines = form.split("\n")
assert max(len(l) for l in lines) <= 100, "line too long"
for bad in ("silentpc", "opusplan", "claude", "sonnet", "/home/", "david", "matthew", "VIC-64X", "SID-64X", "BLT64", "Q64"):
    assert bad.lower() not in form.lower(), "forbidden string: " + bad
assert re.search(r"^[0-9]{4}:", form, re.M) is None
ids = re.findall(r"^ENTRY (\S+)$", form, re.M)
assert len(ids) == len(set(ids)) > 200, "entries"
orders = [int(x) for x in re.findall(r"^ORDER: (\d+) ", form, re.M)]
assert orders == list(range(1, len(ids) + 1)), "order numbers"
aff = re.findall(r"^   AFFECTS OPCODES: (yes|maybe|no)", form, re.M)
rank = {"yes": 0, "maybe": 1, "no": 2}
assert [rank[a] for a in aff] == sorted(rank[a] for a in aff), "opcode items not first"
for k in ("J.9.3", "H.3.8.4", "V.M24", "W.1"):
    assert k in ids, k

def fill(eid, dec, note=None):
    global lines
    i = lines.index("ENTRY " + eid)
    j = next(n for n in range(i, len(lines)) if lines[n].startswith("DECISION:"))
    lines[j] = "DECISION: " + dec
    if note:
        lines[j + 1] = "NOTE: " + note[0]
        for extra in note[1:]:
            lines.insert(j + 2, "    " + extra)
fill("J.9.3", "B, E", ["use three registers", "and the size as two words"])
fill("J.2.1", "defer")
fill("H.3.8.4", "A")
fill("V.M24", "other: keep, but document it")
fill("W.1", "Z")
k = lines.index("--- NEW 1 ---")
lines[k + 1] = "TEXT: Should the assembler warn about X?"
open(tmp + "/edited.txt", "w", encoding="utf-8").write("\n".join(lines))
# one annotation on the J.9.3 entry (by line) and one on the whole file
start = lines.index("ENTRY J.9.3") + 2
db = sqlite3.connect(tmp + "/w.db")
db.execute("CREATE TABLE annotations (id INTEGER PRIMARY KEY AUTOINCREMENT, file TEXT NOT NULL, created TEXT NOT NULL, "
           "row_beg INTEGER, col_beg INTEGER, row_end INTEGER, col_end INTEGER, scope TEXT NOT NULL, selected_text TEXT, "
           "paragraphs TEXT, note TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, kind TEXT NOT NULL DEFAULT 'note', "
           "status TEXT NOT NULL DEFAULT 'open')")
f = os.path.abspath(tmp + "/edited.txt")
db.execute("INSERT INTO annotations (file,created,row_beg,col_beg,row_end,col_end,scope,selected_text,note,kind) VALUES (?,?,?,?,?,?,?,?,?,?)",
           (f, "2026-01-01", start, 1, start, 9, "text", "ISSUE", "why not four registers?", "note"))
db.execute("INSERT INTO annotations (file,created,scope,note,kind) VALUES (?,?,?,?,?)", (f, "2026-01-01", "file", "overall remark", "note"))
db.execute("INSERT INTO annotations (file,created,row_beg,row_end,scope,paragraphs,note,deleted) VALUES (?,?,?,?,?,?,?,1)",
           (f, "2026-01-01", start, start, "paragraphs", "%d-%d" % (start, start + 1), "hidden one"))
db.execute("INSERT INTO annotations (file,created,row_beg,row_end,scope,note) VALUES (?,?,?,?,?,?)",
           ("/elsewhere/other.txt", "2026-01-01", start, start, "text", "another file"))
db.commit()
PY

python3 "$here/ingest.py" "$tmp/edited.txt" --db "$tmp/w.db" --json "$tmp/answers.json" > "$tmp/report.md"
python3 "$here/ingest.py" "$tmp/edited.txt" --status > "$tmp/status.txt"

check() { grep -q -- "$1" "$2" || { echo "FAIL: missing '$1' in $2"; cat "$2" | head -60; exit 1; }; }
check '^### J.9.3' "$tmp/report.md"
check 'letters B, E' "$tmp/report.md"
check 'use three registers' "$tmp/report.md"
check 'and the size as two words' "$tmp/report.md"
check 'why not four registers' "$tmp/report.md"
check 'overall remark' "$tmp/report.md"
check '\[deferred\]' "$tmp/report.md"
check 'other: keep, but document it' "$tmp/report.md"
check 'not offered: Z' "$tmp/report.md"
check 'Should the assembler warn about X' "$tmp/report.md"
check 'answered: 4' "$tmp/status.txt"
check 'deferred: 1' "$tmp/status.txt"
check 'AFFECTS OPCODES yes' "$tmp/status.txt"
! grep -q 'hidden one\|another file' "$tmp/report.md" || { echo "FAIL: foreign or deleted annotation shown"; exit 1; }
python3 - "$tmp/answers.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
e = {x["id"]: x for x in d["entries"]}
assert e["J.9.3"]["letters"] == ["B", "E"] and len(e["J.9.3"]["annotations"]) == 1
assert e["J.2.1"]["status"] == "deferred" and e["H.3.8.4"]["letters"] == ["A"]
assert d["summary"]["answered"] == 4 and d["new"][0]["n"] == 1
PY
echo "feedback tests ok"
