rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3282 | +0.7% | 3.44 | 644 | +8.6% |
| call | 1823 | +2.4% | 1.91 | 613 | +8.2% |
| closure | 1592 | -0.4% | 1.67 | 616 | +9.1% |
| field | 1128 | +0.6% | 1.18 | 603 | +9.2% |
| keeps | 2647 | -0.1% | 2.77 | 648 | +9.8% |
| literal | 1569 | -0.0% | 1.64 | 609 | +8.8% |
| loop | 955 | +0.3% | 1.00 | 573 | +6.8% |
| map | 4500 | +0.2% | 4.71 | 647 | +7.5% |
| native | 1574 | -0.4% | 1.65 | 603 | +8.3% |
| path | 1631 | +1.1% | 1.71 | 607 | +8.2% |
| record | 2133 | +0.7% | 2.23 | 634 | +8.6% |
| variable | 1830 | +0.3% | 1.92 | 605 | +8.8% |
| walk | 3144 | +0.1% | 3.29 | 628 | +8.7% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 552 |  | 546 |  |
| 2 | 600 | 47.4 | 592 | 45.7 |
| 4 | 695 | 47.7 | 677 | 43.6 |
| 8 | 877 | 46.4 | 840 | 42.0 |
| 16 | 1251 | 46.6 | 1165 | 41.3 |
| 32 | 2002 | 46.8 | 1842 | 41.8 |
| 64 | 3542 | 47.4 | 3198 | 42.1 |
| 128 | 6638 | 47.9 | 5903 | 42.2 |
| 256 | 13288 | 49.9 | 11500 | 43.0 |
