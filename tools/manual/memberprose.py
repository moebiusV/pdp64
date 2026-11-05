"""The prose of the instruction entries was written for pdp64/r20 and says, here and there, how the original encoding lays an instruction out (`len`, parcels, the page-2 forms,
the escape groups, byte counts).  The prefix-coded CPUs have other layouts, which the charts and the leaf lists of their entries give from the grammar; so for them the sentences that
state a layout of the original encoding are left out, after a few phrases that only name the group have been trimmed.  The entries whose text lost a sentence are listed by
tools/mkmanual.py --dropped (the hand-written alternatives are to be added to the entries, with the two forms of a field: E(..., notes=...) and ENC_NOTES in isa_enc.py)."""
import re

TRIM = [
    (r' \(`len (?:=|>=) ?\d+`\)', ''), (r', in `(?:MESC|BESC|AESC|FESC|MBLK|SYSX|ATOM|SYS)`', ''), (r' in `(?:MESC|BESC|AESC|FESC|MBLK|SYSX|ATOM)`', ''),
    (r' \(`(?:MESC|BESC|AESC|FESC|MBLK|SYSX|ATOM)`\)', ''),
]
LAYOUT = re.compile(r'`len|\blen\b|[Pp]arcel|[Pp]age[ -]2|\b(?:MESC|BESC|AESC|FESC|MBLK|SYSX|ATOM|XFER|SOP)\b|escape|\(0x[0-9A-F]{2}\)|`reg` |`low`|(?:two|four|six|eight|\d+) bytes|sub-opcode|opcode')


def sentences(t):
    return re.split(r'(?<=[.;]) (?=[A-Z`*(])', t)


def for_enc(t, dropped=None):
    """the text for a prefix-coded CPU: the sentences that state a layout of the original encoding are left out"""
    if not t:
        return t
    for a, b in TRIM:
        t = re.sub(a, b, t)
    out = []
    for s in sentences(t):
        if LAYOUT.search(s):
            if dropped is not None:
                dropped.append(s)
            continue
        out.append(s)
    return ' '.join(out)
