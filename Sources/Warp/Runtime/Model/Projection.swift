//
//  Projection.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// One step of a path with every index read, which is what a hold keeps, a
// read walks and a write walks: a struct's field by the place the build put it at or by its
// name where the build laid out no struct, and what a list or a dictionary holds at a
// value, an element by position and an entry by key. The spelling beside a
// field is what a sentence calls it.
enum Projection: Sendable {
    // Where one step came down: on a part, or on a reading gone wrong, said
    // as the refusal says it.
    enum Part {
        case found(Value)
        case unfit(String)
    }

    case field(Int, Name)
    case name(Name)
    case index(Value)

    // MARK: - Property
    // How the step reads back, as the author wrote it.
    var spelled: PathSegment {
        switch self {
        case let .field(_, name), let .name(name): .name(name)
        case let .index(index): .index(index)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // The part this step names in a value. What may genuinely be absent, a
    // none on the way at any level or an entry the dictionary does not hold, reads
    // as null only where the author marked the step, and is refused
    // everywhere else. A marked step reads an entry the dictionary holds as the
    // entry's Optional, so as its some. A
    // list is whatever has elements: the projection owns the `Array<Int>`
    // equation, lazily, so one element read does not unpack a compact
    // spelling. Past the end is a defect, not absence: the list is there and
    // says how long it is. `segment` is this step as written and `walked` the
    // path as far as it, both for a refusal, so a read that lands spells
    // nothing.
    func part(of value: Value, as segment: () -> PathSegment, walked: () -> Path) -> Part {
        if case let .existential(existential) = value {
            return part(of: existential.value, as: segment, walked: walked)
        }

        // A none stops every reading the same way, and the rule lives with the
        // segment: the build's walk over types asks the same judge, so the
        // two layers cannot drift apart. A marked step reads past every
        // level, and a marker holds only a none, so null and a marker are
        // each absent here.
        if value.isNone {
            switch segment().meetingNone(at: walked()) {
            case .reads:
                return .found(.null)

            case let .refused(reason):
                return .unfit(reason)
            }
        }

        switch self {
        case let .field(position, _):
            guard case let .struct(instance) = value else {
                return .unfit("\(walked().rendered) drills a field into \(value.nominal)")
            }

            guard instance.values.indices.contains(position) else {
                return .unfit("\(walked().rendered) drills past the fields this struct holds")
            }

            return .found(instance.values[position])

        case let .name(name):
            guard case let .struct(instance) = value else {
                return .unfit("\(walked().rendered) drills a field into \(value.nominal)")
            }

            guard let field = instance[name] else {
                return .unfit("\(walked().rendered) drills past the fields this struct holds")
            }

            return .found(field)

        case let .index(index):
            if case let .dictionary(dictionary) = value {
                guard let entry = dictionary[key: index] else {
                    guard segment().optional else {
                        return .unfit(
                            "\(walked().rendered) reads an entry the dictionary does not hold."
                                + " Only `\(segment().mark)` reads absence"
                        )
                    }

                    return .found(.null)
                }

                return .found(segment().optional ? entry.asSome : entry)
            }

            guard let elements = value.elements else {
                return .unfit("\(walked().rendered) indexes into \(value.nominal), expected Array or Dictionary")
            }

            guard case let .int(position) = index else {
                return .unfit("\(walked().rendered) indexes a list by \(index.nominal), expected Int")
            }

            guard position >= 0, position < elements.count else {
                return .unfit(
                    "\(walked().rendered) indexes a list of \(elements.count) at \(position), a position it does not hold"
                )
            }

            return .found(elements[elements.index(elements.startIndex, offsetBy: position)])
        }
    }

    // MARK: - Private
}
