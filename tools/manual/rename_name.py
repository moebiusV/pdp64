#!/usr/bin/env python3
"""rename_name.py OLD NEW FILE... : rename a name in every definition and citation ({{#old}}, {{r:old}}, {{u:old}}) of the given files (docs/manual-src/*.md and the Python generators).
Refuses a NEW that is not [a-z0-9-]+ or that is already defined.  Names are identity: after the one-time polish of the generated slugs, renaming is rare."""
import re, sys
old, new, files = sys.argv[1], sys.argv[2], sys.argv[3:]
if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', new):
    raise SystemExit('bad name ' + new)
texts = {f: open(f).read() for f in files}
if any('{{#%s}}' % new in t for t in texts.values()):
    raise SystemExit(new + ' is already defined')
n = 0
for f, t in texts.items():
    u = re.sub(r'\{\{([#]|r:|u:)%s\}\}' % re.escape(old), lambda m: '{{%s%s}}' % (m.group(1), new), t)
    if u != t:
        n += len(re.findall(re.escape(old), t))
        open(f, 'w').write(u)
print('%d occurrences renamed' % n)
