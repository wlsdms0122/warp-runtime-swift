rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3374 | +0.6% | 3.41 | 189 |  | 612 | -23.5% | 206 | -41.9% |
| call | 1858 | +1.1% | 1.87 | 145 |  | 592 | -23.0% | 188 | -42.7% |
| closure | 1613 | -1.1% | 1.63 | 140 |  | 583 | -24.3% | 186 | -43.2% |
| field | 1174 | +1.9% | 1.19 | 127 |  | 567 | -24.3% | 173 | -44.5% |
| keeps | 2714 | +0.0% | 2.74 | 165 |  | 606 | -24.1% | 205 | -42.4% |
| literal | 1601 | -0.1% | 1.62 | 128 |  | 573 | -25.0% | 178 | -44.7% |
| loop | 991 | +0.5% | 1.00 | 99 |  | 553 | -23.8% | 158 | -45.3% |
| map | 4677 | +2.0% | 4.72 | 167 |  | 602 | -24.5% | 203 | -42.8% |
| native | 1647 | +1.3% | 1.66 | 127 |  | 570 | -24.4% | 175 | -44.3% |
| path | 1720 | +1.9% | 1.74 | 128 |  | 570 | -24.7% | 176 | -44.8% |
| record | 2157 | +0.5% | 2.18 | 175 |  | 596 | -24.5% | 198 | -42.8% |
| variable | 1924 | +2.6% | 1.94 | 132 |  | 584 | -22.8% | 180 | -43.0% |
| walk | 3290 | +1.0% | 3.32 | 151 |  | 593 | -23.4% | 193 | -42.5% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 522 |  | 522 |  | -25.5% | -25.5% |
| 2 | 580 | 57.7 | 571 | 49.0 | -23.7% | -23.7% |
| 4 | 656 | 44.8 | 619 | 32.2 | -23.5% | -25.3% |
| 8 | 794 | 38.9 | 738 | 30.8 | -24.8% | -25.1% |
| 16 | 1103 | 38.7 | 1008 | 32.4 | -24.3% | -23.8% |
| 32 | 1726 | 38.8 | 1489 | 31.2 | -24.1% | -26.2% |
| 64 | 2950 | 38.5 | 2498 | 31.4 | -24.6% | -26.7% |
| 128 | 5505 | 39.2 | 4529 | 31.6 | -23.6% | -26.7% |
| 256 | 10839 | 40.5 | 8924 | 33.0 | -22.2% | -24.8% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7027 | 5977 | 5944 | 1007 | 6951 | 1.01 |
| 2 | 7046 | 6008 | 5781 | 989 | 3880 | 1.82 |
| 4 | 7011 | 5953 | 5722 | 1006 | 2436 | 2.88 |
| 8 | 7136 | 6087 | 5835 | 1006 | 1735 | 4.11 |
| 16 | 7055 | 6079 | 5987 | 959 | 1334 | 5.29 |
| 32 | 7224 | 6192 | 6481 | 966 | 1169 | 6.18 |
| 64 | 7464 | 6374 | 7573 | 990 | 1108 | 6.74 |
| 128 | 7922 | 6762 | 9360 | 1057 | 1130 | 7.01 |
| 256 | 8764 | 7334 | 12971 | 1197 | 1248 | 7.02 |
