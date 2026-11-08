#!/bin/bash
# Builds the bench in release and runs it. Arguments pass through:
# `run.sh [rounds] [repeats] [--against <table>]`. The table lands in
# result/latest.md, which the repository does not keep: a figure is one
# machine's on one day, and a table taken elsewhere is not one this run moved
# from.
#
# Comparing two builds, without the reader doing the arithmetic:
#   ./run.sh 200000 5 && cp result/latest.md result/base.md
#   <change the source, or check out the other revision>
#   ./run.sh 200000 5 --against result/base.md
# The second run reports how far each figure moved. Keep the two runs back to
# back on a quiet machine: the figures are the fastest sample, so anything else
# running only ever makes a run look slower.
set -e
# The figures go through `tee`, whose exit status is the pipeline's. Without
# this a bench that dies mid-run ends quietly and leaves the last table in
# place, which then reads as a measurement of whatever is checked out now.
set -o pipefail
cd "$(dirname "$0")"
mkdir -p result
swift build -c release --package-path . >/dev/null
.build/release/WarpBench "$@" | tee result/latest.md
