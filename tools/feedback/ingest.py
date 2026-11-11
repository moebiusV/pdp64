#!/usr/bin/env python3
"""ingest.py: read back the answers typed into docs/feedback/decisions-feedback.txt.

Reads the edited form (a copy at any path) and, optionally, the annotations the
pager kept for that file; prints a Markdown report and writes answers.json.
It changes no other file.  Standard library only.

Usage:
  ingest.py [FILE] [--db PATH] [--annot-file PATH] [--no-annotations]
            [--json PATH | --no-json] [--all] [--status]
"""
import argparse
import json
import os
import re
import sqlite3
import sys

RULE_RX = re.compile(r"^={20,}\s*$")
ENTRY_RX = re.compile(r"^ENTRY (\S+)\s*$")
OPT_RX = re.compile(r"^\s+([A-Z])\) ")
NEW_RX = re.compile(r"^--- NEW (\d+) ---\s*$")


def default_form():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(os.path.dirname(here)), "docs", "feedback", "decisions-feedback.txt")


def parse_form(path):
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    entries = []
    news = []
    cur = None
    in_new = False
    start_of_rule = None
    new_cur = None
    for i, ln in enumerate(lines, 1):
        if RULE_RX.match(ln):
            if cur is not None and cur["end"] is None:
                cur["end"] = i - 1
            start_of_rule = i
            continue
        m = ENTRY_RX.match(ln)
        if m:
            cur = {"id": m.group(1), "start": start_of_rule or i, "end": None, "title": "", "order": 0,
                   "kind": "", "affects": "", "options": {}, "decision_lines": [], "note_lines": [],
                   "decision_line": None, "phase": "body"}
            entries.append(cur)
            in_new = False
            continue
        if ln.startswith("NEW QUESTIONS AND DECISIONS"):
            if cur is not None and cur["end"] is None:
                cur["end"] = i - 2
            cur = None
            in_new = True
            continue
        if in_new:
            mn = NEW_RX.match(ln)
            if mn:
                new_cur = {"n": int(mn.group(1)), "line": i, "lines": []}
                news.append(new_cur)
                continue
            if ln.startswith("END OF FORM"):
                new_cur = None
                continue
            if new_cur is not None:
                new_cur["lines"].append(ln)
            continue
        if cur is None:
            continue
        if cur["phase"] == "body":
            mo = re.match(r"^ORDER: (\d+)\s+KIND: (.*?)\s+CHAPTER: (.*)$", ln)
            if mo:
                cur["order"], cur["kind"] = int(mo.group(1)), mo.group(2)
                continue
            if ln.startswith("   TITLE: "):
                cur["title"] = ln[len("   TITLE: "):].strip()
            elif ln.startswith("   AFFECTS OPCODES:"):
                ma = re.match(r"\s+AFFECTS OPCODES:\s*(yes|no|maybe)", ln)
                cur["affects"] = ma.group(1) if ma else ""
            mop = OPT_RX.match(ln)
            if mop:
                cur["options"][mop.group(1)] = ln.strip()
            if ln.startswith("DECISION:"):
                cur["phase"] = "decision"
                cur["decision_line"] = i
                cur["decision_lines"].append(ln[len("DECISION:"):])
            continue
        if cur["phase"] == "decision":
            if ln.startswith("NOTE:"):
                cur["phase"] = "note"
                cur["note_lines"].append(ln[len("NOTE:"):])
            else:
                cur["decision_lines"].append(ln)
            continue
        if cur["phase"] == "note":
            cur["note_lines"].append(ln)
    if cur is not None and cur["end"] is None:
        # last entry before the new-questions header never closed
        cur["end"] = len(lines)
    for e in entries:
        if e["end"] is None:
            e["end"] = len(lines)
        e["decision_raw"] = " ".join(x.strip() for x in e["decision_lines"] if x.strip())
        e["note"] = "\n".join(x.rstrip() for x in e["note_lines"]).strip()
        e["note"] = re.sub(r"\n{3,}", "\n\n", e["note"])
        e["decision"] = parse_decision(e["decision_raw"], set(e["options"]))
    for n in news:
        n["text"] = re.sub(r"^TEXT:", "", "\n".join(n["lines"]).strip()).strip()
    return entries, [n for n in news], len(lines)


def parse_decision(raw, valid):
    raw = raw.strip()
    out = {"status": "open", "letters": [], "other": "", "defer": False, "invalid": [], "raw": raw}
    if not raw:
        return out
    low = raw.lower()
    rest = raw
    # 'other: text' (anywhere); everything after it is the text
    mo = re.search(r"\bother\s*:?\s*(.*)$", raw, re.I | re.S)
    if mo:
        out["other"] = mo.group(1).strip()
        rest = raw[:mo.start()]
        out["status"] = "answered"
    if re.search(r"\bdefer(red)?\b", rest, re.I):
        out["defer"] = True
        rest = re.sub(r"\bdefer(red)?\b", "", rest, flags=re.I)
    toks = re.split(r"[\s,;/+&]+|\band\b", rest, flags=re.I)
    letters, bad = [], []
    for t in toks:
        t = t.strip(".)(")
        if not t:
            continue
        if re.fullmatch(r"[A-Za-z]{1,6}", t) and (len(t) == 1 or t.isupper()):
            for ch in t.upper():
                if ch not in letters:
                    letters.append(ch)
        else:
            bad.append(t)
    if bad and not out["other"]:
        # not a letter list: free text counts as an 'other' answer
        out["other"] = raw
        letters = []
        out["defer"] = False
    out["letters"] = letters
    out["invalid"] = [l for l in letters if valid and l not in valid]
    if out["defer"] and not letters and not out["other"]:
        out["status"] = "deferred"
    elif letters or out["other"]:
        out["status"] = "answered"
    return out


# ---------------------------------------------------------------- annotations

def find_db(arg):
    if arg:
        return arg
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(base, "winless", "winless.db")


def load_annotations(db, names, include_deleted=False):
    """Rows of the annotations table for any of the file names; defensive about columns."""
    if not db or not os.path.exists(db):
        return [], "no annotation database at %s" % (db or "(none)")
    try:
        con = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=3)
        con.row_factory = sqlite3.Row
        cur = con.execute("SELECT * FROM annotations")
        rows = [dict(r) for r in cur.fetchall()]
        con.close()
    except sqlite3.Error as ex:
        return [], "cannot read the annotation database: %s" % ex
    out = []
    for r in rows:
        if r.get("file") not in names:
            continue
        if r.get("deleted") and not include_deleted:
            continue
        out.append(normalize_annotation(r))
    out.sort(key=lambda a: (a["id"] if isinstance(a["id"], int) else 0))
    return out, ""


def to_int(x):
    try:
        return int(x)
    except (TypeError, ValueError):
        return None


def normalize_annotation(r):
    a = {"id": to_int(r.get("id")), "kind": r.get("kind") or "note", "status": r.get("status") or "open",
         "scope": r.get("scope") or "", "text": r.get("selected_text") or "", "note": r.get("note") or "",
         "created": r.get("created") or "", "first": None, "last": None}
    rb, re_ = to_int(r.get("row_beg")), to_int(r.get("row_end"))
    paras = r.get("paragraphs") or ""
    mp = re.match(r"^\s*(\d+)\s*-\s*(\d+)\s*$", str(paras))
    if mp:
        a["first"], a["last"] = int(mp.group(1)), int(mp.group(2))
    elif rb is not None:
        a["first"], a["last"] = rb, re_ if re_ is not None else rb
    if a["scope"] == "file":
        a["first"] = a["last"] = None
    return a


def attach(entries, news, annotations, nlines):
    for e in entries:
        e["annotations"] = []
    outside, whole = [], []
    new_first = min((n["line"] for n in news), default=None)
    for a in annotations:
        if a["first"] is None:
            whole.append(a)
            continue
        hit = False
        for e in entries:
            if a["first"] <= e["end"] and a["last"] >= e["start"]:
                e["annotations"].append(a)
                hit = True
                break
        if not hit:
            outside.append(a)
    return outside, whole


# ---------------------------------------------------------------- output

def summarize(entries):
    s = {"total": len(entries), "answered": 0, "deferred": 0, "open": 0, "by_affects": {}}
    for e in entries:
        st = e["decision"]["status"]
        s[st] += 1
        b = s["by_affects"].setdefault(e["affects"] or "unknown",
                                       {"total": 0, "answered": 0, "deferred": 0, "open": 0})
        b["total"] += 1
        b[st] += 1
    return s


def status_text(entries):
    s = summarize(entries)
    out = ["entries: %d   answered: %d   deferred: %d   open: %d" % (s["total"], s["answered"], s["deferred"], s["open"])]
    for k in ("yes", "maybe", "no", "unknown"):
        if k in s["by_affects"]:
            b = s["by_affects"][k]
            out.append("AFFECTS OPCODES %-6s total %3d   answered %3d   deferred %3d   open %3d" %
                       (k + ":", b["total"], b["answered"], b["deferred"], b["open"]))
    return "\n".join(out)


def fmt_ann(a):
    where = "whole file" if a["first"] is None else ("line %d" % a["first"] if a["first"] == a["last"]
                                                      else "lines %d-%d" % (a["first"], a["last"]))
    s = "- annotation %s (%s, %s, %s)" % (a["id"], a["kind"], a["status"], where)
    if a["text"]:
        s += ': on "%s"' % a["text"].replace("\n", " ")[:120]
    if a["note"]:
        s += " -> " + a["note"].replace("\n", " ")
    return s


def decision_text(e):
    d = e["decision"]
    parts = []
    if d["letters"]:
        parts.append("letters " + ", ".join(d["letters"]))
    if d["other"]:
        parts.append("other: " + d["other"])
    if d["defer"] or d["status"] == "deferred":
        parts.append("defer")
    if not parts:
        parts.append("(empty)")
    s = "; ".join(parts)
    if d["invalid"]:
        s += "  [not offered: %s]" % ", ".join(d["invalid"])
    return s


def report(path, entries, news, annotations, outside, whole, note, show_all):
    L = []
    A = L.append
    s = summarize(entries)
    A("# Feedback report")
    A("")
    A("Form: `%s`" % os.path.basename(path))
    A("")
    A("## Summary")
    A("")
    A("- entries: %d; answered: %d; deferred: %d; open: %d" % (s["total"], s["answered"], s["deferred"], s["open"]))
    for k in ("yes", "maybe", "no", "unknown"):
        if k in s["by_affects"]:
            b = s["by_affects"][k]
            A("- AFFECTS OPCODES %s: %d entries, %d answered, %d deferred, %d open" %
              (k, b["total"], b["answered"], b["deferred"], b["open"]))
    A("- annotations read: %d%s" % (len(annotations), "" if not note else " (%s)" % note))
    A("")
    A("## Entries")
    A("")
    shown = 0
    for e in sorted(entries, key=lambda x: x["order"]):
        has = e["decision"]["status"] != "open" or e["note"] or e["annotations"]
        if not (has or show_all):
            continue
        shown += 1
        A("### %s: %s" % (e["id"], e["title"]))
        A("")
        A("- order %d, affects opcodes: %s, kind: %s" % (e["order"], e["affects"] or "?", e["kind"]))
        A("- decision: %s [%s]" % (decision_text(e), e["decision"]["status"]))
        for l in e["decision"]["letters"]:
            if l in e["options"]:
                A("  - %s" % e["options"][l][:140])
        if e["note"]:
            A("- note:")
            for nl in e["note"].split("\n"):
                A("  > " + nl.strip() if nl.strip() else "  >")
        for a in e["annotations"]:
            A(fmt_ann(a))
        A("")
    if not shown:
        A("(no entry has an answer, a note or an annotation yet)")
        A("")
    open_ids = {}
    for e in sorted(entries, key=lambda x: x["order"]):
        if e["decision"]["status"] == "open":
            open_ids.setdefault(e["affects"] or "unknown", []).append(e["id"])
    A("## Entries still open")
    A("")
    for k in ("yes", "maybe", "no", "unknown"):
        if k in open_ids:
            A("- AFFECTS OPCODES %s (%d): %s" % (k, len(open_ids[k]), ", ".join(open_ids[k])))
    A("")
    if whole or outside:
        A("## Annotations outside the entries")
        A("")
        for a in whole + outside:
            A(fmt_ann(a))
        A("")
    A("## New questions and decisions")
    A("")
    filled = [n for n in news if n["text"]]
    if not filled:
        A("(none)")
    for n in filled:
        A("### NEW %d" % n["n"])
        A("")
        for tl in n["text"].split("\n"):
            A("> " + tl.rstrip() if tl.strip() else ">")
        A("")
    return "\n".join(L).rstrip() + "\n"


def to_json(path, entries, news, annotations, outside, whole, note):
    return {
        "form": os.path.basename(path),
        "summary": summarize(entries),
        "entries": [{
            "id": e["id"], "title": e["title"], "order": e["order"], "kind": e["kind"],
            "affects_opcodes": e["affects"], "lines": [e["start"], e["end"]],
            "status": e["decision"]["status"], "letters": e["decision"]["letters"],
            "other": e["decision"]["other"], "defer": e["decision"]["defer"],
            "not_offered": e["decision"]["invalid"], "decision_raw": e["decision_raw"],
            "note": e["note"], "annotations": e["annotations"],
        } for e in sorted(entries, key=lambda x: x["order"])],
        "new": [{"n": n["n"], "text": n["text"]} for n in news if n["text"]],
        "annotations_outside_entries": outside,
        "annotations_whole_file": whole,
        "annotations_note": note,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("file", nargs="?", default=None, help="the edited form (default docs/feedback/decisions-feedback.txt)")
    ap.add_argument("--db", default=None, help="the pager's annotation database")
    ap.add_argument("--annot-file", action="append", default=[], help="file name under which the annotations were made (repeatable)")
    ap.add_argument("--no-annotations", action="store_true")
    ap.add_argument("--include-deleted", action="store_true")
    ap.add_argument("--json", default=None, help="where to write answers.json (default: beside the form)")
    ap.add_argument("--no-json", action="store_true")
    ap.add_argument("--all", action="store_true", help="list every entry, answered or not")
    ap.add_argument("--status", action="store_true", help="print counts only; write nothing")
    a = ap.parse_args(argv)
    path = a.file or default_form()
    if not os.path.exists(path):
        sys.exit("ingest: no such file: %s" % path)
    entries, news, nlines = parse_form(path)
    if not entries:
        sys.exit("ingest: %s has no ENTRY lines; is it a feedback form?" % path)
    if a.status:
        print(status_text(entries))
        return 0
    annotations, note = [], ""
    if not a.no_annotations:
        names = set(a.annot_file) | {os.path.abspath(path), os.path.realpath(path)}
        annotations, note = load_annotations(find_db(a.db), names, a.include_deleted)
    outside, whole = attach(entries, news, annotations, nlines)
    sys.stdout.write(report(path, entries, news, annotations, outside, whole, note, a.all))
    if not a.no_json:
        out = a.json or os.path.join(os.path.dirname(os.path.abspath(path)), "answers.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(to_json(path, entries, news, annotations, outside, whole, note), f, indent=1,
                      ensure_ascii=False, sort_keys=True)
            f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
