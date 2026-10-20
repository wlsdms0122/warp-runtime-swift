//
//  PathParser.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A document's path: what `{ ref: }` reads and `set` writes. A name, then
// `.name` for a field, and `[3]`, `["a"]` or `[i]` for what a list or a map
// holds at a whole number, a text or a value read from a name. `?.` and `?[`
// read an absence as null. A path between brackets is one deeper than the
// path around it, and a path nests no deeper than a document may, counted on
// from the containers around its string.
struct PathParser: Sendable {
    // MARK: - Property
    private static let deeper = "the path nests deeper than a document may, \(Value.nestingBound) levels: the containers"
        + " around its string count, and a path between brackets is one level deeper than the path around it"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // `depth` is how many containers stand around the string the path is
    // written in.
    func parse(_ text: String, at depth: Int = 0) throws -> Path {
        return try path(text, depth: depth)
    }

    // MARK: - Private
    // Only the reading of a reference walks deeper, so a level of the walk
    // holds this and `segment(_:depth:)`, and the scan is done before it.
    private func path(_ text: String, depth: Int) throws -> Path {
        guard depth <= Value.nestingBound else {
            throw PathSyntaxError(Self.deeper)
        }

        return Path(try scan(text).map { scanned in try segment(scanned, depth: depth) })
    }

    private func segment(_ scanned: ScannedSegment, depth: Int) throws -> PathSegment {
        switch scanned {
        case let .read(segment):
            return segment

        case let .reference(text, optional):
            return .indexRef(try path(text, depth: depth + 1), optional: optional)
        }
    }

    private func scan(_ text: String) throws -> [ScannedSegment] {
        var segments: [ScannedSegment] = []
        var buffer = ""
        var brackets = 0

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
                segments.append(.read(.name(try name(key), optional: optional)))
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

        // Whether a text between the brackets is open, and whether the
        // character before was its backslash. Inside one, every character is
        // the text's: a bracket or a dot spells nothing.
        var quoted = false
        var escaped = false

        for character in text {
            if quoted {
                buffer.append(character)

                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    quoted = false
                }

                continue
            }

            switch character {
            case "\"" where brackets > 0:
                quoted = true
                buffer.append(character)

            case "[":
                if brackets == 0 {
                    try flushKey()

                    guard !expectsKey else {
                        throw PathSyntaxError(
                            "a dot is followed by a name, and `[` follows this one"
                        )
                    }
                }

                brackets += 1
                buffer.append(character)

            case "]":
                guard brackets > 0 else {
                    throw PathSyntaxError("`]` closes no `[`")
                }

                brackets -= 1
                buffer.append(character)

                if brackets == 0 {
                    // A `?` carried to a bracket is the author's `?[`. The same
                    // mark `?.` puts on a name, on an index instead.
                    segments.append(try indexSegment(
                        buffer.trimmingCharacters(in: Path.whiteSpace),
                        optional: optional
                    ))
                    optional = false
                    buffer = ""
                }

            case "." where brackets == 0:
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

        guard !quoted else {
            throw PathSyntaxError("the path ends inside a text, and a text is closed by `\"`")
        }

        guard brackets == 0 else {
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

        return segments
    }

    // A segment's spelling as the name it stands for, refused in this
    // parser's own terms.
    private func name(_ spelling: String) throws -> Name {
        do {
            return try Name(spelling)
        } catch {
            throw PathSyntaxError("\(error)")
        }
    }

    // `[3]` and `["a"]` are written values; `[i]` and `[${i}]` are index
    // references; an empty `[]` refuses.
    private func indexSegment(_ bracketed: String, optional: Bool) throws -> ScannedSegment {
        let inner = String(bracketed.dropFirst().dropLast()).trimmingCharacters(in: Path.whiteSpace)

        if let written = try written(inner) {
            return .read(.index(written, optional: optional))
        }

        return .reference(try reference(inner), optional: optional)
    }

    // The value written between the brackets, or nil where they hold a path.
    private func written(_ inner: String) throws -> Value? {
        if inner.hasPrefix("\"") {
            return .string(try text(inner))
        }

        return Int(peeled(inner)).map(Value.int)
    }

    // The path written between the brackets, where they hold no value.
    private func reference(_ inner: String) throws -> String {
        let path = peeled(inner)

        guard !path.isEmpty else {
            throw PathSyntaxError("empty index segment '[]' in reference path")
        }

        // Digits are a whole number however many there are, and never a name.
        let digits = path.first.map { sign in "+-".contains(sign) } == true ? path.dropFirst() : Substring(path)

        guard digits.isEmpty || !digits.allSatisfy({ digit in ("0"..."9").contains(digit) }) else {
            throw PathSyntaxError("index segment '[\(path)]' is a whole number past what an Int holds, and so no position")
        }

        return path
    }

    // What stands between the brackets, out of the `${…}` it may be written in.
    private func peeled(_ inner: String) -> String {
        guard inner.hasPrefix("${"), inner.hasSuffix("}") else { return inner }

        return String(inner.dropFirst(2).dropLast()).trimmingCharacters(in: Path.whiteSpace)
    }

    // A text between double quotes: `\"` is a quote and `\\` a backslash,
    // every other character stands for itself, and the closing quote ends
    // what stands between the brackets. The walk over the path closed it.
    private func text(_ quoted: String) throws -> String {
        var text = ""
        var escaped = false
        var closed = false

        for character in quoted.dropFirst() {
            guard !closed else {
                throw PathSyntaxError(
                    "\(quoted) holds more than a text. A text between the brackets ends at its closing quote"
                )
            }

            if escaped {
                guard character == "\"" || character == "\\" else {
                    throw PathSyntaxError(
                        "`\\\(character)` in \(quoted) is no escape. Inside the quotes `\\\"`"
                            + " is a quote and `\\\\` a backslash"
                    )
                }

                text.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                closed = true
            } else {
                text.append(character)
            }
        }

        return text
    }
}
