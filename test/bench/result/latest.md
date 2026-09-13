rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

Not compared against result/base.md: it carries no `load us`. Take it again before reading this against it.

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3414 | 2419 | 3.43 | 185 | 585 | 195 | 594 |
| call | 1868 | 873 | 1.88 | 144 | 564 | 179 | 572 |
| closure | 1669 | 674 | 1.68 | 140 | 561 | 177 | 564 |
| field | 1179 | 185 | 1.19 | 125 | 544 | 163 | 552 |
| keeps | 2790 | 1795 | 2.80 | 163 | 578 | 192 | 586 |
| literal | 1622 | 627 | 1.63 | 131 | 560 | 172 | 563 |
| loop | 995 | 0 | 1.00 | 97 | 524 | 149 | 530 |
| map | 4722 | 3727 | 4.75 | 167 | 578 | 193 | 586 |
| native | 1677 | 683 | 1.69 | 127 | 548 | 167 | 550 |
| record | 2178 | 1183 | 2.19 | 174 | 576 | 190 | 580 |
| variable | 1935 | 940 | 1.94 | 128 | 553 | 169 | 554 |
| walk | 3310 | 2315 | 3.33 | 150 | 567 | 183 | 572 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 505 |  | 508 |  |
| 2 | 558 | 52.5 | 552 | 44.0 |
| 4 | 637 | 43.9 | 612 | 34.8 |
| 8 | 782 | 39.5 | 719 | 30.2 |
| 16 | 1061 | 37.1 | 965 | 30.5 |
| 32 | 1670 | 37.6 | 1476 | 31.2 |
| 64 | 2879 | 37.7 | 2480 | 31.3 |
| 128 | 5410 | 38.6 | 4590 | 32.1 |
| 256 | 10765 | 40.2 | 8961 | 33.1 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

Not compared against result/base.md: it does not carry this table. Take it again before reading this against it.

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7191 | 6148 | 6123 | 1034 | 7157 | 1.00 |
| 2 | 7664 | 6609 | 6518 | 1087 | 4346 | 1.76 |
| 4 | 7694 | 6695 | 6337 | 1072 | 2656 | 2.90 |
| 8 | 7343 | 6261 | 6273 | 1061 | 1845 | 3.98 |
| 16 | 7633 | 6234 | 6063 | 1004 | 1383 | 5.52 |
| 32 | 7342 | 6387 | 6663 | 990 | 1198 | 6.13 |
| 64 | 7675 | 6638 | 7551 | 1018 | 1136 | 6.76 |
| 128 | 8123 | 6980 | 9276 | 1066 | 1138 | 7.13 |
| 256 | 9048 | 7786 | 12652 | 1180 | 1230 | 7.36 |
