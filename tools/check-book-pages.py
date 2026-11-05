#!/usr/bin/env python3
"""Look at every page of a built book (book/pdp64-MEMBER.pdf) and report the pages that end with the title or the layout charts of a dictionary entry and no text after them
(the author's rule: an entry that would leave its title and charts at the bottom of a page starts on the next page).  Uses pdftotext.
    tools/check-book-pages.py book/pdp64-16.pdf"""
import re, subprocess, sys

def pages(pdf):
    t = subprocess.run(['pdftotext', '-layout', pdf, '-'], capture_output=True, text=True, check=True).stdout
    return t.split('\f')

def content(text):
    lines = [l.strip() for l in text.split('\n') if l.strip()]
    return [l for l in lines if l != 'The pdp64 Architecture Manual' and not re.match(r'^\d+$', l) and not re.match(r'^(pdp64/\S+|Chapter .*|Appendix .*|The instruction set)$', l)]


def is_chart_line(l):
    return (re.match(r'^(parcel \d|\d+( +\d+)*$|[01]+( +[01]+)*$)', l) is not None or re.search(r'; \d+ bytes$', l) is not None
            or re.search(r'\(cont\.\)$', l) is not None or re.search(r'\(\d+ bytes\)$', l) is not None or re.match(r'^[A-Z0-9_.]+: [A-Za-z0-9_./]+, prefix', l) is not None)


bad = 0
pg = pages(sys.argv[1])
body = lambda k, t: any(l.strip().startswith(k) and '. . .' not in l for l in t.split('\n'))
start = next(n for n, t in enumerate(pg, 1) if n > 5 and body('Chapter 9 \u2014', t))
end = len([t for t in pg if t.strip()]) + 1                 # chapter 9 and the reference tables after it (the entries and the charts of the layouts)
for n in range(start, end):
    cur, nxt = content(pg[n - 1]), content(pg[n])
    if not cur or not nxt:
        continue
    last = cur[-1]
    title = re.match(r'^[A-Z0-9_.]+$', last) is not None or (re.match(r'^[A-Z0-9_.]+: .*', last) is not None and len(last) < 60 and is_chart_line(nxt[0]))
    if nxt[0] in ('Syntax', 'Encoding', 'Operation'):
        continue                      # the last line was the text of a code block, and a label with its own chart follows
    if (is_chart_line(last) and not is_chart_line(nxt[0])) or title:
        bad += 1
        print('page %d ends with %s (%r) and page %d begins with text (%r)' % (n, 'a title' if title and not is_chart_line(last) else 'a chart', last[:60], n + 1, nxt[0][:60]))
print('%s: pages %d to %d (chapter 9 and the tables after it); %d page ends leave a title or charts without text after them' % (sys.argv[1], start, end - 1, bad))
sys.exit(1 if bad else 0)
