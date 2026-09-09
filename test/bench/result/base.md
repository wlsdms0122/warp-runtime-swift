rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3329 | 2355 | 3.42 | 774 | 778 |
| call | 1837 | 863 | 1.89 | 740 | 742 |
| closure | 1633 | 659 | 1.68 | 739 | 741 |
| field | 1144 | 170 | 1.17 | 716 | 719 |
| keeps | 2679 | 1705 | 2.75 | 771 | 773 |
| literal | 1582 | 608 | 1.62 | 731 | 731 |
| loop | 974 | 0 | 1.00 | 689 | 691 |
| map | 4595 | 3621 | 4.72 | 773 | 776 |
| native | 1610 | 636 | 1.65 | 723 | 722 |
| path | 1650 | 676 | 1.69 | 725 | 728 |
| record | 2132 | 1158 | 2.19 | 760 | 764 |
| variable | 1867 | 893 | 1.92 | 723 | 726 |
| walk | 3232 | 2258 | 3.32 | 750 | 754 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 663 |  | 659 |  |
| 2 | 722 | 59.0 | 714 | 54.7 |
| 4 | 824 | 53.8 | 805 | 48.6 |
| 8 | 1022 | 51.4 | 980 | 45.8 |
| 16 | 1421 | 50.6 | 1334 | 45.0 |
| 32 | 2241 | 50.9 | 2074 | 45.6 |
| 64 | 3870 | 50.9 | 3518 | 45.4 |
| 128 | 7107 | 50.7 | 6458 | 45.7 |
| 256 | 13928 | 52.0 | 12530 | 46.6 |
