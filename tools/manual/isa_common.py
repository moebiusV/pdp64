"""Shared pieces of the instruction dictionary data: the entry constructor and the phrases every entry reuses."""

# Phrases for the Exceptions line.
MEMX = ('Memory operand: page fault, protection fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`); there is no alignment fault, and an access that crosses a page changes nothing when either page faults ({{r:plain-access-at-any-address}}). '
        'Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.')
NONE = 'None.'
PRIV = 'Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.'
ILL = 'A reserved encoding aborts with the illegal-instruction vector.'

NOFLAGS = 'No flags.'


def E(id, page, names, title, syntax, op, flags, exc, notes='', cf='', xnote='', alias=''):
    return dict(id=id, page=page, names=names, title=title, syntax=syntax, op=op, flags=flags, exc=exc,
                notes=notes, cf=cf, xnote=xnote, alias=alias)
