rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 2863 | 1161 | 1.68 |
| closure | 2459 | 757 | 1.45 |
| field | 1896 | 194 | 1.11 |
| keeps | 3607 | 1905 | 2.12 |
| literal | 2445 | 743 | 1.44 |
| loop | 1702 | 0 | 1.00 |
| map | 6486 | 4785 | 3.81 |
| native | 2958 | 1256 | 1.74 |
| path | 2614 | 912 | 1.54 |
| record | 3827 | 2126 | 2.25 |
| variable | 3180 | 1478 | 1.87 |
| walk | 5464 | 3763 | 3.21 |
