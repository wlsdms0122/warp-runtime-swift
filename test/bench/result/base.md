rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3355 | 2383 | 3.45 | 791 | 795 |
| call | 1900 | 928 | 1.95 | 754 | 756 |
| closure | 1665 | 693 | 1.71 | 758 | 760 |
| field | 1187 | 215 | 1.22 | 738 | 740 |
| keeps | 2724 | 1752 | 2.80 | 790 | 791 |
| literal | 1592 | 620 | 1.64 | 748 | 750 |
| loop | 972 | 0 | 1.00 | 707 | 709 |
| map | 4609 | 3637 | 4.74 | 783 | 789 |
| native | 1627 | 655 | 1.67 | 737 | 739 |
| path | 1673 | 701 | 1.72 | 743 | 745 |
| record | 2136 | 1164 | 2.20 | 773 | 775 |
| variable | 1887 | 915 | 1.94 | 738 | 740 |
| walk | 3304 | 2332 | 3.40 | 770 | 774 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 684 |  | 679 |  |
| 2 | 740 | 56.2 | 736 | 56.8 |
| 4 | 868 | 61.4 | 847 | 56.0 |
| 8 | 1054 | 52.9 | 1034 | 50.7 |
| 16 | 1466 | 52.1 | 1377 | 46.5 |
| 32 | 2274 | 51.3 | 2093 | 45.6 |
| 64 | 3942 | 51.7 | 3592 | 46.2 |
| 128 | 7227 | 51.5 | 6520 | 46.0 |
| 256 | 13957 | 52.1 | 12918 | 48.0 |
