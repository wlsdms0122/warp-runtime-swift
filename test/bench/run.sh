#!/bin/sh
# Builds the bench in release and runs it. Arguments pass through:
# `run.sh [rounds] [repeats] [--against <table>]`. The table lands in
# result/latest.md.
#
# Comparing two builds, without the reader doing the arithmetic:
#   ./run.sh 200000 5 && cp result/latest.md result/base.md
#   <change the source, or check out the other revision>
#   ./run.sh 200000 5 --against result/base.md
# The second run reports how far each figure moved. Keep the two runs back to
# back on a quiet machine: the figures are the fastest sample, so anything else
# running only ever makes a run look slower.
set -e
cd "$(dirname "$0")"
swift build -c release --package-path . >/dev/null
.build/release/WarpBench "$@" | tee result/latest.md
