#!/bin/sh
# tool/feature.sh [programs.tsv]
#
# Runs every program of the feature table through warpx, one line each: the
# name, `ok` or `DIFFER`, what the program did, and the answer or the refusal.
# A program is ok when it did what the table expects and, when it answers,
# its objects read back answer the same. Exits 1 when any program differs.
# The table defaults to the specification's, `warp/example/feature`.
cd "$(dirname "$0")/.." || exit 2
table=${1:-../warp/example/feature/programs.tsv}
folder=$(dirname "$table")
bin=${WARPX:-.build/debug/warpx}
[ -x "$bin" ] || { echo "no warpx at $bin: swift build first" >&2; exit 2; }

# An empty column becomes `-`, so a tab-separated read keeps its place.
programs() {
    tail -n +2 "$table" | awk -F'\t' -v OFS='\t' '{ for (i = 1; i <= NF; i++) if ($i == "") $i = "-"; print }'
}

run() {
    programs | while IFS="$(printf '\t')" read -r name documents entry arguments laid expects asks; do
        set --
        for document in $documents; do set -- "$@" "$folder/$document.warpt"; done
        [ "$arguments" = "-" ] || for argument in $arguments; do set -- "$@" --arg "$argument"; done
        [ "$laid" = "in order" ] && set -- "$@" --one-at-a-time

        out=$("$bin" "$entry" "$@" 2>&1)
        first=$(printf '%s\n' "$out" | head -1)
        status=DIFFER

        case "$first" in
        answer:)
            did=answers
            answer=$(printf '%s\n' "$out" | awk '/^answer:/{f=1; next} /^objects/{f=0} f' | tr -d '\n ')
            objects=$(printf '%s\n' "$out" | awk '/^objects:/{f=1; next} /^log:/{f=0} f' | tr -d '\n ')
            detail=$answer
            [ "$answer" = "$objects" ] || detail="straight $answer, objects $objects"
            [ "$did" = "$expects" ] && [ "$answer" = "$objects" ] && status=ok
            ;;
        "refused at the "*)
            did=$(printf '%s' "$first" | sed 's/^refused at the \([a-z]*\).*/refuses at the \1/')
            detail=${first#*: }
            [ "$did" = "$expects" ] && status=ok
            ;;
        *)
            did=broke
            detail=$first
            ;;
        esac

        [ "$did" = "$expects" ] || detail="expected '$expects': $detail"
        printf '%-30s %-6s %-21s %s\n' "$name" "$status" "$did" "$(printf '%s' "$detail" | cut -c1-110)"
    done
}

lines=$(run)

printf '%s\n' "$lines"
printf '%s\n' "$lines" | grep -q ' DIFFER ' && exit 1
exit 0

