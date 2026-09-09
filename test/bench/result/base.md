rounds 200000, fastest of 5; link and once are the fastest of 201

| workload | ns/round | minus loop | x loop | link us | once us |
|---|---|---|---|---|---|
| box | 3283 | 2314 | 3.39 | 744 | 746 |
| call | 1803 | 834 | 1.86 | 704 | 706 |
| closure | 1587 | 617 | 1.64 | 708 | 709 |
| field | 1144 | 175 | 1.18 | 686 | 689 |
| keeps | 2653 | 1684 | 2.74 | 742 | 741 |
| literal | 1567 | 598 | 1.62 | 695 | 698 |
| loop | 969 | 0 | 1.00 | 658 | 660 |
| map | 4613 | 3643 | 4.76 | 736 | 743 |
| native | 1619 | 650 | 1.67 | 685 | 688 |
| path | 1648 | 679 | 1.70 | 693 | 697 |
| record | 2113 | 1143 | 2.18 | 723 | 725 |
| variable | 1865 | 895 | 1.92 | 690 | 693 |
| walk | 3206 | 2236 | 3.31 | 716 | 722 |

linking a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 630 |  | 630 |  |
| 2 | 688 | 58.3 | 682 | 52.2 |
| 4 | 788 | 52.7 | 771 | 47.0 |
| 8 | 984 | 50.6 | 947 | 45.2 |
| 16 | 1380 | 50.0 | 1298 | 44.6 |
| 32 | 2176 | 49.9 | 2012 | 44.6 |
| 64 | 3775 | 49.9 | 3467 | 45.0 |
| 128 | 6988 | 50.1 | 6364 | 45.2 |
| 256 | 13628 | 51.0 | 12378 | 46.1 |
