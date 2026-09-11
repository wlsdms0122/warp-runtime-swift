rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3367 | +0.4% | 3.41 | 186 |  | 606 | -24.2% | 202 | -43.1% |
| call | 1843 | +0.3% | 1.87 | 144 |  | 584 | -23.9% | 184 | -44.0% |
| closure | 1620 | -0.6% | 1.64 | 142 |  | 580 | -24.6% | 184 | -43.9% |
| field | 1167 | +1.3% | 1.18 | 128 |  | 571 | -23.8% | 175 | -44.1% |
| keeps | 2734 | +0.8% | 2.77 | 165 |  | 607 | -24.0% | 202 | -43.1% |
| literal | 1597 | -0.3% | 1.62 | 132 |  | 584 | -23.6% | 180 | -44.1% |
| loop | 987 | +0.1% | 1.00 | 99 |  | 551 | -24.1% | 157 | -45.6% |
| map | 4707 | +2.7% | 4.77 | 169 |  | 600 | -24.7% | 201 | -43.2% |
| native | 1639 | +0.8% | 1.66 | 128 |  | 573 | -24.0% | 174 | -44.7% |
| path | 1709 | +1.3% | 1.73 | 129 |  | 573 | -24.3% | 175 | -45.0% |
| record | 2136 | -0.5% | 2.16 | 178 |  | 602 | -23.8% | 200 | -42.4% |
| variable | 1904 | +1.6% | 1.93 | 131 |  | 574 | -24.1% | 176 | -44.4% |
| walk | 3259 | +0.0% | 3.30 | 154 |  | 592 | -23.5% | 192 | -43.0% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 534 |  | 536 |  | -23.8% | -23.5% |
| 2 | 571 | 37.2 | 559 | 22.5 | -24.8% | -25.3% |
| 4 | 644 | 36.7 | 621 | 28.3 | -24.9% | -25.0% |
| 8 | 792 | 36.8 | 741 | 29.2 | -25.0% | -24.8% |
| 16 | 1116 | 38.8 | 990 | 30.3 | -23.4% | -25.2% |
| 32 | 1711 | 38.0 | 1508 | 31.3 | -24.7% | -25.3% |
| 64 | 2947 | 38.3 | 2495 | 31.1 | -24.6% | -26.8% |
| 128 | 5496 | 39.1 | 4584 | 31.9 | -23.7% | -25.8% |
| 256 | 10783 | 40.2 | 8951 | 33.0 | -22.6% | -24.6% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7028 | 6019 | 5986 | 1005 | 6992 | 1.01 |
| 2 | 7087 | 6030 | 5809 | 1016 | 3920 | 1.81 |
| 4 | 7074 | 6039 | 5763 | 1009 | 2449 | 2.89 |
| 8 | 7096 | 6079 | 5801 | 990 | 1715 | 4.14 |
| 16 | 7064 | 6107 | 5939 | 984 | 1356 | 5.21 |
| 32 | 7209 | 6185 | 6483 | 966 | 1169 | 6.17 |
| 64 | 7451 | 6428 | 7496 | 1003 | 1120 | 6.65 |
| 128 | 7934 | 6784 | 9354 | 1078 | 1151 | 6.90 |
| 256 | 8684 | 7347 | 12893 | 1215 | 1266 | 6.86 |
