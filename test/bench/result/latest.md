rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| call | 1802 | 832 | 1.86 | 403 | 404 |
| closure | 1610 | 639 | 1.66 | 399 | 400 |
| field | 1187 | 216 | 1.22 | 391 | 390 |
| keeps | 2693 | 1723 | 2.77 | 417 | 417 |
| literal | 1641 | 671 | 1.69 | 399 | 398 |
| loop | 971 | 0 | 1.00 | 376 | 374 |
| map | 4432 | 3461 | 4.57 | 420 | 420 |
| native | 1524 | 554 | 1.57 | 394 | 391 |
| path | 1584 | 613 | 1.63 | 393 | 392 |
| record | 2155 | 1184 | 2.22 | 413 | 413 |
| variable | 1764 | 794 | 1.82 | 397 | 394 |
| walk | 3053 | 2082 | 3.15 | 409 | 412 |
