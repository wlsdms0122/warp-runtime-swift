rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3352 | -0.0% | 3.44 | 184 |  | 579 | -27.6% | 196 | -44.7% |
| call | 1844 | +0.4% | 1.89 | 141 |  | 556 | -27.7% | 176 | -46.3% |
| closure | 1612 | -1.1% | 1.66 | 139 |  | 556 | -27.8% | 177 | -45.9% |
| field | 1146 | -0.5% | 1.18 | 124 |  | 543 | -27.6% | 165 | -47.2% |
| keeps | 2676 | -1.4% | 2.75 | 162 |  | 575 | -27.9% | 193 | -45.8% |
| literal | 1582 | -1.3% | 1.63 | 126 |  | 549 | -28.2% | 169 | -47.4% |
| loop | 973 | -1.3% | 1.00 | 97 |  | 526 | -27.5% | 150 | -48.2% |
| map | 4570 | -0.3% | 4.69 | 166 |  | 575 | -27.8% | 193 | -45.6% |
| native | 1610 | -1.0% | 1.65 | 126 |  | 542 | -28.1% | 167 | -46.9% |
| record | 2143 | -0.1% | 2.20 | 175 |  | 572 | -27.6% | 191 | -44.9% |
| variable | 1868 | -0.4% | 1.92 | 127 |  | 545 | -28.0% | 167 | -47.0% |
| walk | 3216 | -1.3% | 3.30 | 150 |  | 564 | -27.1% | 184 | -45.3% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 502 |  | 501 |  |
| 2 | 540 | 37.5 | 536 | 34.9 |
| 4 | 616 | 37.9 | 597 | 31.9 |
| 8 | 760 | 36.9 | 713 | 30.2 |
| 16 | 1049 | 36.4 | 953 | 30.1 |
| 32 | 1642 | 36.8 | 1463 | 31.0 |
| 64 | 2818 | 36.8 | 2457 | 31.1 |
| 128 | 5198 | 37.0 | 4494 | 31.4 |
| 256 | 10132 | 37.8 | 8705 | 32.2 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7008 | 5962 | 5957 | 1024 | 6981 | 1.00 |
| 2 | 7010 | 5961 | 5775 | 1008 | 3896 | 1.80 |
| 4 | 6994 | 5951 | 5716 | 1002 | 2431 | 2.88 |
| 8 | 7016 | 5979 | 5764 | 998 | 1719 | 4.08 |
| 16 | 6985 | 5985 | 5904 | 975 | 1344 | 5.20 |
| 32 | 7070 | 6061 | 6358 | 972 | 1171 | 6.04 |
| 64 | 7277 | 6244 | 7318 | 994 | 1108 | 6.57 |
| 128 | 7592 | 6504 | 8939 | 1048 | 1118 | 6.79 |
| 256 | 8168 | 6945 | 12130 | 1162 | 1210 | 6.75 |
