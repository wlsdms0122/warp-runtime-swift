//
//  LoweredPath.swift
//  Warp
//
//  Created by JSilver on 10/12/26.
//

import Foundation

// A path as the type check placed it: its segments as the run reads them,
// with no slot named yet. A dot on a struct whose layout the build proved
// stands at the place the field takes; a dot on a type a call decides is read
// by its name; what stands between brackets is written into the place it
// stands in, and an index the run reads is a path of its own. The type check
// works it out once, where it judges the path, and lowering names the slots.
struct LoweredPath: Sendable, Equatable {
    enum Segment: Sendable, Equatable {
        // A field of a struct whose layout the build proved: the place it
        // stands in, beside the spelling the path wrote.
        case field(Int, Name, optional: Bool)

        // A field read by its name, of a value whose type a call decides.
        // The head is one too.
        case name(Name, optional: Bool)

        case index(Value, optional: Bool)
        case at(LoweredPath, optional: Bool)

        // MARK: - Property
        // The segment as a document writes it.
        var written: PathSegment {
            switch self {
            case let .field(_, name, optional), let .name(name, optional):
                return .name(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .at(inner, optional):
                return .indexRef(inner.path, optional: optional)
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    private(set) var segments: [Segment]

    // The name the path reads from.
    var head: Name? {
        guard case let .name(head, _)? = segments.first else { return nil }

        return head
    }

    // The path as a document writes it.
    var path: Path {
        Path(segments.map(\.written))
    }

    // MARK: - Initializer
    init(_ segments: [Segment]) {
        self.segments = segments
    }

    // MARK: - Public
    mutating func append(_ segment: Segment) {
        segments.append(segment)
    }

    func appending(contentsOf other: LoweredPath) -> LoweredPath {
        LoweredPath(segments + other.segments)
    }

    // MARK: - Private
}
