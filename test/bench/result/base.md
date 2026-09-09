rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3299 | 2326 | 3.39 | 795 | 800 |
| call | 1810 | 837 | 1.86 | 758 | 760 |
| closure | 1611 | 638 | 1.66 | 758 | 759 |
| field | 1138 | 165 | 1.17 | 735 | 738 |
| keeps | 2707 | 1734 | 2.78 | 793 | 792 |
| literal | 1588 | 615 | 1.63 | 749 | 749 |
| loop | 973 | 0 | 1.00 | 710 | 711 |
| map | 4549 | 3576 | 4.67 | 795 | 799 |
| native | 1649 | 676 | 1.70 | 741 | 742 |
| path | 1696 | 723 | 1.74 | 756 | 758 |
| record | 2198 | 1225 | 2.26 | 796 | 805 |
| variable | 1899 | 926 | 1.95 | 740 | 742 |
| walk | 3260 | 2287 | 3.35 | 768 | 772 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 680 |  | 677 |  |
| 2 | 740 | 59.2 | 730 | 53.5 |
| 4 | 846 | 55.3 | 827 | 50.2 |
| 8 | 1051 | 52.9 | 1007 | 47.2 |
| 16 | 1457 | 51.8 | 1368 | 46.1 |
| 32 | 2278 | 51.5 | 2103 | 46.0 |
| 64 | 3939 | 51.7 | 3562 | 45.8 |
| 128 | 7246 | 51.7 | 6527 | 46.1 |
| 256 | 14074 | 52.5 | 12606 | 46.8 |
