rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| call | 1809 | 843 | 1.87 | 440 | 441 |
| closure | 1609 | 642 | 1.66 | 435 | 434 |
| field | 1185 | 218 | 1.23 | 427 | 427 |
| keeps | 2698 | 1731 | 2.79 | 452 | 454 |
| literal | 1641 | 674 | 1.70 | 432 | 432 |
| loop | 967 | 0 | 1.00 | 412 | 411 |
| map | 4373 | 3406 | 4.52 | 458 | 460 |
| native | 1511 | 544 | 1.56 | 428 | 429 |
| path | 1588 | 622 | 1.64 | 426 | 426 |
| record | 2171 | 1204 | 2.25 | 449 | 451 |
| variable | 1761 | 794 | 1.82 | 431 | 431 |
| walk | 3039 | 2072 | 3.14 | 444 | 446 |
