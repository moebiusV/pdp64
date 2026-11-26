"""Shared pieces of the instruction dictionary data: the entry constructor and the phrases every entry reuses."""

# Phrases for the Exceptions line.
MEMX = ('Memory operand: page fault, protection fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`); there is no alignment fault, and an access that crosses a page changes nothing when either page faults ({{r:plain-access-at-any-address}}). '
        'Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.')
NONE = 'None.'
PRIV = 'Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.'
ILL = 'A reserved encoding aborts with the illegal-instruction vector.'

NOFLAGS = ''

# The `flags` slot of an entry holds only what is left to say about the result besides the destination register:
# the sticky exception flags of FPSR that a floating-point instruction raises ("Exception flags"), or a result
# that is reported in a register ("Result").  The machine has no condition codes, so for every other entry the slot
# is empty and the entry has no such line.
_NOTHING = ('', 'No flags.', 'None.', 'None written.', 'None written (rotates write no flags).')


def _clean(f):
    if f in _NOTHING or f.startswith(('As for `ADD`', 'Those of the instruction')):
        return ''
    for pre in ('None written. ', 'None. '):
        if f.startswith(pre):
            return f[len(pre):]
    return f


def E(id, page, names, title, syntax, op, flags, exc, notes='', cf='', xnote='', alias=''):
    return dict(id=id, page=page, names=names, title=title, syntax=syntax, op=op, flags=_clean(flags), exc=exc,
                notes=notes, cf=cf, xnote=xnote, alias=alias)
