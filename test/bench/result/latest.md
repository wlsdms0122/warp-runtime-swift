rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 2048 | 877 | 1.75 |
| closure | 1893 | 722 | 1.62 |
| field | 1367 | 196 | 1.17 |
| keeps | 2357 | 1186 | 2.01 |
| loop | 1171 | 0 | 1.00 |
| native | 1884 | 713 | 1.61 |
| path | 1976 | 805 | 1.69 |
| variable | 2137 | 966 | 1.83 |
