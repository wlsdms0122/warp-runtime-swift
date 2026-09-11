rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3302 | -1.5% | 3.40 | 186 |  | 604 | -24.5% | 283 | -20.4% |
| call | 1806 | -1.7% | 1.86 | 143 |  | 580 | -24.4% | 263 | -19.7% |
| closure | 1598 | -2.0% | 1.65 | 140 |  | 580 | -24.6% | 262 | -19.9% |
| field | 1142 | -0.9% | 1.18 | 123 |  | 563 | -24.9% | 251 | -19.7% |
| keeps | 2667 | -1.7% | 2.75 | 163 |  | 600 | -24.8% | 281 | -21.1% |
| literal | 1580 | -1.4% | 1.63 | 130 |  | 573 | -24.9% | 257 | -20.1% |
| loop | 970 | -1.6% | 1.00 | 98 |  | 550 | -24.3% | 236 | -18.4% |
| map | 4602 | +0.4% | 4.74 | 168 |  | 604 | -24.2% | 282 | -20.4% |
| native | 1641 | +0.9% | 1.69 | 128 |  | 571 | -24.3% | 255 | -18.9% |
| path | 1662 | -1.5% | 1.71 | 129 |  | 568 | -25.0% | 254 | -20.2% |
| record | 2093 | -2.5% | 2.16 | 176 |  | 598 | -24.3% | 276 | -20.4% |
| variable | 1917 | +2.2% | 1.98 | 129 |  | 572 | -24.3% | 255 | -19.3% |
| walk | 3310 | +1.6% | 3.41 | 159 |  | 608 | -21.5% | 280 | -16.8% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 564 |  | 552 |  | -19.6% | -21.2% |
| 2 | 595 | 30.7 | 558 | 5.3 | -21.8% | -25.5% |
| 4 | 648 | 28.2 | 633 | 26.9 | -24.4% | -23.5% |
| 8 | 799 | 33.5 | 739 | 26.7 | -24.4% | -25.0% |
| 16 | 1107 | 36.2 | 985 | 28.9 | -24.0% | -25.6% |
| 32 | 1730 | 37.6 | 1510 | 30.9 | -23.9% | -25.2% |
| 64 | 2940 | 37.7 | 2488 | 30.7 | -24.8% | -27.0% |
| 128 | 5453 | 38.5 | 4546 | 31.5 | -24.3% | -26.4% |
| 256 | 10525 | 39.1 | 8860 | 32.6 | -24.5% | -25.4% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7047 | 6002 | 6006 | 1011 | 7017 | 1.00 |
| 2 | 7031 | 5988 | 5906 | 1001 | 3954 | 1.78 |
| 4 | 7044 | 6011 | 6025 | 995 | 2502 | 2.82 |
| 8 | 7074 | 6056 | 6369 | 992 | 1788 | 3.96 |
| 16 | 7078 | 6067 | 7103 | 966 | 1410 | 5.02 |
| 32 | 7186 | 6188 | 8758 | 969 | 1243 | 5.78 |
| 64 | 7450 | 6449 | 12347 | 992 | 1185 | 6.29 |
| 128 | 7865 | 6738 | 18533 | 1061 | 1206 | 6.52 |
| 256 | 8536 | 7300 | 31760 | 1190 | 1314 | 6.50 |
