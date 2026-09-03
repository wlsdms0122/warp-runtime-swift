rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 1911 | 846 | 1.80 |
| closure | 1815 | 751 | 1.71 |
| field | 1259 | 195 | 1.18 |
| keeps | 2185 | 1121 | 2.05 |
| literal | 1904 | 840 | 1.79 |
| loop | 1064 | 0 | 1.00 |
| map | 3955 | 2891 | 3.72 |
| native | 1607 | 543 | 1.51 |
| path | 1690 | 626 | 1.59 |
| record | 2228 | 1164 | 2.09 |
| variable | 1843 | 779 | 1.73 |
| walk | 3115 | 2051 | 2.93 |
