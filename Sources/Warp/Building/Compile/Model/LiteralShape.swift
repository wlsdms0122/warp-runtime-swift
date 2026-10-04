//
//  LiteralShape.swift
//  Warp
//
//  Created by JSilver on 10/4/26.
//

import Foundation

// What a list or record literal holds where it is written into a slot, part
// by part. A part that is no literal holds what it reads as. An attempt
// writes what one of its two ways answers, each written on its own.
enum LiteralShape: Sendable {
    case list([LiteralShape])
    case record([Name: LiteralShape])
    case part(LoweredType)
    indirect case either(LiteralShape, LiteralShape)

    // MARK: - Property
    // The literal as one type, for a slot that judges it whole and for a
    // call filling a type parameter from it. An empty list holds no element,
    // so it is a list of `never`, and the parts beside each other join part
    // by part. An attempt's two ways join as two readings of one slot do.
    var folded: LoweredType {
        switch self {
        case let .list(items):
            return .array(items.reduce(.never) { held, item in Self.joined(held, item.folded) })

        case let .record(fields):
            return .record(fields.mapValues(\.folded))

        case let .part(reading):
            return reading

        case let .either(attempted, rescued):
            return attempted.folded.joined(rescued.folded)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether a slot takes it, along the structure the slot and the literal
    // share: a list by its elements, a record by its fields (a dictionary by
    // every field, a record by the fields it names), each way of an attempt
    // on its own, and a name by the type it names. Where they part it is
    // judged whole. A slot handed in place that names a type parameter
    // takes what `takesInPlace` takes there, a record only as a dictionary's
    // entries, since the parts beside each other need not be one type for
    // each to be a value of what the slot asks there. Every other slot takes
    // what it accepts.
    func isHeld(by slot: LoweredType, inPlace: Bool, in table: LoweredTypeTable) -> Bool {
        let slot = inPlace ? slot.slotUnwrapped : slot
        let rigid = inPlace && slot.namesParameter

        switch (slot, self) {
        case let (_, .either(attempted, rescued)):
            return attempted.isHeld(by: slot, inPlace: inPlace, in: table)
                && rescued.isHeld(by: slot, inPlace: inPlace, in: table)

        case let (_, .part(reading)):
            return rigid ? slot.takesInPlace(reading.slotUnwrapped, in: table) : slot.accepts(reading, in: table)

        case let (.nullable(inner), _), let (.variable(inner), _):
            return isHeld(by: inner, inPlace: inPlace, in: table)

        case let (.array(element), .list(items)):
            return items.allSatisfy { item in item.isHeld(by: element, inPlace: inPlace, in: table) }

        case let (.dictionary(element), .record(fields)):
            return fields.values.allSatisfy { field in field.isHeld(by: element, inPlace: inPlace, in: table) }

        case let (.record(record), .record(fields)) where !rigid:
            return record.named.allSatisfy { name, field in
                fields[name].map { given in given.isHeld(by: field, inPlace: inPlace, in: table) } ?? false
            }

        case let (.named(row), _) where !rigid:
            return isHeld(by: table.loweredTypes[row], inPlace: inPlace, in: table)

        default:
            return rigid ? slot.takesInPlace(folded, in: table) : slot.accepts(folded, in: table)
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

        case let .either(attempted, rescued):
            return attempted.rendered(in: table) + " or " + rescued.rendered(in: table)
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
