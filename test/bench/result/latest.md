rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1795 | 835 | 1.87 |
| closure | 1666 | 707 | 1.74 |
| field | 1128 | 168 | 1.18 |
| keeps | 2062 | 1103 | 2.15 |
| literal | 1563 | 604 | 1.63 |
| loop | 959 | 0 | 1.00 |
| map | 4315 | 3355 | 4.50 |
| native | 1519 | 560 | 1.58 |
| path | 1571 | 612 | 1.64 |
| record | 2199 | 1239 | 2.29 |
| variable | 1751 | 792 | 1.83 |
| walk | 3040 | 2081 | 3.17 |
