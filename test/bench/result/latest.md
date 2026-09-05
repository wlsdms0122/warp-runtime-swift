rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1781 | 853 | 1.92 |
| closure | 1631 | 703 | 1.76 |
| field | 1096 | 167 | 1.18 |
| keeps | 2028 | 1100 | 2.18 |
| literal | 1532 | 603 | 1.65 |
| loop | 929 | 0 | 1.00 |
| map | 4297 | 3368 | 4.63 |
| native | 1467 | 538 | 1.58 |
| path | 1572 | 644 | 1.69 |
| record | 2181 | 1253 | 2.35 |
| variable | 1710 | 782 | 1.84 |
| walk | 3023 | 2095 | 3.26 |
