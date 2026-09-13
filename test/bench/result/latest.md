rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

Not compared against result/base.md: it carries no `load us`. Take it again before reading this against it.

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3448 | 2466 | 3.51 | 188 | 587 | 197 | 595 |
| call | 1872 | 890 | 1.91 | 144 | 564 | 179 | 571 |
| closure | 1627 | 645 | 1.66 | 140 | 558 | 176 | 560 |
| field | 1173 | 191 | 1.19 | 126 | 542 | 163 | 549 |
| keeps | 2740 | 1758 | 2.79 | 164 | 581 | 194 | 586 |
| literal | 1606 | 624 | 1.64 | 129 | 555 | 171 | 558 |
| loop | 982 | 0 | 1.00 | 98 | 532 | 151 | 536 |
| map | 4693 | 3711 | 4.78 | 170 | 585 | 197 | 589 |
| native | 1650 | 668 | 1.68 | 129 | 552 | 168 | 548 |
| record | 2191 | 1209 | 2.23 | 177 | 580 | 193 | 584 |
| variable | 1932 | 950 | 1.97 | 130 | 554 | 169 | 555 |
| walk | 3293 | 2310 | 3.35 | 154 | 576 | 187 | 581 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 509 |  | 510 |  |
| 2 | 552 | 43.0 | 545 | 34.5 |
| 4 | 624 | 38.2 | 605 | 31.7 |
| 8 | 776 | 38.1 | 730 | 31.3 |
| 16 | 1071 | 37.5 | 965 | 30.3 |
| 32 | 1674 | 37.6 | 1489 | 31.6 |
| 64 | 2889 | 37.8 | 2508 | 31.7 |
| 128 | 5382 | 38.4 | 4572 | 32.0 |
| 256 | 10622 | 39.7 | 8866 | 32.8 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7104 | 6055 | 6072 | 1027 | 7098 | 1.00 |
| 2 | 7150 | 6071 | 5884 | 1017 | 3959 | 1.81 |
| 4 | 7101 | 6082 | 5798 | 1013 | 2463 | 2.88 |
| 8 | 7160 | 6106 | 5860 | 999 | 1731 | 4.14 |
| 16 | 7167 | 6135 | 6007 | 989 | 1365 | 5.25 |
| 32 | 7302 | 6274 | 6475 | 975 | 1178 | 6.20 |
| 64 | 7588 | 6529 | 7400 | 1000 | 1115 | 6.80 |
| 128 | 8067 | 6946 | 9173 | 1047 | 1119 | 7.21 |
| 256 | 8931 | 7670 | 12543 | 1164 | 1213 | 7.36 |
