rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3349 | 2369 | 3.42 | 827 | 834 |
| call | 1834 | 854 | 1.87 | 823 | 832 |
| closure | 1655 | 675 | 1.69 | 796 | 799 |
| field | 1164 | 184 | 1.19 | 771 | 775 |
| keeps | 2703 | 1723 | 2.76 | 826 | 830 |
| literal | 1609 | 628 | 1.64 | 779 | 784 |
| loop | 980 | 0 | 1.00 | 738 | 743 |
| map | 4583 | 3602 | 4.68 | 825 | 830 |
| native | 1627 | 647 | 1.66 | 773 | 778 |
| path | 1675 | 695 | 1.71 | 782 | 786 |
| record | 2136 | 1156 | 2.18 | 812 | 817 |
| variable | 1873 | 893 | 1.91 | 775 | 778 |
| walk | 3235 | 2255 | 3.30 | 806 | 812 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 724 |  | 717 |  |
| 2 | 782 | 57.9 | 769 | 52.9 |
| 4 | 892 | 55.9 | 873 | 52.0 |
| 8 | 1113 | 55.5 | 1063 | 49.5 |
| 16 | 1539 | 54.3 | 1445 | 48.5 |
| 32 | 2410 | 54.4 | 2218 | 48.4 |
| 64 | 4160 | 54.5 | 3776 | 48.6 |
| 128 | 7666 | 54.7 | 6948 | 49.1 |
| 256 | 14779 | 55.1 | 13341 | 49.5 |
