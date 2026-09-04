<!-- Measured on warp/name-and-layout. The same machine, minutes apart, gives
main a loop of 975 ns: this branch is about 1.75x slower per round, which is a
regression the ticket has not closed. See plan/ask-owner.md. -->

rounds 1000000, median of 3

| workload | ns/round | minus loop | x loop |
|---|---|---|---|
| call | 2835 | 1129 | 1.66 |
| closure | 2423 | 717 | 1.42 |
| field | 1889 | 183 | 1.11 |
| keeps | 3602 | 1896 | 2.11 |
| literal | 2309 | 603 | 1.35 |
| loop | 1706 | 0 | 1.00 |
| map | 7075 | 5369 | 4.15 |
| native | 2983 | 1276 | 1.75 |
| path | 2639 | 932 | 1.55 |
| record | 4059 | 2352 | 2.38 |
| variable | 3220 | 1514 | 1.89 |
| walk | 5562 | 3856 | 3.26 |
