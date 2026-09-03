rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1769 | 814 | 1.85 |
| closure | 1667 | 712 | 1.75 |
| field | 1137 | 182 | 1.19 |
| keeps | 2091 | 1136 | 2.19 |
| literal | 1598 | 643 | 1.67 |
| loop | 955 | 0 | 1.00 |
| map | 4212 | 3257 | 4.41 |
| native | 1496 | 541 | 1.57 |
| path | 1569 | 615 | 1.64 |
| record | 2120 | 1165 | 2.22 |
| variable | 1734 | 779 | 1.82 |
| walk | 2927 | 1972 | 3.07 |
