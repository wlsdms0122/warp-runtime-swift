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
    // The literal as one type, for a slot that judges it whole and for a
    // call filling a type parameter from it. An empty list holds no element,
    // so it is a list of `never`, and the parts beside each other join part
    // by part.
    var folded: LoweredType {
        switch self {
        case let .list(items):
            return .array(items.reduce(.never) { held, item in Self.joined(held, item.folded) })

        case let .record(fields):
            return .record(fields.mapValues(\.folded))

        case let .part(reading):
            return reading
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether a slot handed in place takes it. Where the slot names a type
    // parameter it is judged part by part along the structure
    // `takesInPlace` walks there, a record only as a dictionary's entries,
    // since the parts beside each other need not be one type for each to be
    // a value of what the slot asks there. Elsewhere it is judged whole, as
    // `takesInPlace` judges a slot naming none.
    func isTaken(inPlaceBy slot: LoweredType, in table: LoweredTypeTable) -> Bool {
        guard slot.namesParameter else { return slot.accepts(folded, in: table) }

        switch (slot, self) {
        case let (_, .part(reading)):
            return slot.takesInPlace(reading.slotUnwrapped, in: table)

        case let (.nullable(inner), _):
            return isTaken(inPlaceBy: inner, in: table)

        case let (.array(element), .list(items)):
            return items.allSatisfy { item in item.isTaken(inPlaceBy: element, in: table) }

        case let (.dictionary(element), .record(fields)):
            return fields.values.allSatisfy { field in field.isTaken(inPlaceBy: element, in: table) }

        default:
            return slot.takesInPlace(folded, in: table)
        }
    }

    // How a refusal names it: written as the literal is, a list in brackets
    // and a record in braces, with each part spelled as the type it reads as.
    // A list whose parts all read as one type is that type.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case let .list(items):
            return "[" + items.map { item in item.rendered(in: table) }.joined(separator: ", ") + "]"

        case let .record(fields):
            return LoweredType.rendered(
                fields: fields.sorted { left, right in left.key < right.key }.map { name, field in
                    (name, field.rendered(in: table))
                }
            )

        case let .part(reading):
            return reading.rendered(in: table)
        }
    }

    // MARK: - Private
    // Two parts a literal holds side by side, as one type: joined as two
    // readings join, and part by part where a reading's join gives up, lists
    // by their elements and records of the same fields field by field, inside
    // what may be null too. Records of other fields are `any`, since a record
    // slot takes either while no one record type holds both.
    private static func joined(_ held: LoweredType, _ part: LoweredType) -> LoweredType {
        switch (held, part) {
        case let (.nullable(mine), _):
            return joined(mine, part).admittingNull

        case let (_, .nullable(theirs)):
            return joined(held, theirs).admittingNull

        case let (.array(mine), .array(theirs)):
            return .array(joined(mine, theirs))

        case let (.record(mine), .record(theirs)) where mine.layout.fields == theirs.layout.fields:
            return .record(
                LoweredRecord(layout: mine.layout, fields: zip(mine.fields, theirs.fields).map { field, given in joined(field, given) })
            )

        default:
            return held.joined(part)
        }
    }
}
