//
//  TemplateParser.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// The template a notation's `{ format: }` writes: text with `${path}`
// placeholders and `$$` for a literal `$`. What a placeholder holds is a
// document's path.
public struct TemplateParser: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

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

                    segments.append(.ref(path: try PathParser().parse(String(inner))))
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
