//
//  PathSegment.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A reference path in the semantic model. Frontends parse their own surface
// syntax (`a.b[0]`, whatever else) into these segments. The runtime never
// re-parses text, so the surface grammar stays a frontend fact.
//
// A dot reads a name out of what the walk has reached, and only that. A procedure is
// sent with a written call, which spells the declaration it means, so a path
// never decides which declaration a bare name stands for.
//
// Optionality is one axis across every access, not a family of spellings: each
// segment carries whether the author wrote it optional (`?.` on a name, `?[` on
// an index) the one mark that says absence is expected here. A plain segment
// refuses what an optional one reads as null.
public enum PathSegment: Sendable, Equatable {
    case key(Name, optional: Bool)
    case index(Int, optional: Bool)
    case indexRef([PathSegment], optional: Bool)
}

public extension PathSegment {
    // The plain spellings. Most segments are written without the mark, and a
    // construction site that says nothing about absence means it.
    static func key(_ name: Name) -> PathSegment { .key(name, optional: false) }
    static func index(_ index: Int) -> PathSegment { .index(index, optional: false) }
    static func indexRef(_ path: [PathSegment]) -> PathSegment { .indexRef(path, optional: false) }

    // Whether the author expects absence here. The one axis every access
    // shares, however it is spelled.
    var optional: Bool {
        switch self {
        case let .key(_, optional), let .index(_, optional), let .indexRef(_, optional):
            return optional
        }
    }

    // This access with nothing said about absence. The mark is the author's
    // expectation of the *value*, not part of where the access lands: `a.b`
    // and `a?.b` read one field, and a question that is only about where a
    // walk arrived has to see one segment for both.
    var unmarked: PathSegment {
        switch self {
        case let .key(name, _):
            return .key(name)

        case let .index(index, _):
            return .index(index)

        case let .indexRef(path, _):
            return .indexRef(path.map(\.unmarked))
        }
    }

    // The name a dot segment reads or sends. Nil for an index, which reads a
    // position, not a name.
    var named: Name? {
        switch self {
        case let .key(name, _):
            return name

        case .index, .indexRef:
            return nil
        }
    }

    // How the mark is spelled at this access. The one place that knows, so
    // every sentence that names the spelling asks instead of guessing.
    var mark: String {
        switch self {
        case .key:
            return "?."

        case .index, .indexRef:
            return "?["
        }
    }

}

extension PathSegment {
    // Where a segment came down. The walk's fact, not the segment's, and the
    // one thing the mark's rule needs that the segment cannot know. A landing
    // is spelled out rather than implied, so a type added later cannot join
    // without saying what a mark means on it, and the ones that name something
    // carry the name rather than asking the segment back for it. Internal, like
    // the rule it feeds: `unwrapped` is the walk's own state, and nothing
    // outside the walk can answer it.
    enum Landing {
        case field(Name)
        case entry
        case element
    }

    // The refusal a mark earns where the types prove there is nothing to read
    // past. Nil where the mark stands, none was written, or the landing is one
    // that may genuinely be absent. One rule for every access, because a rule
    // that lived at each landing would drift.
    func needlessMark(
        at walked: [PathSegment],
        on held: String,
        landing: Landing,
        unwrapped: Bool
    ) -> String? {
        guard optional, !unwrapped else { return nil }

        switch landing {
        // Which names a dictionary holds is the run's fact, so a mark here
        // always has an absence to expect. The one landing that earns no
        // refusal.
        case .entry:
            return nil

        case .element:
            return "\(walked.rendered) writes `\(mark)` into \(held),"
                + " which is never null."
                + " An array the type proves is there is indexed with `[`"

        case let .field(name):
            return "\(walked.rendered) writes `\(mark)` for '\(name)',"
                + " which \(held) declares."
                + " A field the type proves is read with `.`"
        }
    }

    func meetingNull(at walked: [PathSegment]) -> NullMeeting {
        guard optional else {
            return .refused(
                "\(walked.rendered) reads through null."
                    + " Only `\(mark)` reads absence"
            )
        }

        return .reads
    }
}
