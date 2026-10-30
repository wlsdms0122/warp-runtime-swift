#!/bin/bash
# Asks every case in each folder given through the probe suite in
# `Tests/WarpConformanceTests/Probe`, and writes the folder's lines, sorted, to
# `<out>/<folder name>.txt`.
#
#   tool/probe.sh <dir>...
#   JOBS=8 PROBE_TIMEOUT=1800 OUT=<out> tool/probe.sh <dir>...
#   PROBE_REWRITE=<dir> tool/probe.sh <dir>
#
# The tests are built once, and each folder is run through the built test
# bundle, JOBS at a time, stopped after PROBE_TIMEOUT seconds. OUT is
# `.build/probe` unless given, and `<out>/raw/` keeps each folder's lines as
# written and its log. PROBE_ONLY and PROBE_REWRITE reach the suite as they are.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jobs_at_once="${JOBS:-8}"
timeout="${PROBE_TIMEOUT:-1800}"
out="${OUT:-$root/.build/probe}"

if (( $# == 0 )); then
    echo "usage: tool/probe.sh <dir>..." >&2
    exit 2
fi

folders=()
for folder in "$@"; do
    folders+=("$(cd "$folder" && pwd)")
done

mkdir -p "$out"
out="$(cd "$out" && pwd)"

echo "building tests in $root"
if ! (cd "$root" && swift build --build-tests > "$out/build.log" 2>&1); then
    tail -30 "$out/build.log"
    echo "build failed (see $out/build.log)" >&2
    exit 1
fi

helper="$(dirname "$(dirname "$(xcrun --find swift)")")/libexec/swift/pm/swiftpm-testing-helper"
platform="$(xcrun --show-sdk-platform-path)/Developer"
bundle="$(cd "$root" && swift build --build-tests --show-bin-path)/WarpConformanceTests.xctest/Contents/MacOS/WarpConformanceTests"

rm -rf "$out/raw"
mkdir -p "$out/raw"

probe() {
    local folder="$1"
    local name
    name="$(basename "$folder")"

    rm -f "$out/raw/$name.raw"

    # perl is a system binary, so it starts without DYLD_* and sets them for
    # the helper itself.
    (
        cd "$out/raw" &&
        PROBE_FRAMEWORK_PATH="$platform/Library/Frameworks" \
        PROBE_LIBRARY_PATH="$platform/usr/lib" \
        PROBE_DIR="$folder" \
        PROBE_OUT="$out/raw/$name.raw" \
        perl -e '$ENV{DYLD_FRAMEWORK_PATH}=$ENV{PROBE_FRAMEWORK_PATH}; $ENV{DYLD_LIBRARY_PATH}=$ENV{PROBE_LIBRARY_PATH}; alarm shift; exec @ARGV' "$timeout" \
            "$helper" --test-bundle-path "$bundle" --testing-library swift-testing --filter 'WarpConformanceTests.ProbeTests' \
            > "$out/raw/$name.log" 2>&1
    ) && status=0 || status=$?
    echo "exit $status" >> "$out/raw/$name.log"
}

echo "probing ${#folders[@]} folders, $jobs_at_once at a time"
for folder in "${folders[@]}"; do
    while (( $(jobs -rp | wc -l) >= jobs_at_once )); do sleep 1; done
    probe "$folder" &
done
wait

for folder in "${folders[@]}"; do
    name="$(basename "$folder")"

    if [[ -f "$out/raw/$name.raw" ]]; then
        LC_ALL=C sort "$out/raw/$name.raw" > "$out/$name.txt"
    else
        : > "$out/$name.txt"
    fi

    lines="$(wc -l < "$out/$name.txt" | tr -d ' ')"
    cases="$(find "$folder" -maxdepth 1 -name '*.test.warpt' -name "${PROBE_ONLY:-}*" | wc -l | tr -d ' ')"
    if [[ "$lines" != "$cases" ]]; then
        echo "$name: $lines lines for $cases cases (see $out/raw/$name.log)"
    fi
done

echo "written to $out"
