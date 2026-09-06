rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| call | 1750 | 834 | 1.91 | 405 | 406 |
| closure | 1552 | 636 | 1.69 | 402 | 404 |
| field | 1086 | 169 | 1.18 | 394 | 396 |
| keeps | 2568 | 1652 | 2.80 | 421 | 423 |
| literal | 1522 | 605 | 1.66 | 398 | 401 |
| loop | 917 | 0 | 1.00 | 380 | 380 |
| map | 4263 | 3347 | 4.65 | 423 | 427 |
| native | 1466 | 549 | 1.60 | 396 | 396 |
| path | 1532 | 615 | 1.67 | 395 | 398 |
| record | 2055 | 1138 | 2.24 | 416 | 420 |
| variable | 1709 | 792 | 1.86 | 397 | 399 |
| walk | 3032 | 2115 | 3.31 | 410 | 414 |
