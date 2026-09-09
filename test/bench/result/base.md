rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3310 | 2343 | 3.42 | 814 | 813 |
| call | 1820 | 853 | 1.88 | 775 | 776 |
| closure | 1608 | 641 | 1.66 | 775 | 780 |
| field | 1138 | 172 | 1.18 | 754 | 756 |
| keeps | 2682 | 1715 | 2.77 | 806 | 811 |
| literal | 1585 | 619 | 1.64 | 764 | 765 |
| loop | 967 | 0 | 1.00 | 725 | 724 |
| map | 4560 | 3593 | 4.72 | 804 | 808 |
| native | 1607 | 641 | 1.66 | 757 | 758 |
| path | 1653 | 686 | 1.71 | 764 | 765 |
| record | 2122 | 1155 | 2.20 | 801 | 801 |
| variable | 1856 | 889 | 1.92 | 761 | 761 |
| walk | 3204 | 2237 | 3.31 | 782 | 788 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 702 |  | 698 |  |
| 2 | 766 | 63.7 | 755 | 56.4 |
| 4 | 882 | 60.0 | 853 | 51.6 |
| 8 | 1091 | 55.6 | 1027 | 47.0 |
| 16 | 1544 | 56.1 | 1419 | 48.0 |
| 32 | 2430 | 55.7 | 2190 | 48.1 |
| 64 | 4243 | 56.2 | 3741 | 48.3 |
| 128 | 7850 | 56.3 | 6844 | 48.4 |
| 256 | 15317 | 57.3 | 13268 | 49.3 |
