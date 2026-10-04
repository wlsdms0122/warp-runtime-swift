//
//  LiteralShape.swift
//  Warp
//
//  Created by JSilver on 10/4/26.
//

import Foundation

// What a list or record literal holds where it is written into a slot, part
// by part. A part that is no literal holds what it reads as.
enum LiteralShape: Sendable {
    case list([LiteralShape])
    case record([Name: LiteralShape])
    case part(LoweredType)

    // MARK: - Property
    // The literal as one type, for a slot that judges it whole. An empty list
    // holds no element, so it is a list of `never`, and the parts beside each
    // other join as two readings do.
    var folded: LoweredType {
        switch self {
        case let .list(items):
            return .array(items.reduce(.never) { held, item in held.joined(item.folded) })

        case let .record(fields):
            return .record(fields.mapValues(\.folded))

        case let .part(reading):
            return reading
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether a slot takes it, part by part along the slot: a list by each
    // element and a record by each field, since the parts beside each other
    // need not be one type for each to fit what the slot asks there. A slot
    // that asks for no such parts takes it whole. `takes` judges a part
    // against what the slot asks at it.
    func isTaken(by slot: LoweredType, taking takes: (LoweredType, LoweredType) -> Bool) -> Bool {
        switch (slot, self) {
        case let (_, .part(reading)):
            return takes(slot, reading)

        case let (.nullable(inner), _):
            return isTaken(by: inner, taking: takes)

        case let (.array(element), .list(items)):
            return items.allSatisfy { item in item.isTaken(by: element, taking: takes) }

        case let (.dictionary(element), .record(fields)):
            return fields.values.allSatisfy { field in field.isTaken(by: element, taking: takes) }

        default:
            return takes(slot, folded)
        }
    }

    // The same where a slot handed in place takes it, so where it asks for a
    // type parameter only that parameter is taken.
    func isTaken(inPlaceBy slot: LoweredType, in table: LoweredTypeTable) -> Bool {
        isTaken(by: slot) { slot, part in slot.takesInPlace(part.slotUnwrapped, in: table) }
    }

    // The same where any other slot takes it.
    func isAccepted(by slot: LoweredType, in table: LoweredTypeTable) -> Bool {
        isTaken(by: slot) { slot, part in slot.accepts(part, in: table) }
    }

    // How a refusal names it: a list and a record part by part, the way the
    // slot judged it.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case let .list(items):
            return "[" + items.map { item in item.rendered(in: table) }.joined(separator: ", ") + "]"

        case let .record(fields):
            let named = fields.sorted { left, right in left.key < right.key }.map { name, field in
                "\(name): \(field.rendered(in: table))"
            }

            return "{ " + named.joined(separator: ", ") + " }"

        case let .part(reading):
            return reading.rendered(in: table)
        }
    }

    // MARK: - Private
}
