rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3465 | 2482 | 3.53 | 187 | 589 | 197 | 597 |
| call | 1843 | 861 | 1.88 | 146 | 570 | 179 | 576 |
| closure | 1617 | 634 | 1.65 | 147 | 582 | 185 | 589 |
| field | 1257 | 275 | 1.28 | 129 | 558 | 168 | 564 |
| keeps | 2785 | 1802 | 2.83 | 169 | 592 | 196 | 602 |
| literal | 1593 | 610 | 1.62 | 129 | 555 | 169 | 558 |
| loop | 983 | 0 | 1.00 | 125 | 583 | 163 | 586 |
| map | 5232 | 4249 | 5.32 | 169 | 589 | 197 | 594 |
| native | 1621 | 639 | 1.65 | 129 | 559 | 171 | 565 |
| record | 2136 | 1154 | 2.17 | 176 | 579 | 192 | 586 |
| variable | 1882 | 899 | 1.92 | 130 | 558 | 172 | 562 |
| walk | 3297 | 2315 | 3.36 | 174 | 605 | 199 | 622 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 515 |  | 522 |  |
| 2 | 561 | 45.7 | 567 | 45.8 |
| 4 | 673 | 52.8 | 612 | 30.3 |
| 8 | 782 | 38.1 | 736 | 30.6 |
| 16 | 1088 | 38.2 | 988 | 31.1 |
| 32 | 1694 | 38.0 | 1509 | 31.9 |
| 64 | 2967 | 38.9 | 2507 | 31.5 |
| 128 | 5478 | 39.1 | 4576 | 31.9 |
| 256 | 10703 | 40.0 | 8885 | 32.8 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7140 | 6037 | 6062 | 1034 | 7096 | 1.01 |
| 2 | 7137 | 6069 | 5873 | 1024 | 3960 | 1.80 |
| 4 | 7134 | 6089 | 5839 | 1038 | 2497 | 2.86 |
| 8 | 7423 | 6144 | 5906 | 1018 | 1756 | 4.23 |
| 16 | 7151 | 6232 | 6133 | 996 | 1379 | 5.18 |
| 32 | 7413 | 6426 | 6578 | 995 | 1200 | 6.18 |
| 64 | 7597 | 6558 | 7491 | 1009 | 1126 | 6.75 |
| 128 | 8153 | 7175 | 9147 | 1073 | 1144 | 7.12 |
| 256 | 9037 | 7790 | 12758 | 1187 | 1237 | 7.31 |
