rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3407 | +1.6% | 3.41 | 186 |  | 553 | -30.9% | 194 | -45.4% |
| call | 1851 | +0.8% | 1.85 | 143 |  | 531 | -30.9% | 176 | -46.4% |
| closure | 1643 | +0.8% | 1.65 | 139 |  | 527 | -31.5% | 174 | -46.7% |
| field | 1177 | +2.2% | 1.18 | 125 |  | 516 | -31.2% | 163 | -47.7% |
| keeps | 2747 | +1.3% | 2.75 | 163 |  | 548 | -31.3% | 192 | -46.1% |
| literal | 1612 | +0.6% | 1.61 | 129 |  | 523 | -31.5% | 169 | -47.6% |
| loop | 998 | +1.2% | 1.00 | 98 |  | 499 | -31.3% | 149 | -48.6% |
| map | 4723 | +3.0% | 4.73 | 169 |  | 550 | -31.0% | 191 | -46.0% |
| native | 1643 | +1.1% | 1.65 | 128 |  | 520 | -31.1% | 167 | -46.8% |
| record | 2165 | +0.9% | 2.17 | 177 |  | 545 | -31.0% | 190 | -45.3% |
| variable | 1925 | +2.7% | 1.93 | 129 |  | 519 | -31.4% | 167 | -47.0% |
| walk | 3310 | +1.6% | 3.32 | 149 |  | 537 | -30.7% | 182 | -45.9% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 473 |  | 474 |  | -32.5% | -32.4% |
| 2 | 518 | 44.8 | 510 | 35.7 | -31.9% | -31.8% |
| 4 | 589 | 38.6 | 568 | 31.2 | -31.4% | -31.4% |
| 8 | 731 | 36.8 | 684 | 30.0 | -30.8% | -30.6% |
| 16 | 1027 | 37.0 | 935 | 30.7 | -29.5% | -29.4% |
| 32 | 1619 | 37.0 | 1436 | 31.0 | -28.8% | -28.8% |
| 64 | 2810 | 37.1 | 2439 | 31.2 | -28.1% | -28.4% |
| 128 | 5217 | 37.4 | 4492 | 31.6 | -27.6% | -27.3% |
| 256 | 10179 | 38.1 | 8885 | 33.0 | -27.0% | -25.1% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7001 | 5951 | 5941 | 1020 | 6961 | 1.01 |
| 2 | 6998 | 5961 | 5753 | 1009 | 3885 | 1.80 |
| 4 | 6977 | 5946 | 5676 | 998 | 2417 | 2.89 |
| 8 | 7018 | 5988 | 5758 | 999 | 1718 | 4.08 |
| 16 | 7020 | 5992 | 5883 | 976 | 1343 | 5.23 |
| 32 | 7107 | 6109 | 6333 | 974 | 1172 | 6.06 |
| 64 | 7313 | 6286 | 7312 | 994 | 1108 | 6.60 |
| 128 | 7687 | 6554 | 9004 | 1050 | 1120 | 6.86 |
| 256 | 8266 | 6990 | 12336 | 1166 | 1214 | 6.81 |
