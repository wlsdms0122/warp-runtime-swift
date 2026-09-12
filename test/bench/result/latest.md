rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3307 | -1.4% | 3.42 | 183 |  | 582 | -27.3% | 196 | -44.7% |
| call | 1810 | -1.5% | 1.87 | 142 |  | 556 | -27.6% | 175 | -46.6% |
| closure | 1604 | -1.6% | 1.66 | 138 |  | 553 | -28.2% | 175 | -46.4% |
| field | 1141 | -0.9% | 1.18 | 123 |  | 539 | -28.1% | 163 | -47.8% |
| keeps | 2699 | -0.5% | 2.79 | 160 |  | 572 | -28.3% | 192 | -45.9% |
| literal | 1573 | -1.8% | 1.63 | 125 |  | 546 | -28.5% | 168 | -47.8% |
| loop | 968 | -1.8% | 1.00 | 95 |  | 523 | -28.0% | 149 | -48.5% |
| map | 4556 | -0.6% | 4.71 | 165 |  | 576 | -27.8% | 193 | -45.6% |
| native | 1603 | -1.4% | 1.66 | 125 |  | 543 | -28.0% | 166 | -47.2% |
| record | 2102 | -2.0% | 2.17 | 173 |  | 571 | -27.8% | 191 | -45.1% |
| variable | 1859 | -0.9% | 1.92 | 127 |  | 546 | -27.8% | 168 | -46.8% |
| walk | 3167 | -2.8% | 3.27 | 149 |  | 563 | -27.3% | 184 | -45.3% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 499 |  | 496 |  |
| 2 | 542 | 43.0 | 534 | 38.0 |
| 4 | 617 | 39.4 | 595 | 33.1 |
| 8 | 760 | 37.4 | 719 | 31.9 |
| 16 | 1048 | 36.6 | 958 | 30.8 |
| 32 | 1638 | 36.7 | 1455 | 30.9 |
| 64 | 2800 | 36.5 | 2447 | 31.0 |
| 128 | 5180 | 36.9 | 4470 | 31.3 |
| 256 | 10044 | 37.4 | 8652 | 32.0 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6980 | 5937 | 5931 | 1008 | 6938 | 1.01 |
| 2 | 6977 | 5930 | 5747 | 997 | 3871 | 1.80 |
| 4 | 6961 | 5926 | 5678 | 993 | 2412 | 2.89 |
| 8 | 6984 | 5957 | 5747 | 988 | 1707 | 4.09 |
| 16 | 6975 | 5966 | 5863 | 966 | 1333 | 5.23 |
| 32 | 7072 | 6067 | 6330 | 962 | 1159 | 6.10 |
| 64 | 7246 | 6208 | 7279 | 985 | 1099 | 6.59 |
| 128 | 7590 | 6497 | 8889 | 1042 | 1111 | 6.83 |
| 256 | 8140 | 6915 | 12088 | 1154 | 1201 | 6.78 |
