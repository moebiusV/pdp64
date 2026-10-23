"""Shared pieces of the instruction dictionary data: the entry constructor and the phrases every entry reuses."""

# Phrases for the Exceptions line.
MEMX = ('Memory operand: page fault, protection fault, alignment fault or bus error (a read of non-existent memory is a precise abort with cause `BUSFAULT`). '
        'Every such fault is precise and the instruction restarts after it, because the register update of an auto-increment or auto-decrement mode is held until the instruction retires.')
NONE = 'None.'
PRIV = 'Privileged: outside kernel mode the instruction aborts with the privileged-instruction vector.'
ILL = 'A reserved encoding aborts with the illegal-instruction vector.'

NZVC_ADD = '`N` and `Z` from the result, `V` set on signed overflow, `C` set on a carry out of bit 63.'
NZVC_SUB = '`N` and `Z` from the result, `V` set on signed overflow, `C` set on a **borrow** (the PDP-11 sense): `C` = 1 when the unsigned operand being subtracted is the larger.'
NZ0 = '`N` and `Z` from the result, `V` cleared, `C` unchanged.'
NOFLAGS = 'None written.'


def E(id, page, names, title, syntax, op, flags, exc, sect, notes='', cf='', xnote=''):
    return dict(id=id, page=page, names=names, title=title, syntax=syntax, op=op, flags=flags, exc=exc, sect=sect,
                notes=notes, cf=cf, xnote=xnote)
