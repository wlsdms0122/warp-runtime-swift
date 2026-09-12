rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3444 | +2.7% | 3.51 | 186 |  | 556 | -30.5% | 195 | -45.1% |
| call | 1869 | +1.7% | 1.90 | 139 |  | 522 | -32.0% | 172 | -47.5% |
| closure | 1629 | -0.0% | 1.66 | 138 |  | 522 | -32.2% | 173 | -47.2% |
| field | 1162 | +0.9% | 1.18 | 123 |  | 508 | -32.3% | 160 | -48.8% |
| keeps | 2710 | -0.1% | 2.76 | 160 |  | 540 | -32.3% | 189 | -46.8% |
| literal | 1613 | +0.6% | 1.64 | 126 |  | 517 | -32.4% | 166 | -48.4% |
| loop | 982 | -0.4% | 1.00 | 96 |  | 493 | -32.1% | 145 | -49.8% |
| map | 4720 | +3.0% | 4.80 | 166 |  | 545 | -31.6% | 190 | -46.3% |
| native | 1641 | +0.9% | 1.67 | 128 |  | 521 | -30.9% | 166 | -47.0% |
| record | 2161 | +0.7% | 2.20 | 172 |  | 540 | -31.7% | 188 | -45.9% |
| variable | 1913 | +2.0% | 1.95 | 126 |  | 515 | -31.9% | 165 | -47.9% |
| walk | 3301 | +1.3% | 3.36 | 149 |  | 531 | -31.4% | 180 | -46.5% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 469 |  | 467 |  | -33.1% | -33.4% |
| 2 | 512 | 42.6 | 510 | 42.8 | -32.7% | -31.9% |
| 4 | 582 | 37.7 | 575 | 36.2 | -32.2% | -30.5% |
| 8 | 731 | 37.4 | 679 | 30.3 | -30.8% | -31.0% |
| 16 | 1009 | 36.0 | 913 | 29.7 | -30.7% | -31.0% |
| 32 | 1591 | 36.2 | 1423 | 30.8 | -30.0% | -29.5% |
| 64 | 2768 | 36.5 | 2400 | 30.7 | -29.2% | -29.5% |
| 128 | 5126 | 36.7 | 4425 | 31.2 | -28.8% | -28.4% |
| 256 | 10207 | 38.2 | 8871 | 33.0 | -26.8% | -25.3% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6983 | 5859 | 5887 | 1006 | 6892 | 1.01 |
| 2 | 6927 | 5858 | 5645 | 1001 | 3824 | 1.81 |
| 4 | 6875 | 5897 | 5599 | 994 | 2394 | 2.87 |
| 8 | 6982 | 5945 | 5666 | 988 | 1696 | 4.12 |
| 16 | 6947 | 5970 | 5825 | 969 | 1333 | 5.21 |
| 32 | 7045 | 6024 | 6251 | 979 | 1175 | 6.00 |
| 64 | 7281 | 6211 | 7213 | 988 | 1100 | 6.62 |
| 128 | 7584 | 6457 | 8955 | 1061 | 1131 | 6.71 |
| 256 | 8199 | 6920 | 12195 | 1156 | 1204 | 6.81 |
