rounds 200000, fastest of 5; load, build, baked and once are the fastest of 201; against /private/tmp/claude-501/-Users-jsilver-Developer-project-agent-jineun-bot-bot/32326910-aa23-4122-86d9-114c1bedc3a8/scratchpad/before3.md

| workload | ns/round | moved | x loop | load us | moved | build us | moved | baked us | moved |
|---|---|---|---|---|---|---|---|---|---|
| box | 3373 | +2.2% | 3.45 | 184 | -1.2% | 601 | -0.4% | 239 | -15.6% |
| call | 1832 | +1.4% | 1.87 | 141 | -1.4% | 578 | -0.3% | 222 | -15.7% |
| closure | 1611 | +0.8% | 1.65 | 140 | -0.2% | 578 | -0.3% | 221 | -15.6% |
| field | 1156 | +1.2% | 1.18 | 125 | +1.8% | 563 | +0.0% | 207 | -17.4% |
| keeps | 2716 | +1.8% | 2.78 | 163 | -0.1% | 598 | -0.3% | 238 | -15.2% |
| literal | 1577 | -0.2% | 1.61 | 127 | -2.1% | 569 | -0.7% | 213 | -17.0% |
| loop | 978 | +0.8% | 1.00 | 96 | -1.7% | 546 | -0.8% | 194 | -18.0% |
| map | 4626 | +0.5% | 4.73 | 167 | -0.5% | 601 | -0.5% | 239 | -15.3% |
| native | 1632 | -0.5% | 1.67 | 127 | -1.0% | 567 | -0.6% | 211 | -17.3% |
| path | 1693 | +1.9% | 1.73 | 127 | -1.4% | 566 | -0.4% | 212 | -16.6% |
| record | 2138 | +2.2% | 2.19 | 172 | -2.4% | 592 | -0.9% | 235 | -14.7% |
| variable | 1895 | -1.1% | 1.94 | 128 | -0.8% | 568 | -0.8% | 212 | -16.8% |
| walk | 3257 | -1.6% | 3.33 | 151 | -5.3% | 584 | -3.9% | 229 | -18.3% |

building a chain of words, each calling the one in front of it; spread one to a document and gathered into one; fastest of 201

| words | spread us | spread each | gathered us | gathered each | spread moved | gathered moved |
|---|---|---|---|---|---|---|
| 1 | 523 |  | 519 |  | -7.3% | -6.0% |
| 2 | 564 | 41.3 | 554 | 34.5 | -5.2% | -0.8% |
| 4 | 641 | 39.5 | 615 | 31.9 | -1.0% | -2.9% |
| 8 | 792 | 38.5 | 734 | 30.7 | -0.9% | -0.7% |
| 16 | 1092 | 38.0 | 972 | 30.2 | -1.3% | -1.3% |
| 32 | 1698 | 37.9 | 1477 | 30.9 | -1.9% | -2.2% |
| 64 | 2932 | 38.2 | 2478 | 31.1 | -0.3% | -0.4% |
| 128 | 5407 | 38.5 | 4495 | 31.3 | -0.8% | -1.1% |
| 256 | 10494 | 39.1 | 8693 | 32.1 | -0.3% | -1.9% |

building 256 words that call nothing, dealt into documents, against a vocabulary compiled once; fastest of 201

`alone` is the documents compiled one at a time rather than together. `spread` is one document's share of that plus the link, which is what the row costs on as many cores as it has documents and nothing charged for handing them out; `x` is `build` over it.

| documents | build us | moved | compile us | moved | alone us | moved | link us | moved | spread us | x |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 6953 | -1.3% | 5909 | -1.5% | 5918 | -1.5% | 1011 | +0.0% | 6929 | 1.00 |
| 2 | 6967 | -0.9% | 5925 | -1.1% | 5774 | -2.2% | 1001 | +0.0% | 3888 | 1.79 |
| 4 | 6972 | -1.0% | 5938 | -1.2% | 5795 | -3.8% | 999 | +0.4% | 2448 | 2.85 |
| 8 | 7000 | -1.0% | 5984 | -1.2% | 6000 | -5.8% | 996 | +0.4% | 1746 | 4.01 |
| 16 | 7008 | -1.0% | 6021 | -0.8% | 6417 | -9.7% | 972 | +0.6% | 1373 | 5.10 |
| 32 | 7134 | -0.7% | 6133 | -0.9% | 7461 | -14.8% | 973 | +0.4% | 1206 | 5.91 |
| 64 | 7370 | -1.1% | 6360 | -1.4% | 9557 | -22.6% | 1000 | +0.8% | 1149 | 6.41 |
| 128 | 7801 | -0.8% | 6699 | -0.6% | 13405 | -27.7% | 1068 | +0.7% | 1173 | 6.65 |
| 256 | 8507 | -0.3% | 7238 | -0.8% | 21268 | -33.0% | 1201 | +1.0% | 1284 | 6.62 |
