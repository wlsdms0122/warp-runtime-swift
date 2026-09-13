rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

Not compared against result/base.md: it carries no `load us`. Take it again before reading this against it.

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3419 | 2426 | 3.44 | 187 | 583 | 195 | 588 |
| call | 1864 | 871 | 1.88 | 144 | 561 | 177 | 565 |
| closure | 1640 | 646 | 1.65 | 142 | 559 | 176 | 564 |
| field | 1173 | 180 | 1.18 | 125 | 541 | 163 | 550 |
| keeps | 2760 | 1767 | 2.78 | 164 | 579 | 194 | 585 |
| literal | 1623 | 630 | 1.63 | 130 | 552 | 170 | 563 |
| loop | 993 | 0 | 1.00 | 98 | 527 | 150 | 531 |
| map | 4762 | 3768 | 4.79 | 168 | 580 | 194 | 585 |
| native | 1654 | 660 | 1.66 | 127 | 547 | 167 | 552 |
| record | 2170 | 1177 | 2.18 | 174 | 574 | 190 | 576 |
| variable | 1921 | 927 | 1.93 | 130 | 552 | 168 | 557 |
| walk | 3308 | 2315 | 3.33 | 150 | 565 | 183 | 568 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 500 |  | 498 |  |
| 2 | 540 | 40.0 | 536 | 38.8 |
| 4 | 621 | 40.2 | 597 | 33.3 |
| 8 | 764 | 37.7 | 713 | 30.8 |
| 16 | 1060 | 37.3 | 959 | 30.8 |
| 32 | 1644 | 36.9 | 1450 | 30.7 |
| 64 | 2869 | 37.6 | 2467 | 31.3 |
| 128 | 5317 | 37.9 | 4519 | 31.7 |
| 256 | 10677 | 39.9 | 8849 | 32.8 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7064 | 5997 | 6003 | 1019 | 7022 | 1.01 |
| 2 | 7081 | 5971 | 5772 | 1006 | 3892 | 1.82 |
| 4 | 6998 | 6019 | 5800 | 998 | 2448 | 2.86 |
| 8 | 7069 | 6035 | 5775 | 992 | 1714 | 4.12 |
| 16 | 7138 | 6036 | 5919 | 983 | 1353 | 5.28 |
| 32 | 7234 | 6235 | 6440 | 967 | 1168 | 6.19 |
| 64 | 7541 | 6535 | 7419 | 987 | 1103 | 6.84 |
| 128 | 8135 | 6892 | 9141 | 1046 | 1117 | 7.28 |
| 256 | 8956 | 7630 | 12610 | 1160 | 1209 | 7.40 |
