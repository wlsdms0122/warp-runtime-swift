rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3367 | 2383 | 3.42 | 788 | 791 |
| call | 1853 | 868 | 1.88 | 759 | 761 |
| closure | 1634 | 650 | 1.66 | 760 | 762 |
| field | 1162 | 177 | 1.18 | 742 | 741 |
| keeps | 2754 | 1769 | 2.80 | 788 | 789 |
| literal | 1609 | 624 | 1.63 | 750 | 753 |
| loop | 985 | 0 | 1.00 | 715 | 716 |
| map | 4641 | 3657 | 4.71 | 790 | 795 |
| native | 1648 | 664 | 1.67 | 743 | 746 |
| path | 1693 | 708 | 1.72 | 746 | 748 |
| record | 2161 | 1176 | 2.19 | 782 | 786 |
| variable | 1902 | 918 | 1.93 | 748 | 750 |
| walk | 3249 | 2265 | 3.30 | 768 | 772 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 691 |  | 686 |  |
| 2 | 749 | 57.9 | 738 | 52.3 |
| 4 | 849 | 52.5 | 819 | 44.5 |
| 8 | 1043 | 50.2 | 977 | 41.7 |
| 16 | 1444 | 50.2 | 1322 | 42.4 |
| 32 | 2229 | 49.6 | 1993 | 42.2 |
| 64 | 3867 | 50.4 | 3348 | 42.3 |
| 128 | 7138 | 50.8 | 6097 | 42.6 |
| 256 | 14097 | 52.6 | 11954 | 44.2 |
