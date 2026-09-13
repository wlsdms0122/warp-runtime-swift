rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

Not compared against result/base.md: it carries no `load us`. Take it again before reading this against it.

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3456 | 2432 | 3.37 | 186 | 587 | 197 | 591 |
| call | 1886 | 862 | 1.84 | 144 | 567 | 179 | 570 |
| closure | 1656 | 632 | 1.62 | 142 | 566 | 179 | 572 |
| field | 1183 | 159 | 1.15 | 126 | 552 | 167 | 560 |
| keeps | 2784 | 1760 | 2.72 | 165 | 588 | 197 | 594 |
| literal | 1629 | 605 | 1.59 | 130 | 560 | 172 | 568 |
| loop | 1024 | 0 | 1.00 | 100 | 539 | 153 | 544 |
| map | 4701 | 3677 | 4.59 | 169 | 584 | 194 | 592 |
| native | 1682 | 658 | 1.64 | 129 | 554 | 169 | 561 |
| record | 2212 | 1188 | 2.16 | 178 | 584 | 194 | 591 |
| variable | 1936 | 912 | 1.89 | 131 | 557 | 171 | 563 |
| walk | 3497 | 2473 | 3.42 | 157 | 575 | 189 | 586 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 513 |  | 514 |  |
| 2 | 555 | 42.4 | 548 | 34.6 |
| 4 | 636 | 40.9 | 608 | 31.5 |
| 8 | 777 | 37.8 | 730 | 30.9 |
| 16 | 1079 | 37.7 | 976 | 30.8 |
| 32 | 1676 | 37.5 | 1489 | 31.5 |
| 64 | 2908 | 38.0 | 2529 | 32.0 |
| 128 | 5729 | 41.1 | 4628 | 32.4 |
| 256 | 10681 | 39.9 | 8884 | 32.8 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7133 | 6079 | 6098 | 1033 | 7131 | 1.00 |
| 2 | 7141 | 6070 | 5903 | 1040 | 3992 | 1.79 |
| 4 | 7707 | 6151 | 5854 | 1022 | 2486 | 3.10 |
| 8 | 7180 | 6128 | 5892 | 1017 | 1753 | 4.10 |
| 16 | 7194 | 6152 | 6015 | 994 | 1370 | 5.25 |
| 32 | 7316 | 6283 | 6498 | 991 | 1194 | 6.13 |
| 64 | 7634 | 6564 | 7470 | 1013 | 1130 | 6.76 |
| 128 | 8039 | 6963 | 9198 | 1069 | 1140 | 7.05 |
| 256 | 8991 | 7673 | 12504 | 1187 | 1236 | 7.28 |
