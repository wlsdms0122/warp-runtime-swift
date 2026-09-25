//
//  Array+PathSegment.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

public extension Array where Element == PathSegment {
    // The canonical textual form. Diagnostics and encoding share one spelling.
    var rendered: String {
        var rendered = ""

        for segment in self {
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

    // What a mark on the head claims, said once for every layer that judges a
    // path. Nil where the head is written plain. The head is a name a scope
    // holds, not a field that may be absent: there is nothing before it to read
    // past, so the mark has nothing to mean.
    var markedHead: String? {
        guard let first, first.optional else { return nil }

        return "\(rendered) marks the head optional, and the head of a path"
            + " is a name a scope holds. `\(first.mark)` expects an absence,"
            + " and a name that answers nothing is a reading gone wrong"
    }

    // The root name this path reads from. Nil when the path doesn't start with
    // a name, which no scope can serve.
    var head: Name? {
        guard case let .key(head, _)? = first else { return nil }

        return head
    }

    // An index segment may itself name a binding. `items[i]` references both
    // `items` and `i`. Static validation must see the nested path too, or a
    // typo'd index escapes to runtime.
    var expandingIndexReferences: [[PathSegment]] {
        var paths: [[PathSegment]] = [self]

        for segment in self {
            guard case let .indexRef(indexPath, _) = segment else { continue }

            paths += indexPath.expandingIndexReferences
        }

        return paths
    }
}
