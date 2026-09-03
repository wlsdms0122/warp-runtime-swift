rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1803 | 823 | 1.84 |
| closure | 1706 | 727 | 1.74 |
| field | 1156 | 176 | 1.18 |
| keeps | 2044 | 1065 | 2.09 |
| literal | 1746 | 766 | 1.78 |
| loop | 980 | 0 | 1.00 |
| map | 3786 | 2807 | 3.86 |
| native | 1522 | 542 | 1.55 |
| path | 1590 | 611 | 1.62 |
| record | 2115 | 1136 | 2.16 |
| variable | 1752 | 773 | 1.79 |
| walk | 2956 | 1976 | 3.02 |
