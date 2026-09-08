rounds 200000, fastest of 5; link and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | link us | moved |
|---|---|---|---|---|---|
| box | 3357 | +3.0% | 3.40 | 659 | +11.2% |
| call | 1815 | +2.0% | 1.84 | 642 | +13.2% |
| closure | 1638 | +2.4% | 1.66 | 638 | +12.9% |
| field | 1142 | +1.9% | 1.16 | 615 | +11.5% |
| keeps | 2683 | +1.2% | 2.72 | 663 | +12.4% |
| literal | 1601 | +2.0% | 1.62 | 636 | +13.5% |
| loop | 987 | +3.7% | 1.00 | 608 | +13.1% |
| map | 4587 | +2.1% | 4.65 | 675 | +12.1% |
| native | 1649 | +4.4% | 1.67 | 618 | +11.0% |
| path | 1694 | +4.9% | 1.72 | 624 | +11.2% |
| record | 2195 | +3.6% | 2.22 | 655 | +12.2% |
| variable | 1868 | +2.4% | 1.89 | 620 | +11.6% |
| walk | 3288 | +4.7% | 3.33 | 661 | +14.3% |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 558 |  | 558 |  |
| 2 | 615 | 56.4 | 604 | 46.0 |
| 4 | 702 | 48.0 | 697 | 46.3 |
| 8 | 893 | 47.9 | 855 | 42.4 |
| 16 | 1266 | 47.2 | 1190 | 42.1 |
| 32 | 2010 | 46.8 | 1865 | 42.1 |
| 64 | 3560 | 47.6 | 3249 | 42.7 |
| 128 | 6578 | 47.4 | 6028 | 43.1 |
| 256 | 12962 | 48.6 | 11841 | 44.2 |
