rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3455 | +3.0% | 3.48 | 188 |  | 560 | -29.9% | 197 | -44.5% |
| call | 1891 | +3.0% | 1.91 | 144 |  | 529 | -31.1% | 175 | -46.5% |
| closure | 1645 | +0.9% | 1.66 | 140 |  | 528 | -31.4% | 176 | -46.3% |
| field | 1197 | +3.9% | 1.21 | 126 |  | 516 | -31.2% | 164 | -47.5% |
| keeps | 2767 | +2.0% | 2.79 | 164 |  | 547 | -31.4% | 192 | -46.0% |
| literal | 1625 | +1.4% | 1.64 | 129 |  | 522 | -31.6% | 168 | -47.7% |
| loop | 993 | +0.7% | 1.00 | 98 |  | 498 | -31.4% | 148 | -48.9% |
| map | 4728 | +3.2% | 4.76 | 168 |  | 544 | -31.8% | 190 | -46.3% |
| native | 1665 | +2.4% | 1.68 | 127 |  | 515 | -31.7% | 165 | -47.5% |
| record | 2198 | +2.4% | 2.21 | 175 |  | 545 | -31.0% | 190 | -45.3% |
| variable | 1933 | +3.1% | 1.95 | 129 |  | 519 | -31.4% | 167 | -47.3% |
| walk | 3319 | +1.9% | 3.34 | 152 |  | 536 | -30.7% | 183 | -45.5% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 477 |  | 473 |  | -32.0% | -32.5% |
| 2 | 519 | 41.8 | 509 | 35.6 | -31.8% | -32.0% |
| 4 | 592 | 38.3 | 571 | 32.5 | -31.1% | -31.1% |
| 8 | 737 | 37.2 | 694 | 31.5 | -30.2% | -29.5% |
| 16 | 1032 | 37.0 | 932 | 30.6 | -29.2% | -29.6% |
| 32 | 1619 | 36.8 | 1441 | 31.2 | -28.8% | -28.6% |
| 64 | 2807 | 37.0 | 2450 | 31.4 | -28.2% | -28.1% |
| 128 | 5217 | 37.3 | 4509 | 31.8 | -27.6% | -27.0% |
| 256 | 10257 | 38.4 | 8761 | 32.5 | -26.4% | -26.2% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6987 | 5937 | 5919 | 1017 | 6936 | 1.01 |
| 2 | 6974 | 5995 | 5747 | 1005 | 3879 | 1.80 |
| 4 | 6990 | 5953 | 5716 | 997 | 2426 | 2.88 |
| 8 | 7059 | 5994 | 5768 | 998 | 1719 | 4.11 |
| 16 | 7032 | 6033 | 5909 | 974 | 1344 | 5.23 |
| 32 | 7146 | 6120 | 6413 | 970 | 1170 | 6.11 |
| 64 | 7346 | 6325 | 7334 | 989 | 1104 | 6.66 |
| 128 | 7658 | 6566 | 8992 | 1049 | 1119 | 6.84 |
| 256 | 8326 | 6989 | 12574 | 1167 | 1216 | 6.85 |
