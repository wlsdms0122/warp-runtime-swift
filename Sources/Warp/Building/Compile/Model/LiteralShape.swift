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

    // Whether it is a part rather than a literal or an attempt.
    var isPart: Bool {
        if case .part = self { return true }

        return false
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether a slot takes it, part by part along `parts(along:)`. A slot
    // handed in place that names a type parameter takes what `takesInPlace`
    // takes there, since the parts beside each other need not be one type
    // for each to be a value of what the slot asks there. Every other slot
    // takes what it accepts, and a membership around a literal one of its
    // members takes part by part.
    func isHeld(by slot: LoweredType, inPlace: Bool, in table: LoweredTypeTable) -> Bool {
        parts(along: slot, inPlace: inPlace, in: table) { slot, part, rigid in
            if rigid {
                return slot.takesInPlace(part.folded.slotUnwrapped, in: table)
            }

            guard slot.accepts(part.folded, in: table) else { return false }

            guard case let .composition(bounds) = slot, !part.isPart else { return true }

            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return table.constraints[row].contains { member in part.isHeld(by: member, inPlace: false, in: table) }
            }
        }
    }

    // Every part of it along the structure it shares with the slot, each
    // with what the slot asks of it there, until `holds` refuses one: a list
    // by its elements, a dictionary by every field, a record by the fields
    // it names (one it lacks refuses), a name by the type it names, what may
    // be null by what it is besides, and each way of an attempt on its own.
    // A slot handed in place that names a type parameter is rigid, and shares
    // no record, which `takesInPlace` judges whole.
    func parts(
        along slot: LoweredType,
        inPlace: Bool,
        in table: LoweredTypeTable,
        holding holds: (LoweredType, LiteralShape, Bool) -> Bool
    ) -> Bool {
        let slot = inPlace ? slot.slotUnwrapped : slot
        let rigid = inPlace && slot.namesParameter

        switch (slot, self) {
        case (_, .part):
            return holds(slot, self, rigid)

        case let (_, .either(attempted, rescued)):
            return attempted.parts(along: slot, inPlace: inPlace, in: table, holding: holds)
                && rescued.parts(along: slot, inPlace: inPlace, in: table, holding: holds)

        case let (.nullable(inner), _), let (.variable(inner), _):
            return parts(along: inner, inPlace: inPlace, in: table, holding: holds)

        case let (.array(element), .list(items)):
            return items.allSatisfy { item in item.parts(along: element, inPlace: inPlace, in: table, holding: holds) }

        case let (.dictionary(element), .record(fields)):
            return fields.values.allSatisfy { field in field.parts(along: element, inPlace: inPlace, in: table, holding: holds) }

        case let (.record(record), .record(fields)) where !rigid:
            return record.named.allSatisfy { name, field in
                fields[name].map { given in given.parts(along: field, inPlace: inPlace, in: table, holding: holds) } ?? false
            }

        case let (.named(row), _):
            return parts(along: table.loweredTypes[row], inPlace: inPlace, in: table, holding: holds)

        default:
            return holds(slot, self, rigid)
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
