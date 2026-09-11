rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3347 | -0.2% | 3.40 | 187 |  | 604 | -24.5% | 242 | -31.9% |
| call | 1825 | -0.6% | 1.86 | 144 |  | 581 | -24.4% | 223 | -31.9% |
| closure | 1627 | -0.2% | 1.65 | 140 |  | 579 | -24.8% | 221 | -32.5% |
| field | 1164 | +1.0% | 1.18 | 126 |  | 567 | -24.4% | 210 | -32.6% |
| keeps | 2702 | -0.4% | 2.75 | 164 |  | 598 | -25.0% | 241 | -32.4% |
| literal | 1598 | -0.3% | 1.62 | 128 |  | 572 | -25.1% | 216 | -33.0% |
| loop | 984 | -0.2% | 1.00 | 98 |  | 548 | -24.5% | 195 | -32.5% |
| map | 4624 | +0.9% | 4.70 | 168 |  | 602 | -24.4% | 240 | -32.2% |
| native | 1627 | +0.1% | 1.65 | 128 |  | 571 | -24.2% | 213 | -32.1% |
| path | 1699 | +0.7% | 1.73 | 128 |  | 570 | -24.7% | 214 | -32.9% |
| record | 2132 | -0.6% | 2.17 | 177 |  | 598 | -24.3% | 239 | -31.2% |
| variable | 1880 | +0.3% | 1.91 | 129 |  | 572 | -24.4% | 214 | -32.4% |
| walk | 3233 | -0.8% | 3.29 | 152 |  | 588 | -24.1% | 230 | -31.5% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 524 |  | 522 |  | -25.2% | -25.5% |
| 2 | 570 | 46.0 | 559 | 36.5 | -25.0% | -25.3% |
| 4 | 649 | 41.5 | 619 | 32.4 | -24.4% | -25.2% |
| 8 | 799 | 39.2 | 738 | 30.9 | -24.4% | -25.1% |
| 16 | 1104 | 38.7 | 987 | 31.0 | -24.2% | -25.4% |
| 32 | 1718 | 38.5 | 1483 | 31.0 | -24.4% | -26.5% |
| 64 | 2964 | 38.7 | 2490 | 31.2 | -24.2% | -26.9% |
| 128 | 5463 | 38.9 | 4534 | 31.6 | -24.2% | -26.7% |
| 256 | 10654 | 39.7 | 8797 | 32.4 | -23.6% | -25.9% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7007 | 5978 | 5988 | 1007 | 6995 | 1.00 |
| 2 | 7003 | 5982 | 5819 | 1001 | 3910 | 1.79 |
| 4 | 7028 | 5988 | 5840 | 994 | 2454 | 2.86 |
| 8 | 7060 | 6031 | 6036 | 990 | 1745 | 4.05 |
| 16 | 7059 | 6073 | 6464 | 970 | 1374 | 5.14 |
| 32 | 7175 | 6180 | 7494 | 969 | 1203 | 5.97 |
| 64 | 7416 | 6402 | 9581 | 993 | 1142 | 6.49 |
| 128 | 7846 | 6753 | 13501 | 1060 | 1165 | 6.73 |
| 256 | 8590 | 7335 | 21290 | 1196 | 1279 | 6.71 |
