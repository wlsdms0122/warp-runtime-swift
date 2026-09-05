rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1798 | 839 | 1.87 |
| closure | 1664 | 704 | 1.73 |
| field | 1129 | 169 | 1.18 |
| keeps | 2095 | 1135 | 2.18 |
| literal | 1583 | 624 | 1.65 |
| loop | 959 | 0 | 1.00 |
| map | 4295 | 3335 | 4.48 |
| native | 1507 | 548 | 1.57 |
| path | 1571 | 612 | 1.64 |
| record | 2190 | 1231 | 2.28 |
| variable | 1750 | 791 | 1.82 |
| walk | 3026 | 2067 | 3.15 |
