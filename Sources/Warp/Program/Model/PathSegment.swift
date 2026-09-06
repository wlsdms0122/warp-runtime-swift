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
// A dot means what the link decided it means. A document writes `key` segments;
// the link reads each against the type the walk has reached and rewrites the
// ones that are sends into `word` segments, so by the time a run reads a path,
// a `key` is only ever a field and a `word` is only ever a send, and the value
// that arrives has no say in which.
//
// Optionality is one axis across every access, not a family of spellings: each
// segment carries whether the author wrote it optional (`?.` on a name, `?[` on
// an index) the one mark that says absence is expected here. A plain segment
// refuses what an optional one reads as null.
public enum PathSegment: Sendable, Equatable {
    case key(Name, optional: Bool)
    case word(Name, optional: Bool)
    case index(Int, optional: Bool)
    case indexRef([PathSegment], optional: Bool)
}

public extension PathSegment {
    // The plain spellings. Most segments are written without the mark, and a
    // construction site that says nothing about absence means it.
    static func key(_ name: Name) -> PathSegment { .key(name, optional: false) }
    static func word(_ name: Name) -> PathSegment { .word(name, optional: false) }
    static func index(_ index: Int) -> PathSegment { .index(index, optional: false) }
    static func indexRef(_ path: [PathSegment]) -> PathSegment { .indexRef(path, optional: false) }

    // Whether the author expects absence here. The one axis every access
    // shares, however it is spelled.
    var optional: Bool {
        switch self {
        case let .key(_, optional), let .word(_, optional),
            let .index(_, optional), let .indexRef(_, optional):
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

        case let .word(name, _):
            return .word(name)

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
        case let .key(name, _), let .word(name, _):
            return name

        case .index, .indexRef:
            return nil
        }
    }

    // How the mark is spelled at this access. The one place that knows, so
    // every sentence that names the spelling asks instead of guessing.
    var mark: String {
        switch self {
        case .key, .word:
            return "?."

        case .index, .indexRef:
            return "?["
        }
    }

}

// What a segment does when the walk meets null. The one rule, owned here so the
// link's walk over types and the run's walk over values cannot drift: an
// optional segment (`?.`, `?[`) reads the absence as null for the rest of the
// path, and a plain one refuses.
enum NullMeeting {
    case reads
    case refused(String)
}

extension PathSegment {
    // Where a segment came down. The walk's fact, not the segment's, and the
    // one thing the mark's rule needs that the segment cannot know. A landing
    // is spelled out rather than implied, so a shape added later cannot join
    // without saying what a mark means on it, and the ones that name something
    // carry the name rather than asking the segment back for it. Internal, like
    // the rule it feeds: `unwrapped` is the walk's own state, and nothing
    // outside the walk can answer it.
    enum Landing {
        case field(Name)
        case entry
        case word(Name)
        case element
    }

    // The refusal a mark earns where the types prove there is nothing to read
    // past. Nil where the mark stands, none was written, or the landing is one
    // that may genuinely be absent. One rule for every access, because a rule
    // that lived at each landing would drift.
    func needlessMark(
        at walked: [PathSegment],
        on receiver: String,
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
            return "\(walked.rendered) writes `\(mark)` into \(receiver),"
                + " which is never null."
                + " An array the type proves is there is indexed with `[`"

        case let .field(name):
            return "\(walked.rendered) writes `\(mark)` for '\(name)',"
                + " which \(receiver) declares."
                + " A field the type proves is read with `.`"

        case let .word(name):
            return "\(walked.rendered) writes `\(mark)` for '\(name)',"
                + " and \(receiver) is never null."
                + " A word that always answers is sent with `.`"
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

public extension Array where Element == PathSegment {
    // The canonical textual form. Diagnostics and encoding share one spelling.
    // A `word` spells the way the `key` it was rewritten from did: the rewrite
    // is the link's fact, and the author reads back what they wrote.
    var rendered: String {
        var rendered = ""

        for segment in self {
            switch segment {
            case let .key(key, optional), let .word(key, optional):
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
