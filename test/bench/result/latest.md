rounds 1000000, fastest of 3; load, build, baked and once are the fastest of 201

| workload | ns/round | minus loop | x loop | load us | build us | baked us | once us |
|---|---|---|---|---|---|---|---|
| box | 3307 | 2344 | 3.44 | 183 | 578 | 194 | 584 |
| call | 1800 | 837 | 1.87 | 142 | 557 | 176 | 563 |
| closure | 1605 | 643 | 1.67 | 139 | 553 | 175 | 559 |
| field | 1146 | 184 | 1.19 | 124 | 539 | 162 | 547 |
| keeps | 2665 | 1703 | 2.77 | 160 | 573 | 192 | 576 |
| literal | 1575 | 612 | 1.64 | 126 | 544 | 168 | 551 |
| loop | 962 | 0 | 1.00 | 96 | 521 | 148 | 526 |
| map | 4547 | 3585 | 4.73 | 166 | 572 | 194 | 582 |
| native | 1600 | 638 | 1.66 | 126 | 543 | 166 | 548 |
| record | 2113 | 1150 | 2.20 | 173 | 568 | 189 | 575 |
| variable | 1863 | 900 | 1.94 | 127 | 544 | 167 | 551 |
| walk | 3182 | 2220 | 3.31 | 149 | 561 | 183 | 566 |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 497 |  | 496 |  |
| 2 | 540 | 43.2 | 531 | 35.1 |
| 4 | 613 | 38.7 | 594 | 32.7 |
| 8 | 759 | 37.5 | 715 | 31.3 |
| 16 | 1050 | 36.9 | 956 | 30.7 |
| 32 | 1635 | 36.7 | 1456 | 31.0 |
| 64 | 2809 | 36.7 | 2450 | 31.0 |
| 128 | 5192 | 37.0 | 4470 | 31.3 |
| 256 | 10087 | 37.6 | 8692 | 32.1 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6981 | 5960 | 5941 | 1007 | 6948 | 1.00 |
| 2 | 6978 | 5952 | 5745 | 1000 | 3872 | 1.80 |
| 4 | 6955 | 5940 | 5691 | 987 | 2410 | 2.89 |
| 8 | 6956 | 5982 | 5738 | 984 | 1702 | 4.09 |
| 16 | 6954 | 5980 | 5883 | 964 | 1332 | 5.22 |
| 32 | 7048 | 6074 | 6350 | 961 | 1159 | 6.08 |
| 64 | 7240 | 6240 | 7297 | 982 | 1096 | 6.61 |
| 128 | 7559 | 6500 | 8915 | 1038 | 1108 | 6.82 |
| 256 | 8077 | 6908 | 12143 | 1154 | 1201 | 6.72 |
