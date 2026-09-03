rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1809 | 833 | 1.85 |
| closure | 1698 | 722 | 1.74 |
| field | 1160 | 184 | 1.19 |
| keeps | 2114 | 1137 | 2.17 |
| literal | 1616 | 640 | 1.66 |
| loop | 976 | 0 | 1.00 |
| map | 4571 | 3595 | 4.68 |
| native | 1524 | 548 | 1.56 |
| path | 1594 | 618 | 1.63 |
| record | 2147 | 1171 | 2.20 |
| variable | 1777 | 801 | 1.82 |
| walk | 2995 | 2019 | 3.07 |
