#!/bin/sh
# Builds the bench in release and runs it. Arguments pass through:
# `run.sh [rounds] [repeats]`. The table lands in result/latest.md.
set -e
cd "$(dirname "$0")"
swift build -c release --package-path . >/dev/null
.build/release/WarpBench "$@" | tee result/latest.md
