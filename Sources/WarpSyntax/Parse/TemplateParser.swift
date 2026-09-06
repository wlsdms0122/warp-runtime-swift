//
//  TemplateParser.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// The template dialect. `${a.b[0].c}` placeholders, `$$` escaping,
// `[i]`/`[${i}]` index references. It lives on exactly two closed surfaces: `{
// format: }` templates and resource file bodies, both rendered against declared
// bindings only. `parseRefPath` additionally spells the path inside `{ ref: }`.
// Procedure values themselves never pass through here. A string in a procedure
// is a literal.
public struct TemplateParser: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() { }

    // MARK: - Public
    public func parse(_ text: String) throws -> [TemplateSegment] {
        var segments: [TemplateSegment] = []
        var index = text.startIndex
        var buffer = ""

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if character == "$", next < text.endIndex, text[next] == "$" {
                buffer.append("$")
                index = text.index(after: next)

                continue
            }

            if character == "$", next < text.endIndex, text[next] == "{" {
                let innerStart = text.index(after: next)

                if let close = matchingBraceClose(text, from: innerStart) {
                    let inner = text[innerStart..<close]

                    if inner.trimmingCharacters(in: .whitespaces).isEmpty {
                        buffer.append(character)
                        index = next

                        continue
                    }

                    if !buffer.isEmpty {
                        segments.append(.text(buffer))
                        buffer = ""
                    }

                    segments.append(.ref(path: try parseRefPath(String(inner))))
                    index = text.index(after: close)

                    continue
                }
            }

            buffer.append(character)
            index = next
        }

        if !buffer.isEmpty { segments.append(.text(buffer)) }

        return segments
    }

    public func parseRefPath(_ inner: String) throws -> [PathSegment] {
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
            let written = buffer.trimmingCharacters(in: .whitespaces)
            var key = written

            buffer = ""

            // A trailing `?` belongs to the dot after it: `a?.b` reads b
            // optionally. It is peeled here so the key keeps its own spelling.
            var next = false

            if key.hasSuffix("?") {
                // Trimmed again, because the `?` may have held a space off the
                // name's end. `b ?` names `b`, not `b `.
                key = String(key.dropLast()).trimmingCharacters(in: .whitespaces)
                next = true
            }

            guard !key.contains("?") else {
                throw TemplateSyntaxError(
                    "'\(written)'. `?` is written once, at the end of a"
                        + " segment, as `?.`"
                )
            }

            var appended = false

            if key.isEmpty {
                // A pending `?.` points at this segment, and an empty one is
                // nothing to point at.
                guard !optional || next else {
                    throw TemplateSyntaxError(
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
                    throw TemplateSyntaxError(
                        "`?` twice in a row marks nothing. Write one `?.`"
                    )
                }

                optional = true
            }

            return appended
        }

        for character in inner {
            switch character {
            case "[":
                if depth == 0 {
                    try flushKey()

                    guard !expectsKey else {
                        throw TemplateSyntaxError(
                            "a dot is followed by a name, and `[` follows this one"
                        )
                    }
                }

                depth += 1
                buffer.append(character)

            case "]":
                depth -= 1
                buffer.append(character)

                if depth == 0 {
                    // A `?` carried to a bracket is the author's `?[`. The same
                    // mark `?.` puts on a name, on an index instead.
                    segments.append(try indexSegment(
                        buffer.trimmingCharacters(in: .whitespaces),
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
                    throw TemplateSyntaxError(
                        "a dot is written between segments, and nothing"
                            + " stands before this one"
                    )
                }

                if !appended, !optional, segments.isEmpty {
                    throw TemplateSyntaxError(
                        "a dot is written between segments, and nothing"
                            + " stands before this one"
                    )
                }

                expectsKey = true

            default:
                buffer.append(character)
            }
        }

        try flushKey()

        guard !optional else {
            throw TemplateSyntaxError(
                "the path ends on `?`. `?.` marks the segment after it,"
                    + " and nothing follows"
            )
        }

        guard !expectsKey else {
            throw TemplateSyntaxError(
                "the path ends on a dot, and a dot is followed by a name"
            )
        }

        guard !segments.isEmpty else {
            throw TemplateSyntaxError("empty reference path")
        }

        // What a mark on the head would claim is the path's own fact, said by
        // the path, whichever spelling wrote it, and wherever a layer judges
        // the same path later.
        if let refusal = segments.markedHead {
            throw TemplateSyntaxError(refusal)
        }

        return segments
    }

    public func render(_ segments: [TemplateSegment]) -> String {
        segments.map { segment -> String in
            switch segment {
            case let .text(text):
                return text.replacingOccurrences(of: "$", with: "$$")

            case let .ref(path):
                return "${" + path.rendered + "}"
            }
        }
        .joined()
    }

    // MARK: - Private
    // A segment's spelling as the name it stands for, said in this parser's
    // own words so an author reading a template's refusal reads one voice.
    private func name(_ spelling: String) throws -> Name {
        do {
            return try Name(spelling)
        } catch {
            throw TemplateSyntaxError("\(error)")
        }
    }

    // `[3]` is a literal index; `[i]` and `[${i}]` are index references; an empty
    // `[]` is an author mistake rejected at parse, not carried into the model.
    private func indexSegment(_ bracketed: String, optional: Bool) throws -> PathSegment {
        var inner = String(bracketed.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)

        if inner.hasPrefix("${"), inner.hasSuffix("}") {
            inner = String(inner.dropFirst(2).dropLast())
                .trimmingCharacters(in: .whitespaces)
        }

        if let literal = Int(inner) { return .index(literal, optional: optional) }

        guard !inner.isEmpty else {
            throw TemplateSyntaxError("empty index segment '[]' in reference path")
        }

        return .indexRef(try parseRefPath(inner), optional: optional)
    }

    private func matchingBraceClose(
        _ text: String,
        from start: String.Index
    ) -> String.Index? {
        var depth = 1
        var index = start
        var inQuotes = false

        while index < text.endIndex {
            let character = text[index]

            if character == "\"" {
                inQuotes.toggle()
            } else if !inQuotes {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1

                    if depth == 0 { return index }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
