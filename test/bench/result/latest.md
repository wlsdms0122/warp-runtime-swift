rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3300 | -1.6% | 3.40 | 185 |  | 568 | -29.0% | 194 | -45.5% |
| call | 1810 | -1.5% | 1.87 | 141 |  | 547 | -28.8% | 175 | -46.8% |
| closure | 1610 | -1.2% | 1.66 | 139 |  | 546 | -29.1% | 176 | -46.2% |
| field | 1158 | +0.5% | 1.19 | 124 |  | 529 | -29.5% | 162 | -48.0% |
| keeps | 2695 | -0.7% | 2.78 | 162 |  | 561 | -29.7% | 191 | -46.3% |
| literal | 1604 | +0.0% | 1.65 | 126 |  | 535 | -30.0% | 167 | -48.2% |
| loop | 969 | -1.7% | 1.00 | 96 |  | 512 | -29.4% | 149 | -48.6% |
| map | 4586 | +0.1% | 4.73 | 166 |  | 563 | -29.4% | 191 | -45.9% |
| native | 1637 | +0.7% | 1.69 | 126 |  | 534 | -29.2% | 166 | -47.3% |
| record | 2113 | -1.6% | 2.18 | 174 |  | 562 | -28.9% | 190 | -45.1% |
| variable | 1867 | -0.4% | 1.93 | 128 |  | 536 | -29.1% | 168 | -47.0% |
| walk | 3157 | -3.1% | 3.26 | 150 |  | 550 | -28.9% | 182 | -45.8% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 489 |  | 489 |  |
| 2 | 530 | 41.5 | 524 | 35.0 |
| 4 | 606 | 39.1 | 587 | 32.7 |
| 8 | 749 | 37.2 | 702 | 30.5 |
| 16 | 1046 | 37.2 | 948 | 30.6 |
| 32 | 1638 | 37.1 | 1462 | 31.4 |
| 64 | 2821 | 37.0 | 2468 | 31.4 |
| 128 | 5186 | 37.0 | 4487 | 31.5 |
| 256 | 10114 | 37.7 | 8750 | 32.4 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7036 | 5981 | 5973 | 1021 | 6995 | 1.01 |
| 2 | 7023 | 5989 | 5790 | 1007 | 3902 | 1.80 |
| 4 | 7028 | 5978 | 5730 | 1003 | 2436 | 2.89 |
| 8 | 7043 | 6000 | 5766 | 999 | 1720 | 4.10 |
| 16 | 7059 | 6038 | 5875 | 975 | 1343 | 5.26 |
| 32 | 7112 | 6079 | 6348 | 973 | 1171 | 6.07 |
| 64 | 7300 | 6258 | 7320 | 994 | 1108 | 6.59 |
| 128 | 7642 | 6524 | 8942 | 1049 | 1119 | 6.83 |
| 256 | 8287 | 6943 | 12176 | 1165 | 1213 | 6.83 |
