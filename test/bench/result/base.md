rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3295 | 2335 | 3.43 | 795 | 798 |
| call | 1808 | 847 | 1.88 | 759 | 762 |
| closure | 1585 | 625 | 1.65 | 763 | 767 |
| field | 1136 | 175 | 1.18 | 744 | 747 |
| keeps | 2641 | 1681 | 2.75 | 795 | 798 |
| literal | 1556 | 596 | 1.62 | 751 | 754 |
| loop | 960 | 0 | 1.00 | 713 | 713 |
| map | 4561 | 3601 | 4.75 | 796 | 797 |
| native | 1602 | 642 | 1.67 | 745 | 743 |
| path | 1655 | 695 | 1.72 | 750 | 751 |
| record | 2116 | 1156 | 2.20 | 778 | 780 |
| variable | 1855 | 895 | 1.93 | 746 | 747 |
| walk | 3206 | 2246 | 3.34 | 771 | 776 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 685 |  | 684 |  |
| 2 | 749 | 63.1 | 739 | 54.6 |
| 4 | 850 | 54.9 | 828 | 48.0 |
| 8 | 1056 | 52.9 | 1009 | 46.3 |
| 16 | 1463 | 51.8 | 1372 | 45.8 |
| 32 | 2286 | 51.6 | 2103 | 45.8 |
| 64 | 3939 | 51.6 | 3575 | 45.9 |
| 128 | 7230 | 51.5 | 6520 | 45.9 |
| 256 | 14023 | 52.3 | 12641 | 46.9 |
