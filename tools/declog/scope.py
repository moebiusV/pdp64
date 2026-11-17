#!/usr/bin/env python3
"""scope.py: narrow each project's message set to its own threads plus mentions elsewhere.

For a project: the FOCUS threads (the project's own sessions by project folder, and the chats about it) keep all of the
author's messages; in every other thread only the messages in which the author himself wrote one of the MENTION terms
are kept ("check all mentions").  The broad set is kept as messages.broad.jsonl.
"""
import collections, json, os, re, shutil, sys

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'docs', 'decision-log', 'data')
PROJ = {
    'pdp64': dict(focus={'531', '533', '788', '589', '792', '592', '1882', '1889'},
                  mention=r'pdp64|pdp-64|11/64|11-64|commodore 64|(?<![0-9a-z_])c64(?![0-9a-z_])'),
    'imp72': dict(focus={'silentpc-opusplan:feecd34c', 'hist-silentpc-opusplan:33587680', '644', '595', '617', '646'},
                  mention=r'imp[- ]?72'),
    'hbnf': dict(focus={'silentpc:fd13bc5f', 'hist-silentpc:fd13bc5f', 'hist-silentpc:1ea8e55b', '576', '578', '704', '726',
                        'silentpc:c14a13ff', 'silentpc:fa150405', 'silentpc:afd90154', 'silentpc:7b74ec60',
                        'silentpc:f7933077', 'silentpc-opusplan:4a4c3021', 'silentpc-opusplan:aaaf0cf4',
                        'silentpc-opusplan:34019d9b', 'silentpc-opusplan:f7e53777', '644', '594', '646'},
                 mention=r'hbnf'),
}
for p, cfg in PROJ.items():
    d = os.path.join(D, p)
    broad = os.path.join(d, 'messages.broad.jsonl')
    src = broad if os.path.exists(broad) else (os.path.join(d, 'messages.all.jsonl') if p == 'hbnf' and os.path.exists(os.path.join(d, 'messages.all.jsonl')) else os.path.join(d, 'messages.jsonl'))
    if not os.path.exists(broad):
        shutil.copy(src, broad)
    M = [json.loads(l) for l in open(broad)]
    rx = re.compile(cfg['mention'], re.I)
    keep, n_focus, n_ment = [], 0, 0
    for m in M:
        if str(m['thread']) in cfg['focus']:
            keep.append(m); n_focus += 1
        elif rx.search(m['text']):
            m['mention'] = True; keep.append(m); n_ment += 1
    open(os.path.join(d, 'messages.jsonl'), 'w').write(''.join(json.dumps(m, ensure_ascii=False) + '\n' for m in keep))
    print('%s: %d broad -> %d (%d in its own threads, %d mentions elsewhere)' % (p, len(M), len(keep), n_focus, n_ment))
