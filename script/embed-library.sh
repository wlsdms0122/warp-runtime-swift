#!/bin/bash
# Writes the shared `lib/std` documents into a Swift source, so the vocabulary
# they hold arrives with the library rather than off a disk the caller may not
# have.
#
# The documents are the source; this is a copy of them. `LibraryTests` holds
# the two to being the same bytes, so a document edited without running this
# is a red test rather than a runtime that quietly ships the old one.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
library="$root/../../lib/std"
written="$root/Sources/WarpStandard/Library/Library.swift"

{
    echo "//"
    echo "//  Library.swift"
    echo "//  WarpStandard"
    echo "//"
    echo "//  Written by script/embed-library.sh. Edit lib/std and run it again."
    echo "//"
    echo ""
    echo "import Foundation"
    echo ""
    echo "// The documents of \`lib/std\`, as they stand in the repository."
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
