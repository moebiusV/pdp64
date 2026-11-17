| class | sites | share | of them in a loop |
|---|---:|---:|---:|
| const | 503 | 60.3% | 257 |
| var | 68 | 8.2% | 45 |
| offset-nuw | 1 | 0.1% | 1 |
| band | 176 | 21.1% | 66 |
| combo | 84 | 10.1% | 28 |
| signed | 2 | 0.2% | 0 |
| all | 834 | 100% | 397 |

| form | instructions added | bytes added | against cbhis (instructions) | against cbhis (bytes) |
|---|---:|---:|---:|---:|
| cbhis | 1096 | 4384 | +0 | +0 |
| cmp+trap | 2014 | 5916 | +918 | +1532 |
| CHK | 1096 | 4384 | +0 | +0 |
| CHK2 | 920 | 3680 | -176 | -704 |
| asrt | 1862 | 7448 | +766 | +3064 |

IR instructions of the sanitized build, 840 files: 402235; sites 834 (0.207 per 100 IR instructions).
Subscripts with a variable index (`getelementptr` with a non-constant index) in the same IR: 10078; the sanitizer guarded 834 of them (8.3%), the arrays whose size the compiler knows.
If a language that checks every subscript (Ada, Rust, Go) guarded all 10078, with the same mix of classes, option 1 (cbhis) would add about 13244 instructions and 52976 bytes before the optimiser removes the provable ones.
