rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1837 | 858 | 1.88 |
| closure | 1707 | 728 | 1.74 |
| field | 1153 | 173 | 1.18 |
| keeps | 2072 | 1092 | 2.11 |
| literal | 1595 | 615 | 1.63 |
| loop | 980 | 0 | 1.00 |
| map | 4345 | 3366 | 4.44 |
| native | 1533 | 553 | 1.56 |
| path | 1589 | 610 | 1.62 |
| record | 2246 | 1266 | 2.29 |
| variable | 1815 | 835 | 1.85 |
| walk | 3057 | 2077 | 3.12 |
