rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3279 | 2317 | 3.41 | 831 | 837 |
| call | 1799 | 837 | 1.87 | 796 | 797 |
| closure | 1594 | 631 | 1.66 | 796 | 796 |
| field | 1135 | 173 | 1.18 | 775 | 774 |
| keeps | 2698 | 1735 | 2.80 | 831 | 831 |
| literal | 1562 | 600 | 1.62 | 788 | 788 |
| loop | 963 | 0 | 1.00 | 746 | 747 |
| map | 4545 | 3582 | 4.72 | 830 | 832 |
| native | 1593 | 631 | 1.66 | 778 | 778 |
| path | 1653 | 690 | 1.72 | 785 | 784 |
| record | 2121 | 1158 | 2.20 | 818 | 821 |
| variable | 1841 | 878 | 1.91 | 778 | 781 |
| walk | 3219 | 2256 | 3.34 | 805 | 807 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 715 |  | 712 |  |
| 2 | 779 | 63.9 | 767 | 55.1 |
| 4 | 884 | 56.2 | 865 | 50.9 |
| 8 | 1102 | 55.3 | 1051 | 48.3 |
| 16 | 1535 | 54.6 | 1435 | 48.2 |
| 32 | 2396 | 54.2 | 2206 | 48.2 |
| 64 | 4157 | 54.6 | 3773 | 48.6 |
| 128 | 7635 | 54.5 | 6909 | 48.8 |
| 256 | 14846 | 55.4 | 13345 | 49.5 |
