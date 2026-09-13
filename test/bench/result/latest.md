rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

Not compared against result/base.md: it carries no `load us`. Take it again before reading this against it.

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3405 | 2417 | 3.44 | 191 | 612 | 204 | 616 |
| call | 1908 | 920 | 1.93 | 152 | 589 | 187 | 593 |
| closure | 1641 | 652 | 1.66 | 142 | 575 | 181 | 580 |
| field | 1161 | 172 | 1.17 | 128 | 560 | 168 | 567 |
| keeps | 2746 | 1758 | 2.78 | 168 | 592 | 200 | 602 |
| literal | 1602 | 614 | 1.62 | 130 | 563 | 174 | 571 |
| loop | 988 | 0 | 1.00 | 99 | 541 | 155 | 548 |
| map | 4729 | 3740 | 4.78 | 171 | 596 | 199 | 601 |
| native | 1632 | 643 | 1.65 | 130 | 561 | 170 | 564 |
| record | 2161 | 1173 | 2.19 | 179 | 590 | 193 | 597 |
| variable | 1904 | 916 | 1.93 | 134 | 568 | 174 | 580 |
| walk | 3299 | 2310 | 3.34 | 152 | 576 | 187 | 585 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 513 |  | 512 |  |
| 2 | 558 | 44.9 | 546 | 33.5 |
| 4 | 637 | 41.4 | 628 | 38.8 |
| 8 | 799 | 40.9 | 737 | 32.2 |
| 16 | 1109 | 39.7 | 1037 | 35.0 |
| 32 | 1796 | 41.4 | 1594 | 34.9 |
| 64 | 2999 | 39.5 | 2571 | 32.7 |
| 128 | 5455 | 38.9 | 4676 | 32.8 |
| 256 | 10747 | 40.1 | 8955 | 33.1 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7132 | 6048 | 6099 | 1039 | 7138 | 1.00 |
| 2 | 7114 | 6263 | 5968 | 1019 | 4003 | 1.78 |
| 4 | 7178 | 6070 | 5824 | 1016 | 2472 | 2.90 |
| 8 | 7144 | 6121 | 5860 | 1022 | 1754 | 4.07 |
| 16 | 7179 | 6193 | 6065 | 993 | 1372 | 5.23 |
| 32 | 7316 | 6253 | 6491 | 985 | 1188 | 6.16 |
| 64 | 7591 | 6547 | 7465 | 1007 | 1124 | 6.75 |
| 128 | 8094 | 6949 | 9171 | 1063 | 1135 | 7.13 |
| 256 | 8945 | 7675 | 12567 | 1182 | 1231 | 7.27 |
