rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3325 | -0.8% | 3.43 | 187 |  | 607 | -24.1% | 201 | -43.3% |
| call | 1825 | -0.7% | 1.88 | 145 |  | 586 | -23.7% | 184 | -44.0% |
| closure | 1625 | -0.3% | 1.68 | 141 |  | 582 | -24.4% | 183 | -44.0% |
| field | 1151 | -0.1% | 1.19 | 127 |  | 568 | -24.2% | 172 | -44.9% |
| keeps | 2693 | -0.7% | 2.78 | 164 |  | 604 | -24.3% | 201 | -43.4% |
| literal | 1592 | -0.7% | 1.64 | 129 |  | 576 | -24.7% | 177 | -45.1% |
| loop | 970 | -1.6% | 1.00 | 98 |  | 551 | -24.1% | 156 | -45.9% |
| map | 4692 | +2.4% | 4.84 | 168 |  | 602 | -24.5% | 201 | -43.2% |
| native | 1619 | -0.4% | 1.67 | 128 |  | 574 | -23.9% | 174 | -44.4% |
| path | 1703 | +0.9% | 1.76 | 129 |  | 574 | -24.1% | 175 | -45.0% |
| record | 2133 | -0.6% | 2.20 | 176 |  | 604 | -23.5% | 199 | -42.8% |
| variable | 1885 | +0.5% | 1.94 | 130 |  | 576 | -23.9% | 176 | -44.4% |
| walk | 3197 | -1.9% | 3.30 | 152 |  | 592 | -23.5% | 191 | -43.1% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 526 |  | 523 |  | -25.0% | -25.3% |
| 2 | 568 | 42.6 | 559 | 35.4 | -25.2% | -25.3% |
| 4 | 647 | 40.5 | 623 | 33.2 | -24.6% | -24.7% |
| 8 | 801 | 39.4 | 741 | 31.0 | -24.1% | -24.8% |
| 16 | 1109 | 38.9 | 993 | 31.3 | -23.9% | -25.0% |
| 32 | 1732 | 38.9 | 1493 | 31.3 | -23.8% | -26.0% |
| 64 | 2959 | 38.6 | 2501 | 31.4 | -24.3% | -26.6% |
| 128 | 5471 | 38.9 | 4533 | 31.6 | -24.0% | -26.7% |
| 256 | 10623 | 39.6 | 8819 | 32.5 | -23.8% | -25.7% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 6969 | 5945 | 5970 | 999 | 6969 | 1.00 |
| 2 | 6976 | 5955 | 5789 | 995 | 3889 | 1.79 |
| 4 | 6995 | 5980 | 5741 | 988 | 2424 | 2.89 |
| 8 | 7000 | 5998 | 5805 | 980 | 1705 | 4.10 |
| 16 | 7022 | 6027 | 5972 | 963 | 1336 | 5.25 |
| 32 | 7145 | 6150 | 6465 | 963 | 1165 | 6.13 |
| 64 | 7399 | 6378 | 7489 | 989 | 1106 | 6.69 |
| 128 | 7818 | 6718 | 9271 | 1052 | 1125 | 6.95 |
| 256 | 8540 | 7290 | 12766 | 1189 | 1238 | 6.90 |
