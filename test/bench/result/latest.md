rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3408 | +1.6% | 3.44 | 188 |  | 554 | -30.7% | 194 | -45.4% |
| call | 1861 | +1.3% | 1.88 | 144 |  | 532 | -30.7% | 176 | -46.5% |
| closure | 1629 | -0.1% | 1.64 | 142 |  | 532 | -30.9% | 176 | -46.0% |
| field | 1172 | +1.7% | 1.18 | 126 |  | 516 | -31.2% | 162 | -48.0% |
| keeps | 2726 | +0.5% | 2.75 | 164 |  | 548 | -31.4% | 191 | -46.3% |
| literal | 1597 | -0.4% | 1.61 | 129 |  | 523 | -31.5% | 168 | -47.9% |
| loop | 990 | +0.4% | 1.00 | 97 |  | 497 | -31.6% | 147 | -49.0% |
| map | 4716 | +2.9% | 4.76 | 168 |  | 550 | -31.0% | 192 | -45.8% |
| native | 1653 | +1.6% | 1.67 | 127 |  | 519 | -31.2% | 165 | -47.5% |
| record | 2159 | +0.6% | 2.18 | 177 |  | 548 | -30.6% | 189 | -45.4% |
| variable | 1913 | +2.0% | 1.93 | 129 |  | 521 | -31.1% | 167 | -47.1% |
| walk | 3301 | +1.3% | 3.33 | 152 |  | 537 | -30.6% | 182 | -45.9% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 476 |  | 481 |  | -32.1% | -31.4% |
| 2 | 533 | 57.2 | 511 | 30.8 | -29.9% | -31.6% |
| 4 | 593 | 39.0 | 569 | 29.4 | -30.9% | -31.3% |
| 8 | 735 | 37.1 | 687 | 29.4 | -30.4% | -30.3% |
| 16 | 1028 | 36.8 | 937 | 30.4 | -29.5% | -29.3% |
| 32 | 1623 | 37.0 | 1442 | 31.0 | -28.6% | -28.5% |
| 64 | 2812 | 37.1 | 2451 | 31.3 | -28.1% | -28.1% |
| 128 | 5248 | 37.6 | 4498 | 31.6 | -27.1% | -27.2% |
| 256 | 10299 | 38.5 | 8894 | 33.0 | -26.1% | -25.1% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7032 | 5986 | 5982 | 1014 | 6996 | 1.01 |
| 2 | 7043 | 5982 | 5787 | 1001 | 3894 | 1.81 |
| 4 | 7034 | 5972 | 5708 | 995 | 2422 | 2.90 |
| 8 | 7076 | 6009 | 5773 | 993 | 1715 | 4.13 |
| 16 | 7040 | 6025 | 5928 | 969 | 1340 | 5.25 |
| 32 | 7122 | 6111 | 6406 | 964 | 1164 | 6.12 |
| 64 | 7365 | 6314 | 7346 | 988 | 1103 | 6.68 |
| 128 | 7691 | 6559 | 9119 | 1063 | 1134 | 6.78 |
| 256 | 8314 | 7087 | 12496 | 1163 | 1212 | 6.86 |
