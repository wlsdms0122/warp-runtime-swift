rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 2966 | 1176 | 1.66 |
| closure | 2542 | 752 | 1.42 |
| field | 1990 | 200 | 1.11 |
| keeps | 3832 | 2042 | 2.14 |
| literal | 2606 | 816 | 1.46 |
| loop | 1790 | 0 | 1.00 |
| map | 6869 | 5079 | 3.84 |
| native | 3098 | 1308 | 1.73 |
| path | 2792 | 1002 | 1.56 |
| record | 3983 | 2193 | 2.23 |
| variable | 3351 | 1561 | 1.87 |
| walk | 5687 | 3897 | 3.18 |
