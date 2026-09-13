rounds 1000000, fastest of 3; load, build, baked and once are the fastest of 201

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3402 | 2413 | 3.44 | 183 | 578 | 194 | 585 |
| call | 1857 | 868 | 1.88 | 141 | 557 | 177 | 564 |
| closure | 1641 | 652 | 1.66 | 140 | 556 | 177 | 560 |
| field | 1176 | 187 | 1.19 | 124 | 540 | 164 | 547 |
| keeps | 2747 | 1758 | 2.78 | 160 | 572 | 193 | 576 |
| literal | 1612 | 623 | 1.63 | 125 | 541 | 168 | 547 |
| loop | 989 | 0 | 1.00 | 95 | 521 | 148 | 524 |
| map | 4707 | 3718 | 4.76 | 165 | 572 | 193 | 580 |
| native | 1645 | 656 | 1.66 | 125 | 541 | 167 | 545 |
| record | 2187 | 1198 | 2.21 | 174 | 570 | 191 | 574 |
| variable | 1927 | 938 | 1.95 | 127 | 543 | 168 | 550 |
| walk | 3279 | 2289 | 3.31 | 148 | 559 | 183 | 565 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 499 |  | 496 |  |
| 2 | 540 | 41.0 | 532 | 36.5 |
| 4 | 614 | 38.6 | 593 | 32.5 |
| 8 | 758 | 37.1 | 712 | 30.9 |
| 16 | 1050 | 36.8 | 954 | 30.5 |
| 32 | 1638 | 36.8 | 1456 | 31.0 |
| 64 | 2831 | 37.0 | 2465 | 31.3 |
| 128 | 5215 | 37.1 | 4497 | 31.5 |
| 256 | 10482 | 39.2 | 8791 | 32.5 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7052 | 6047 | 6034 | 1020 | 7054 | 1.00 |
| 2 | 7027 | 5974 | 5780 | 998 | 3888 | 1.81 |
| 4 | 7056 | 5995 | 5710 | 994 | 2421 | 2.91 |
| 8 | 6997 | 6026 | 5783 | 991 | 1714 | 4.08 |
| 16 | 7016 | 5993 | 5912 | 968 | 1338 | 5.24 |
| 32 | 7081 | 6121 | 6396 | 966 | 1166 | 6.07 |
| 64 | 7331 | 6260 | 7311 | 986 | 1101 | 6.66 |
| 128 | 7634 | 6554 | 8934 | 1043 | 1113 | 6.86 |
| 256 | 8197 | 6948 | 12358 | 1162 | 1210 | 6.77 |
