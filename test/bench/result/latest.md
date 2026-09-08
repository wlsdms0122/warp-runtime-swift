rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3319 | +1.8% | 3.42 | 654 | +10.3% |
| call | 1823 | +2.4% | 1.88 | 624 | +10.0% |
| closure | 1618 | +1.2% | 1.66 | 626 | +10.8% |
| field | 1146 | +2.3% | 1.18 | 612 | +10.9% |
| keeps | 2712 | +2.3% | 2.79 | 660 | +11.9% |
| literal | 1592 | +1.4% | 1.64 | 622 | +11.0% |
| loop | 972 | +2.1% | 1.00 | 583 | +8.6% |
| map | 4601 | +2.4% | 4.73 | 660 | +9.6% |
| native | 1615 | +2.2% | 1.66 | 614 | +10.3% |
| path | 1671 | +3.5% | 1.72 | 619 | +10.3% |
| record | 2129 | +0.5% | 2.19 | 646 | +10.7% |
| variable | 1867 | +2.3% | 1.92 | 615 | +10.6% |
| walk | 3179 | +1.2% | 3.27 | 641 | +11.0% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 552 |  | 548 |  |
| 2 | 601 | 49.0 | 593 | 44.7 |
| 4 | 693 | 46.8 | 676 | 42.6 |
| 8 | 875 | 46.1 | 839 | 41.6 |
| 16 | 1241 | 45.9 | 1164 | 41.1 |
| 32 | 1987 | 46.3 | 1833 | 41.5 |
| 64 | 3481 | 46.5 | 3180 | 41.8 |
| 128 | 6497 | 46.8 | 5913 | 42.2 |
| 256 | 12690 | 47.6 | 11514 | 43.0 |
