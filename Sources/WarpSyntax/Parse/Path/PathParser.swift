//
//  PathParser.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A document's path: what `{ ref: }` reads and `set` writes. A name, then
// `.name` for a field, `[3]` for a literal index and `[i]` for an index read
// from a name. `?.` and `?[` read an absence as null.
public struct PathParser: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func parse(_ text: String) throws -> Path {
        var segments: [PathSegment] = []
        var buffer = ""
        var depth = 0

        // Whether the segment being read was reached through `?.`. The `?` is
        // written at the end of the piece before the dot, so it is carried from
        // one flush to the next.
        var optional = false

        // Whether a dot has promised a name it has not delivered yet. An empty
        // segment is a path the author never wrote, so a dot with nothing after
        // it (another dot, a bracket, the end) is refused rather than silently
        // dropped.
        var expectsKey = false

        @discardableResult
        func flushKey() throws -> Bool {
            // What the author wrote, kept whole. A refusal quotes their
            // spelling, not a peeled copy of it.
            let written = buffer.trimmingCharacters(in: Path.whiteSpace)
            var key = written

            buffer = ""

            // A trailing `?` belongs to the dot after it: `a?.b` reads b
            // optionally. It is peeled here so the key keeps its own spelling.
            var next = false

            if key.hasSuffix("?") {
                // Trimmed again, because the `?` may have held a space off the
                // name's end. `b ?` names `b`, not `b `.
                key = String(key.dropLast()).trimmingCharacters(in: Path.whiteSpace)
                next = true
            }

            guard !key.contains("?") else {
                throw PathSyntaxError(
                    "'\(written)'. `?` is written once, at the end of a"
                        + " segment, as `?.`"
                )
            }

            var appended = false

            if key.isEmpty {
                // A pending `?.` points at this segment, and an empty one is
                // nothing to point at.
                guard !optional || next else {
                    throw PathSyntaxError(
                        "`?.` marks the segment after it, and nothing is"
                            + " written there"
                    )
                }
            } else {
                segments.append(.key(try name(key), optional: optional))
                optional = false
                expectsKey = false
                appended = true
            }

            if next {
                guard !optional else {
                    throw PathSyntaxError(
                        "`?` twice in a row marks nothing. Write one `?.`"
                    )
                }

                optional = true
            }

            return appended
        }

        for character in text {
            switch character {
            case "[":
                if depth == 0 {
                    try flushKey()

                    guard !expectsKey else {
                        throw PathSyntaxError(
                            "a dot is followed by a name, and `[` follows this one"
                        )
                    }
                }

                depth += 1
                buffer.append(character)

            case "]":
                guard depth > 0 else {
                    throw PathSyntaxError("`]` closes no `[`")
                }

                depth -= 1
                buffer.append(character)

                if depth == 0 {
                    // A `?` carried to a bracket is the author's `?[`. The same
                    // mark `?.` puts on a name, on an index instead.
                    segments.append(try indexSegment(
                        buffer.trimmingCharacters(in: Path.whiteSpace),
                        optional: optional
                    ))
                    optional = false
                    buffer = ""
                }

            case "." where depth == 0:
                let appended = try flushKey()

                // A dot follows a segment. The one state that says so is
                // `expectsKey`: a previous dot still waiting for its name means
                // the segment this dot closes is empty (however many dots in a
                // row, wherever they stand) and a dot at the very head has
                // nothing before it at all.
                guard !expectsKey else {
                    throw PathSyntaxError(
                        "a dot is written between segments, and nothing"
                            + " stands before this one"
                    )
                }

                if !appended, !optional, segments.isEmpty {
                    throw PathSyntaxError(
                        "a dot is written between segments, and nothing"
                            + " stands before this one"
                    )
                }

                expectsKey = true

            default:
                buffer.append(character)
            }
        }

        guard depth == 0 else {
            throw PathSyntaxError("the path ends inside `[`, and a `[` is closed by `]`")
        }

        try flushKey()

        guard !optional else {
            throw PathSyntaxError(
                "the path ends on `?`. `?.` marks the segment after it,"
                    + " and nothing follows"
            )
        }

        guard !expectsKey else {
            throw PathSyntaxError(
                "the path ends on a dot, and a dot is followed by a name"
            )
        }

        guard !segments.isEmpty else {
            throw PathSyntaxError("empty reference path")
        }

        return Path(segments)
    }

    // MARK: - Private
    // A segment's spelling as the name it stands for, refused in this
    // parser's own terms.
    private func name(_ spelling: String) throws -> Name {
        do {
            return try Name(spelling)
        } catch {
            throw PathSyntaxError("\(error)")
        }
    }

    // `[3]` is a literal index; `[i]` and `[${i}]` are index references; an empty
    // `[]` is an author mistake refused at the load, not carried into the model.
    private func indexSegment(_ bracketed: String, optional: Bool) throws -> PathSegment {
        var inner = String(bracketed.dropFirst().dropLast())
            .trimmingCharacters(in: Path.whiteSpace)

        if inner.hasPrefix("${"), inner.hasSuffix("}") {
            inner = String(inner.dropFirst(2).dropLast())
                .trimmingCharacters(in: Path.whiteSpace)
        }

        if let literal = Int(inner) {
            return .index(literal, optional: optional)
        }

        guard !inner.isEmpty else {
            throw PathSyntaxError("empty index segment '[]' in reference path")
        }

        // Digits are a whole number however many there are, and never a name.
        let digits = inner.first.map { sign in "+-".contains(sign) } == true ? inner.dropFirst() : Substring(inner)

        guard digits.isEmpty || !digits.allSatisfy({ digit in ("0"..."9").contains(digit) }) else {
            throw PathSyntaxError("index segment '[\(inner)]' is a whole number past what an Int holds, and so no position")
        }

        return .indexRef(try parse(inner), optional: optional)
    }
}
