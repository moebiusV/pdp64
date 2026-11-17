654 of 674 bodies compiled; instructions with the default checks 584,061, with all checks suppressed 481,454: the checks add 102,607 (21.3%); check sites 18556 (3.18 per 100 instructions)

The cold blocks that call a check routine hold 55,736 instructions (9.5% of the code, 3.0 per check site; a block shared by several jumps is counted once): what a table-driven trap that carries no arguments would remove.

| kind | sites | share |
|---|---:|---:|
| CE_Access_Check | 8274 | 44.6% |
| CE_Range_Check | 5006 | 27.0% |
| CE_Index_Check | 3081 | 16.6% |
| CE_Length_Check | 922 | 5.0% |
| CE_Invalid_Data | 415 | 2.2% |
| PE_Access_Before_Elaboration | 394 | 2.1% |
| PE_Finalize_Raised_Exception | 152 | 0.8% |
| CE_Overflow_Check | 124 | 0.7% |
| CE_Discriminant_Check | 94 | 0.5% |
| CE_Divide_By_Zero | 35 | 0.2% |
| CE_Tag_Check | 25 | 0.1% |
| PE_Accessibility_Check | 19 | 0.1% |
| SE_Object_Too_Large | 13 | 0.1% |
| PE_Build_In_Place_Mismatch | 1 | 0.0% |
| PE_Unchecked_Union_Restriction | 1 | 0.0% |

Index and range checks (8087): unbiased, register bound: 4765 (59%), unbiased, other bound: 1597 (20%), unbiased, constant bound: 919 (11%), biased, register bound: 452 (6%), biased, constant bound: 249 (3%), biased, other bound: 105 (1%)
