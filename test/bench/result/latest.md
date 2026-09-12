rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3441 | +2.6% | 3.44 | 186 |  | 553 | -30.8% | 194 | -45.4% |
| call | 1861 | +1.3% | 1.86 | 143 |  | 530 | -31.0% | 175 | -46.8% |
| closure | 1654 | +1.5% | 1.65 | 139 |  | 526 | -31.7% | 174 | -46.7% |
| field | 1193 | +3.5% | 1.19 | 125 |  | 516 | -31.2% | 163 | -47.9% |
| keeps | 2761 | +1.8% | 2.76 | 164 |  | 550 | -31.1% | 192 | -46.0% |
| literal | 1677 | +4.6% | 1.68 | 128 |  | 523 | -31.5% | 169 | -47.5% |
| loop | 1000 | +1.4% | 1.00 | 96 |  | 498 | -31.4% | 148 | -48.8% |
| map | 4740 | +3.4% | 4.74 | 168 |  | 547 | -31.4% | 191 | -46.1% |
| native | 1679 | +3.3% | 1.68 | 128 |  | 521 | -31.0% | 166 | -47.0% |
| record | 2213 | +3.1% | 2.21 | 176 |  | 548 | -30.6% | 190 | -45.3% |
| variable | 1957 | +4.4% | 1.96 | 131 |  | 525 | -30.5% | 169 | -46.5% |
| walk | 3367 | +3.4% | 3.37 | 154 |  | 545 | -29.6% | 185 | -45.0% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 483 |  | 477 |  |
| 2 | 521 | 37.6 | 513 | 35.9 |
| 4 | 597 | 38.0 | 572 | 31.9 |
| 8 | 738 | 36.4 | 688 | 30.2 |
| 16 | 1030 | 36.4 | 937 | 30.7 |
| 32 | 1622 | 36.7 | 1438 | 31.0 |
| 64 | 2813 | 37.0 | 2457 | 31.4 |
| 128 | 5244 | 37.5 | 4514 | 31.8 |
| 256 | 10229 | 38.2 | 8777 | 32.6 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7174 | 6051 | 6070 | 1032 | 7102 | 1.01 |
| 2 | 7171 | 6037 | 5857 | 1018 | 3946 | 1.82 |
| 4 | 7156 | 6035 | 5801 | 1017 | 2468 | 2.90 |
| 8 | 7102 | 6063 | 5863 | 1010 | 1743 | 4.08 |
| 16 | 7097 | 6092 | 6009 | 988 | 1363 | 5.21 |
| 32 | 7210 | 6166 | 6432 | 986 | 1187 | 6.07 |
| 64 | 7451 | 6341 | 7413 | 1004 | 1119 | 6.66 |
| 128 | 7730 | 6607 | 9105 | 1062 | 1133 | 6.82 |
| 256 | 8280 | 7040 | 12438 | 1178 | 1226 | 6.75 |
