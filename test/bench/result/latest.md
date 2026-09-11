rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3343 | -0.3% | 3.26 | 189 |  | 608 | -24.0% | 282 | -20.4% |
| call | 1822 | -0.8% | 1.78 | 146 |  | 588 | -23.4% | 264 | -19.4% |
| closure | 1660 | +1.9% | 1.62 | 142 |  | 577 | -25.0% | 262 | -19.8% |
| field | 1198 | +4.0% | 1.17 | 130 |  | 574 | -23.5% | 253 | -18.8% |
| keeps | 2768 | +2.0% | 2.70 | 163 |  | 598 | -25.0% | 280 | -21.3% |
| literal | 1607 | +0.2% | 1.57 | 129 |  | 574 | -24.9% | 257 | -20.3% |
| loop | 1025 | +3.9% | 1.00 | 103 |  | 563 | -22.5% | 240 | -16.9% |
| map | 4738 | +3.4% | 4.62 | 168 |  | 601 | -24.5% | 280 | -20.8% |
| native | 1668 | +2.6% | 1.63 | 128 |  | 568 | -24.6% | 253 | -19.6% |
| path | 1720 | +1.9% | 1.68 | 129 |  | 569 | -24.8% | 253 | -20.7% |
| record | 2189 | +2.0% | 2.14 | 177 |  | 596 | -24.6% | 277 | -20.3% |
| variable | 1929 | +2.9% | 1.88 | 130 |  | 569 | -24.7% | 254 | -19.6% |
| walk | 3278 | +0.6% | 3.20 | 151 |  | 585 | -24.4% | 269 | -19.9% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 522 |  | 521 |  | -25.5% | -25.6% |
| 2 | 567 | 44.0 | 556 | 34.1 | -25.5% | -25.7% |
| 4 | 646 | 41.2 | 619 | 32.6 | -24.7% | -25.2% |
| 8 | 796 | 39.0 | 738 | 30.9 | -24.6% | -25.1% |
| 16 | 1105 | 38.8 | 986 | 31.0 | -24.2% | -25.5% |
| 32 | 1717 | 38.5 | 1485 | 31.1 | -24.4% | -26.4% |
| 64 | 2958 | 38.7 | 2488 | 31.2 | -24.4% | -27.0% |
| 128 | 5473 | 39.0 | 4534 | 31.6 | -24.0% | -26.6% |
| 256 | 10630 | 39.6 | 8771 | 32.4 | -23.7% | -26.1% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7056 | 6034 | 6060 | 1034 | 7094 | 0.99 |
| 2 | 7057 | 6021 | 5910 | 1017 | 3972 | 1.78 |
| 4 | 7053 | 6022 | 6039 | 1009 | 2519 | 2.80 |
| 8 | 7096 | 6066 | 6442 | 1003 | 1809 | 3.92 |
| 16 | 7124 | 6111 | 7175 | 986 | 1435 | 4.97 |
| 32 | 7215 | 6224 | 8895 | 987 | 1265 | 5.70 |
| 64 | 7516 | 6471 | 12389 | 1009 | 1203 | 6.25 |
| 128 | 7903 | 6811 | 18988 | 1076 | 1224 | 6.46 |
| 256 | 8697 | 7398 | 32188 | 1210 | 1335 | 6.51 |
