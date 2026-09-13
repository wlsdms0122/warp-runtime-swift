rounds 200000, fastest of 3; load, build, baked and once are the fastest of 201; against result/base.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3413 | +1.8% | 3.44 | 187 |  | 594 | -25.8% | 200 | -43.7% |
| call | 1856 | +1.0% | 1.87 | 144 |  | 565 | -26.5% | 179 | -45.5% |
| closure | 1654 | +1.4% | 1.67 | 140 |  | 558 | -27.5% | 176 | -46.2% |
| field | 1166 | +1.2% | 1.18 | 126 |  | 544 | -27.4% | 164 | -47.5% |
| keeps | 2760 | +1.7% | 2.78 | 165 |  | 586 | -26.5% | 196 | -44.8% |
| literal | 1626 | +1.4% | 1.64 | 129 |  | 558 | -27.0% | 172 | -46.7% |
| loop | 992 | +0.6% | 1.00 | 95 |  | 527 | -27.4% | 149 | -48.3% |
| map | 4781 | +4.3% | 4.82 | 167 |  | 583 | -26.8% | 196 | -44.6% |
| native | 1659 | +2.0% | 1.67 | 129 |  | 559 | -25.9% | 171 | -45.6% |
| record | 2171 | +1.2% | 2.19 | 174 |  | 577 | -27.0% | 192 | -44.5% |
| variable | 1923 | +2.5% | 1.94 | 130 |  | 555 | -26.6% | 172 | -45.6% |
| walk | 3281 | +0.7% | 3.31 | 153 |  | 578 | -25.4% | 188 | -44.0% |

building a chain of procedures, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| procedures | spread us | spread each | gathered us | gathered each |
|---|---|---|---|---|
| 1 | 509 |  | 506 |  |
| 2 | 555 | 45.8 | 542 | 35.7 |
| 4 | 621 | 37.5 | 608 | 34.0 |
| 8 | 780 | 38.8 | 729 | 31.9 |
| 16 | 1059 | 36.7 | 969 | 30.8 |
| 32 | 1676 | 37.6 | 1471 | 31.1 |
| 64 | 2866 | 37.4 | 2484 | 31.4 |
| 128 | 5313 | 37.8 | 4600 | 32.2 |
| 256 | 10696 | 39.9 | 8871 | 32.8 |

building 256 procedures that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | compile us | alone us | link us | spread us | x |
|---|---|---|---|---|---|---|
| 1 | 7086 | 5983 | 5988 | 1028 | 7016 | 1.01 |
| 2 | 7135 | 6088 | 5805 | 1015 | 3918 | 1.82 |
| 4 | 7104 | 5989 | 5793 | 1007 | 2456 | 2.89 |
| 8 | 7148 | 6096 | 5863 | 1002 | 1735 | 4.12 |
| 16 | 7170 | 6136 | 5921 | 978 | 1348 | 5.32 |
| 32 | 7332 | 6266 | 6489 | 964 | 1167 | 6.28 |
| 64 | 7547 | 6564 | 7468 | 996 | 1113 | 6.78 |
| 128 | 8050 | 6971 | 9111 | 1057 | 1128 | 7.13 |
| 256 | 8946 | 7727 | 12634 | 1175 | 1224 | 7.31 |
