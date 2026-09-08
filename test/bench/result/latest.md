rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3207 | -1.6% | 3.44 | 674 | +13.7% |
| call | 1766 | -0.8% | 1.89 | 644 | +13.6% |
| closure | 1563 | -2.3% | 1.67 | 644 | +14.0% |
| field | 1115 | -0.5% | 1.20 | 628 | +13.7% |
| keeps | 2589 | -2.4% | 2.77 | 677 | +14.8% |
| literal | 1537 | -2.1% | 1.65 | 638 | +14.0% |
| loop | 933 | -2.0% | 1.00 | 601 | +12.0% |
| map | 4449 | -0.9% | 4.77 | 678 | +12.7% |
| native | 1550 | -1.9% | 1.66 | 632 | +13.4% |
| path | 1619 | +0.3% | 1.73 | 636 | +13.4% |
| record | 2056 | -2.9% | 2.20 | 663 | +13.5% |
| variable | 1792 | -1.8% | 1.92 | 630 | +13.3% |
| walk | 3137 | -0.1% | 3.36 | 657 | +13.6% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 564 |  | 561 |  |
| 2 | 621 | 56.8 | 607 | 45.7 |
| 4 | 718 | 51.3 | 696 | 45.1 |
| 8 | 920 | 50.9 | 863 | 43.1 |
| 16 | 1326 | 50.8 | 1192 | 42.0 |
| 32 | 2180 | 52.1 | 1864 | 42.0 |
| 64 | 4060 | 55.5 | 3228 | 42.3 |
| 128 | 8421 | 61.9 | 5982 | 42.7 |
| 256 | 19875 | 75.7 | 11616 | 43.4 |
