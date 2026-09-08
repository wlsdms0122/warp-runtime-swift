rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3325 | +2.0% | 3.41 | 654 | +10.3% |
| call | 1828 | +2.7% | 1.87 | 623 | +9.9% |
| closure | 1612 | +0.8% | 1.65 | 626 | +10.9% |
| field | 1152 | +2.7% | 1.18 | 607 | +10.0% |
| keeps | 2694 | +1.6% | 2.76 | 659 | +11.7% |
| literal | 1585 | +0.9% | 1.62 | 621 | +11.0% |
| loop | 976 | +2.5% | 1.00 | 582 | +8.4% |
| map | 4552 | +1.4% | 4.66 | 658 | +9.2% |
| native | 1619 | +2.5% | 1.66 | 611 | +9.7% |
| path | 1662 | +3.0% | 1.70 | 615 | +9.7% |
| record | 2149 | +1.5% | 2.20 | 644 | +10.3% |
| variable | 1875 | +2.7% | 1.92 | 611 | +9.9% |
| walk | 3219 | +2.5% | 3.30 | 642 | +11.1% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 555 |  | 553 |  |
| 2 | 603 | 47.8 | 598 | 44.4 |
| 4 | 697 | 47.3 | 680 | 42.1 |
| 8 | 881 | 46.6 | 844 | 41.5 |
| 16 | 1246 | 46.0 | 1177 | 41.6 |
| 32 | 1984 | 46.1 | 1836 | 41.4 |
| 64 | 3475 | 46.3 | 3185 | 41.8 |
| 128 | 6489 | 46.7 | 5909 | 42.2 |
| 256 | 12629 | 47.3 | 11525 | 43.0 |
