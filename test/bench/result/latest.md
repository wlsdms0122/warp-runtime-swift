rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3425 | +2.1% | 3.42 | 187 |  | 552 | -31.0% | 194 | -45.4% |
| call | 1861 | +1.3% | 1.86 | 143 |  | 528 | -31.3% | 175 | -46.7% |
| closure | 1640 | +0.6% | 1.64 | 140 |  | 528 | -31.4% | 175 | -46.6% |
| field | 1190 | +3.3% | 1.19 | 124 |  | 510 | -32.0% | 161 | -48.3% |
| keeps | 2728 | +0.5% | 2.73 | 162 |  | 544 | -31.8% | 191 | -46.3% |
| literal | 1631 | +1.8% | 1.63 | 127 |  | 518 | -32.2% | 167 | -48.1% |
| loop | 1000 | +1.5% | 1.00 | 96 |  | 496 | -31.7% | 148 | -48.9% |
| map | 4743 | +3.5% | 4.74 | 167 |  | 545 | -31.6% | 190 | -46.2% |
| native | 1661 | +2.2% | 1.66 | 127 |  | 517 | -31.5% | 166 | -47.2% |
| record | 2170 | +1.1% | 2.17 | 175 |  | 544 | -31.1% | 189 | -45.5% |
| variable | 1948 | +3.9% | 1.95 | 128 |  | 520 | -31.3% | 168 | -47.0% |
| walk | 3282 | +0.8% | 3.28 | 151 |  | 535 | -30.9% | 183 | -45.6% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 472 |  | 470 |  | -32.6% | -33.0% |
| 2 | 517 | 44.7 | 509 | 39.0 | -32.0% | -32.0% |
| 4 | 591 | 39.6 | 570 | 33.5 | -31.1% | -31.1% |
| 8 | 735 | 37.5 | 685 | 30.8 | -30.4% | -30.4% |
| 16 | 1028 | 37.1 | 935 | 31.0 | -29.4% | -29.4% |
| 32 | 1612 | 36.8 | 1435 | 31.1 | -29.1% | -28.9% |
| 64 | 2807 | 37.1 | 2440 | 31.3 | -28.2% | -28.4% |
| 128 | 5205 | 37.3 | 4491 | 31.7 | -27.7% | -27.3% |
| 256 | 10154 | 38.0 | 8833 | 32.8 | -27.1% | -25.6% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6996 | 5946 | 5928 | 1017 | 6945 | 1.01 |
| 2 | 6994 | 5966 | 5750 | 1009 | 3885 | 1.80 |
| 4 | 7006 | 5956 | 5707 | 1002 | 2428 | 2.89 |
| 8 | 7056 | 5980 | 5749 | 998 | 1717 | 4.11 |
| 16 | 7018 | 6002 | 5895 | 974 | 1342 | 5.23 |
| 32 | 7101 | 6100 | 6367 | 971 | 1170 | 6.07 |
| 64 | 7328 | 6302 | 7366 | 992 | 1107 | 6.62 |
| 128 | 7670 | 6561 | 9020 | 1049 | 1120 | 6.85 |
| 256 | 8284 | 6976 | 12500 | 1166 | 1215 | 6.82 |
