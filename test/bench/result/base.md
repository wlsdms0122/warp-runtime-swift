rounds 200000, fastest of 3; build and once are the fastest of 201

| workload | ns/round | minus loop | x loop | build us | baked us | once us |
|---|---|---|---|---|---|---|
| box | 3353 | 2367 | 3.40 | 800 | 355 | 811 |
| call | 1837 | 851 | 1.86 | 768 | 328 | 779 |
| closure | 1630 | 645 | 1.65 | 770 | 327 | 776 |
| field | 1152 | 167 | 1.17 | 750 | 312 | 759 |
| keeps | 2713 | 1728 | 2.75 | 798 | 356 | 805 |
| literal | 1603 | 618 | 1.63 | 764 | 322 | 771 |
| loop | 986 | 0 | 1.00 | 726 | 289 | 734 |
| map | 4583 | 3597 | 4.65 | 797 | 354 | 809 |
| native | 1626 | 640 | 1.65 | 754 | 314 | 762 |
| path | 1687 | 701 | 1.71 | 757 | 319 | 768 |
| record | 2146 | 1160 | 2.18 | 790 | 347 | 800 |
| variable | 1875 | 890 | 1.90 | 756 | 316 | 765 |
| walk | 3258 | 2272 | 3.31 | 774 | 336 | 789 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 701 |  | 701 |  |
| 2 | 760 | 58.8 | 748 | 47.9 |
| 4 | 858 | 52.4 | 828 | 42.6 |
| 8 | 1056 | 50.6 | 985 | 40.7 |
| 16 | 1457 | 50.4 | 1324 | 41.6 |
| 32 | 2273 | 50.7 | 2018 | 42.5 |
| 64 | 3911 | 50.9 | 3407 | 43.0 |
| 128 | 7203 | 51.2 | 6181 | 43.2 |
| 256 | 13937 | 51.9 | 11870 | 43.8 |
