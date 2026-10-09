//
//  Path.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a reference reads and an assignment writes: a name, then the segments
// that reach into what it holds.
public struct Path: Sendable, Equatable {
    // MARK: - Property
    // What a path's segment is read without at either end: white space, a
    // line break included. So a value's name with one at an end is no name a
    // path reaches.
    public static let whiteSpace = CharacterSet.whitespacesAndNewlines

    public private(set) var segments: [PathSegment]

    // The canonical textual form. Diagnostics and encoding share one spelling.
    public var rendered: String {
        var rendered = ""

        for segment in segments {
            switch segment {
            case let .key(key, optional):
                rendered += (optional ? "?." : (rendered.isEmpty ? "" : ".")) + key.spelling

            case let .index(index, optional):
                rendered += (optional ? "?[" : "[") + "\(index)]"

            case let .indexRef(indexPath, optional):
                rendered += (optional ? "?[" : "[") + "\(indexPath.rendered)]"
            }
        }

        return rendered
    }

    // What a mark on the head claims, which the load refuses. Nil where the
    // head is written plain. The head is a name a scope
    // holds, not a field that may be absent: there is nothing before it to read
    // past, so the mark has nothing to mean.
    public var markedHead: String? {
        guard let first = segments.first, first.optional else { return nil }

        return "\(rendered) marks the head optional, and the head of a path"
            + " is a name a scope holds. `\(first.mark)` expects an absence,"
            + " and a name that answers nothing is a reading gone wrong"
    }

    // The root name this path reads from. Nil when the path doesn't start with
    // a name, which no scope can serve.
    public var head: Name? {
        guard case let .key(head, _)? = segments.first else { return nil }

        return head
    }

    // An index segment may itself name a binding. `items[i]` references both
    // `items` and `i`. Static validation must see the nested path too, or a
    // typo'd index escapes to runtime.
    public var expandingIndexReferences: [Path] {
        var paths: [Path] = [self]

        for segment in segments {
            guard case let .indexRef(indexPath, _) = segment else { continue }

            paths += indexPath.expandingIndexReferences
        }

        return paths
    }

    // This path with nothing said about absence, segment by segment.
    public var unmarked: Path {
        Path(segments.map(\.unmarked))
    }

    // MARK: - Initializer
    public init(_ segments: [PathSegment]) {
        self.segments = segments
    }

    // MARK: - Public
    public mutating func append(_ segment: PathSegment) {
        segments.append(segment)
    }

    public func appending(contentsOf segments: [PathSegment]) -> Path {
        Path(self.segments + segments)
    }

    // MARK: - Private
}
