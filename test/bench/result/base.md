rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3331 | 2361 | 3.43 | 685 | 687 |
| call | 1837 | 867 | 1.89 | 645 | 647 |
| closure | 1615 | 644 | 1.66 | 649 | 650 |
| field | 1161 | 190 | 1.20 | 632 | 632 |
| keeps | 2702 | 1731 | 2.78 | 683 | 683 |
| literal | 1594 | 623 | 1.64 | 642 | 642 |
| loop | 971 | 0 | 1.00 | 604 | 605 |
| map | 4605 | 3634 | 4.74 | 684 | 683 |
| native | 1635 | 664 | 1.68 | 636 | 638 |
| path | 1716 | 746 | 1.77 | 640 | 640 |
| record | 2122 | 1151 | 2.19 | 670 | 670 |
| variable | 1867 | 896 | 1.92 | 636 | 637 |
| walk | 3230 | 2259 | 3.33 | 664 | 662 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 573 |  | 571 |  |
| 2 | 627 | 54.5 | 619 | 48.0 |
| 4 | 724 | 50.6 | 710 | 46.4 |
| 8 | 917 | 49.1 | 884 | 44.6 |
| 16 | 1306 | 48.9 | 1228 | 43.8 |
| 32 | 2098 | 49.2 | 1945 | 44.3 |
| 64 | 3691 | 49.5 | 3388 | 44.7 |
| 128 | 6883 | 49.7 | 6264 | 44.8 |
| 256 | 13396 | 50.3 | 12179 | 45.5 |
