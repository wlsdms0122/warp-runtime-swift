rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3319 | -1.0% | 3.44 | 186 |  | 565 | -29.4% | 195 | -45.0% |
| call | 1806 | -1.7% | 1.87 | 142 |  | 541 | -29.6% | 176 | -46.3% |
| closure | 1598 | -2.0% | 1.66 | 139 |  | 542 | -29.7% | 176 | -46.1% |
| field | 1141 | -0.9% | 1.18 | 125 |  | 529 | -29.5% | 164 | -47.5% |
| keeps | 2700 | -0.5% | 2.80 | 161 |  | 561 | -29.7% | 193 | -45.8% |
| literal | 1570 | -2.0% | 1.63 | 127 |  | 535 | -30.0% | 168 | -47.9% |
| loop | 964 | -2.2% | 1.00 | 95 |  | 511 | -29.6% | 149 | -48.4% |
| map | 4605 | +0.5% | 4.78 | 165 |  | 561 | -29.6% | 193 | -45.6% |
| native | 1609 | -1.1% | 1.67 | 126 |  | 529 | -29.8% | 166 | -47.1% |
| record | 2113 | -1.5% | 2.19 | 175 |  | 561 | -29.0% | 191 | -45.1% |
| variable | 1869 | -0.3% | 1.94 | 128 |  | 533 | -29.5% | 168 | -46.9% |
| walk | 3202 | -1.7% | 3.32 | 150 |  | 550 | -28.9% | 183 | -45.4% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 489 |  | 490 |  |
| 2 | 530 | 40.9 | 522 | 32.2 |
| 4 | 607 | 39.2 | 585 | 31.7 |
| 8 | 749 | 37.2 | 706 | 30.8 |
| 16 | 1047 | 37.2 | 950 | 30.7 |
| 32 | 1620 | 36.5 | 1439 | 30.6 |
| 64 | 2808 | 36.8 | 2452 | 31.1 |
| 128 | 5191 | 37.0 | 4488 | 31.5 |
| 256 | 10128 | 37.8 | 8726 | 32.3 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7009 | 5956 | 5959 | 1007 | 6966 | 1.01 |
| 2 | 7008 | 5958 | 5763 | 999 | 3881 | 1.81 |
| 4 | 7011 | 5961 | 5712 | 991 | 2419 | 2.90 |
| 8 | 7010 | 5995 | 5736 | 985 | 1702 | 4.12 |
| 16 | 7015 | 5995 | 5884 | 968 | 1336 | 5.25 |
| 32 | 7095 | 6079 | 6358 | 963 | 1162 | 6.11 |
| 64 | 7283 | 6240 | 7315 | 986 | 1101 | 6.62 |
| 128 | 7606 | 6504 | 8935 | 1043 | 1113 | 6.84 |
| 256 | 8172 | 6954 | 12188 | 1158 | 1205 | 6.78 |
