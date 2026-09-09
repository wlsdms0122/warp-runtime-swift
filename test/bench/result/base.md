rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3323 | 2356 | 3.44 | 791 | 796 |
| call | 1813 | 846 | 1.88 | 756 | 759 |
| closure | 1606 | 640 | 1.66 | 762 | 763 |
| field | 1154 | 187 | 1.19 | 742 | 742 |
| keeps | 2669 | 1702 | 2.76 | 796 | 797 |
| literal | 1582 | 615 | 1.64 | 753 | 755 |
| loop | 967 | 0 | 1.00 | 711 | 713 |
| map | 4555 | 3588 | 4.71 | 793 | 797 |
| native | 1618 | 651 | 1.67 | 742 | 745 |
| path | 1662 | 695 | 1.72 | 747 | 750 |
| record | 2110 | 1143 | 2.18 | 776 | 782 |
| variable | 1879 | 912 | 1.94 | 745 | 746 |
| walk | 3218 | 2252 | 3.33 | 769 | 774 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 679 |  | 681 |  |
| 2 | 744 | 64.8 | 731 | 49.9 |
| 4 | 844 | 55.1 | 820 | 46.5 |
| 8 | 1047 | 52.5 | 998 | 45.3 |
| 16 | 1454 | 51.7 | 1361 | 45.4 |
| 32 | 2286 | 51.8 | 2095 | 45.6 |
| 64 | 3936 | 51.7 | 3549 | 45.5 |
| 128 | 7289 | 52.0 | 6546 | 46.2 |
| 256 | 14087 | 52.6 | 12597 | 46.7 |
