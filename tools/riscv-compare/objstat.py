"""objstat.py -- instruction count, instruction bytes and .text size of an object file, from llvm-objdump -d (any architecture it knows).
count_obj(path) -> (n_instructions, instruction_bytes, text_section_bytes, data_bytes_in_text, padding_instructions, padding_bytes, call_relocations)
call_relocations = relocations whose type name contains CALL or PLT32 (RISC-V R_RISCV_CALL/CALL_PLT: an unrelaxed auipc+jalr pair that the linker shrinks to one jal when the target is within 1 MiB)
The length of an instruction is the distance to the next line of the listing (the end of .text for the last one).  Lines that objdump shows as
data (.word, .byte, .long, .quad, <unknown>) are not instructions; their bytes go in the fourth field.  Padding is the assembler's alignment fill
(nop, c.nop, nopw, nopl, data16/cs prefixed nops); it is in neither of the first two fields, so ins + ibytes are the code proper and
ibytes + data + padding = text (up to the section end)."""
import re, subprocess
OBJDUMP = 'llvm-objdump-21'
DATA = {'.word', '.byte', '.long', '.quad', '.short', '.half', '.2byte', '.4byte', '.8byte', '<unknown>'}
def is_pad(txt):
    t = txt.split()
    if not t:
        return False
    if t[0] in ('nop', 'c.nop') or t[0].startswith('nop'):
        return True
    return t[0] in ('data16', 'cs', 'xchg', 'ds', 'es') and any(w.startswith('nop') for w in t[:4]) or txt.strip() in ('xchg\t%ax, %ax', 'xchg   %ax,%ax')
def count_obj(path):
    h = subprocess.run([OBJDUMP, '-h', path], capture_output=True, text=True).stdout
    tb = 0
    for l in h.split('\n'):
        p = l.split()
        if len(p) > 2 and p[1] == '.text':
            tb = int(p[2], 16)
    r = subprocess.run([OBJDUMP, '-d', '-j', '.text', '--no-show-raw-insn', path], capture_output=True, text=True, errors='replace')
    ent = []
    for l in r.stdout.split('\n'):
        m = re.match(r'^\s*([0-9a-f]+):\s+(\S.*)$', l)
        if m:
            t = m.group(2).strip().split()
            ent.append((int(m.group(1), 16), t[0] if t else '', m.group(2)))
    n = nb = db = pn = pb = 0
    for i, (a, mn, txt) in enumerate(ent):
        end = ent[i + 1][0] if i + 1 < len(ent) else tb
        if mn in DATA:
            db += end - a
        elif is_pad(txt):
            pn += 1; pb += end - a
        else:
            n += 1; nb += end - a
    rr = subprocess.run([OBJDUMP, '-r', path], capture_output=True, text=True, errors='replace').stdout
    nc = sum(1 for l in rr.split('\n') if re.search(r'R_\w+_(CALL\w*|PLT32)\b', l))
    return n, nb, tb, db, pn, pb, nc
