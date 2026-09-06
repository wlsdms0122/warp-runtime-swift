rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| call | 1803 | 835 | 1.86 | 408 | 411 |
| closure | 1600 | 632 | 1.65 | 406 | 408 |
| field | 1183 | 215 | 1.22 | 395 | 398 |
| keeps | 2692 | 1724 | 2.78 | 423 | 424 |
| literal | 1635 | 667 | 1.69 | 400 | 400 |
| loop | 968 | 0 | 1.00 | 379 | 378 |
| map | 4399 | 3431 | 4.54 | 424 | 426 |
| native | 1517 | 549 | 1.57 | 399 | 398 |
| path | 1590 | 622 | 1.64 | 397 | 398 |
| record | 2163 | 1195 | 2.23 | 419 | 420 |
| variable | 1765 | 797 | 1.82 | 398 | 399 |
| walk | 3055 | 2087 | 3.16 | 413 | 415 |
