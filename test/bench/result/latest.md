rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1767 | 807 | 1.84 |
| closure | 1685 | 726 | 1.76 |
| field | 1137 | 178 | 1.19 |
| keeps | 2016 | 1057 | 2.10 |
| literal | 1716 | 756 | 1.79 |
| loop | 960 | 0 | 1.00 |
| map | 3785 | 2826 | 3.95 |
| native | 1460 | 501 | 1.52 |
| path | 1575 | 616 | 1.64 |
| record | 2073 | 1114 | 2.16 |
| variable | 1703 | 744 | 1.78 |
| walk | 2972 | 2012 | 3.10 |
