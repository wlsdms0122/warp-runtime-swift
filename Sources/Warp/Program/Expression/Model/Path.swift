//
//  Path.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a reference reads and an assignment writes: a name, then the segments
// that reach into what it holds.
package struct Path: Sendable, Equatable {
    // MARK: - Property
    // What a path's segment is read without at either end: every scalar
    // Unicode gives the White_Space property, a line break included.
    // Foundation's `whitespacesAndNewlines` also holds U+200B, which has no
    // White_Space.
    package static let whiteSpace = CharacterSet(
        (0...0x10FFFF as ClosedRange<UInt32>).lazy
            .compactMap(Unicode.Scalar.init)
            .filter(\.properties.isWhitespace)
    )

    package private(set) var segments: [PathSegment]

    // The canonical textual form. Diagnostics and encoding share one spelling.
    package var rendered: String {
        var rendered = ""

        for segment in segments {
            rendered += spelling(of: segment, first: rendered.isEmpty)
        }

        return rendered
    }

    // What a mark on the head claims, which the load refuses. Nil where the
    // head is written plain. The head is a name a scope holds, not a field
    // that may be absent: there is nothing before it to read past, so the
    // mark has nothing to mean.
    var markedHead: String? {
        guard let first = segments.first, first.optional else { return nil }

        return "\(rendered) marks the head optional, and the head of a path"
            + " is a name a scope holds. `\(first.mark)` expects an absence,"
            + " and a name that holds nothing is a reading gone wrong"
    }

    // What a mark past the head claims where the path is written to, which a
    // write is refused for: a write reads no absence. Nil where no step past
    // the head is marked. Asked by the load of a `set`, and by the build of a
    // path handed in place, which only the slot it lands in says.
    var writtenThroughAbsence: String? {
        guard let marked = segments.indices.dropFirst().first(where: { index in segments[index].optional }) else {
            return nil
        }

        return "\(Path(Array(segments[...marked])).rendered) writes through `\(segments[marked].mark)`, and a write"
            + " reads no absence. Write the whole, or write what is there"
    }

    // The root name this path reads from. Nil when the path doesn't start with
    // a name, which no scope can serve.
    package var head: Name? {
        guard case let .name(head, _)? = segments.first else { return nil }

        return head
    }

    // An index segment may itself name a binding. `items[i]` references both
    // `items` and `i`, and the load reads the nested path too.
    var expandingIndexReferences: [Path] {
        var paths: [Path] = [self]

        for segment in segments {
            guard case let .indexRef(indexPath, _) = segment else { continue }

            paths += indexPath.expandingIndexReferences
        }

        return paths
    }

    // This path with nothing said about absence, segment by segment.
    package var unmarked: Path {
        Path(segments.map(\.unmarked))
    }

    // MARK: - Initializer
    package init(_ segments: [PathSegment]) {
        self.segments = segments
    }

    // MARK: - Public
    package mutating func append(_ segment: PathSegment) {
        segments.append(segment)
    }

    package func appending(contentsOf segments: [PathSegment]) -> Path {
        Path(self.segments + segments)
    }

    // MARK: - Private
    private func spelling(of segment: PathSegment, first: Bool) -> String {
        switch segment {
        case let .name(key, optional):
            return (optional ? "?." : (first ? "" : ".")) + key.spelling

        case let .index(index, optional):
            return (optional ? "?[" : "[") + spelling(of: index) + "]"

        case let .indexRef(indexPath, optional):
            return (optional ? "?[" : "[") + "\(indexPath.rendered)]"
        }
    }

    // A value between the brackets as a path writes it: an integer in its
    // digits and a string between double quotes, `\"` a quote and `\\` a
    // backslash inside them. A value of another kind has no spelling in a
    // path, and shows the way `text` shows it.
    private func spelling(of index: Value) -> String {
        switch index {
        case let .int(position):
            return String(position)

        case let .string(text):
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")

            return "\"\(escaped)\""

        default:
            return Rendering(index).text()
        }
    }
}
