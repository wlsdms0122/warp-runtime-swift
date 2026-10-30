#!/bin/bash
# Writes the `lib/standard` documents of the `warp` submodule into a Swift
# source, so the vocabulary they hold arrives with the library rather than off a
# disk the caller may not have.
#
# The documents are the source; this is a copy of them. `LibraryTests` holds
# the two to being the same text, so a document edited without running this
# is a red test.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
library="$root/warp/lib/standard"
written="$root/Sources/WarpStandard/Library/Library.swift"

{
    echo "//"
    echo "//  Library.swift"
    echo "//  WarpStandard"
    echo "//"
    echo "//  Written by tool/embed-library.sh. Edit warp/lib/standard and run it again."
    echo "//"
    echo ""
    echo "import Foundation"
    echo ""
    echo "// The documents of \`lib/standard\`, as they stand in the \`warp\` submodule."
    echo "enum Library {"
    echo "    static let documents: [String: String] = ["

    files=("$library"/*.warpt)
    last="${files[${#files[@]} - 1]}"

    for file in "${files[@]}"; do
        name="$(basename "$file" .warpt)"
        separator=","
        [ "$file" = "$last" ] && separator=""

        echo "        \"$name\": \"\"\""
        /usr/bin/sed -e 's/\\/\\\\/g' -e 's/"""/\\"\\"\\"/g' -e 's/^/            /' "$file"
        echo "            \"\"\"$separator"
    done

    echo "    ]"
    echo "}"
} > "$written"

echo "$written"
