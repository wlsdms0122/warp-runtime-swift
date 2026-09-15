#!/bin/bash
# Writes the release number beside the commit it was built from, the way a
# compiler's build system does it: the number is edited by a person in
# `version`, the commit comes from git, and nobody types the whole string.
#
# Run it where a release is cut. A working tree that is not a release keeps
# whatever the last run wrote, which is the number alone.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release="$(cat "$root/version")"
commit="$(git -C "$root" rev-parse --short HEAD)"
stamped="warp-swift $release ($commit)"

/usr/bin/sed -i '' \
    -E "s|public static let runtime = \".*\"|public static let runtime = \"$stamped\"|" \
    "$root/Sources/Warp/Building/Compiled.swift"

echo "$stamped"
