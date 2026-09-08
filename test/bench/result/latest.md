rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3318 | +1.8% | 3.40 | 652 | +10.0% |
| call | 1824 | +2.5% | 1.87 | 619 | +9.2% |
| closure | 1619 | +1.2% | 1.66 | 620 | +9.8% |
| field | 1140 | +1.7% | 1.17 | 603 | +9.3% |
| keeps | 2710 | +2.2% | 2.78 | 654 | +10.9% |
| literal | 1583 | +0.9% | 1.62 | 615 | +9.8% |
| loop | 975 | +2.4% | 1.00 | 576 | +7.3% |
| map | 4579 | +2.0% | 4.70 | 654 | +8.6% |
| native | 1621 | +2.6% | 1.66 | 606 | +8.7% |
| path | 1670 | +3.5% | 1.71 | 613 | +9.3% |
| record | 2135 | +0.8% | 2.19 | 641 | +9.7% |
| variable | 1883 | +3.2% | 1.93 | 606 | +9.0% |
| walk | 3202 | +2.0% | 3.29 | 630 | +9.1% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 545 |  | 545 |  |
| 2 | 602 | 57.0 | 596 | 51.3 |
| 4 | 690 | 48.5 | 675 | 43.3 |
| 8 | 876 | 47.2 | 835 | 41.4 |
| 16 | 1243 | 46.5 | 1166 | 41.4 |
| 32 | 1993 | 46.7 | 1841 | 41.8 |
| 64 | 3491 | 46.8 | 3181 | 41.8 |
| 128 | 6499 | 46.9 | 5905 | 42.2 |
| 256 | 12678 | 47.6 | 11484 | 42.9 |
