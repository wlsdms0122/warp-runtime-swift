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
    // What is written where a shape is kept only where the reading beside it
    // does not say: that shape, or the reading as one part.
    init(_ shape: LiteralShape?, reading: LoweredType) {
        self = shape ?? .part(reading)
    }

    // MARK: - Public
    // Whether a slot takes it, part by part along `everyPart(along:)`. A
    // slot handed in place that names a type parameter takes what
    // `takesInPlace` takes there, since the parts beside each other need not
    // be one type for each to be a value of what the slot asks there. Every
    // other slot takes what it accepts.
    func isHeld(by slot: LoweredType, inPlace: Bool, in table: LoweredTypeTable) -> Bool {
        isHeld(by: slot, inPlace: inPlace, in: table, asking: .nothing)
    }

    // Whether every part of it, along the structure it shares with the slot,
    // `holds` what the slot asks of it there: a list by its elements, a
    // dictionary by every field, a record by the fields it names (one it
    // lacks refuses), a name by the type it names, what may be null by what
    // it is besides, and each way of an attempt on its own. A slot handed in
    // place that names a type parameter is rigid, and shares no record,
    // which `takesInPlace` judges whole. A membership shares no structure:
    // which member a literal is, is a judgement, made where it is held.
    func everyPart(
        along slot: LoweredType,
        inPlace: Bool,
        in table: LoweredTypeTable,
        holds: (LoweredType, LiteralShape, Bool) -> Bool
    ) -> Bool {
        everyPart(along: slot, inPlace: inPlace, in: table, whole: true) { slot, part, rigid, _ in holds(slot, part, rigid) }
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
    // `asking` is which memberships are already being asked of this literal.
    // A part the walk took apart is another literal and starts with none.
    private func isHeld(by slot: LoweredType, inPlace: Bool, in table: LoweredTypeTable, asking: Asking) -> Bool {
        everyPart(along: slot, inPlace: inPlace, in: table, whole: true) { slot, part, rigid, whole in
            if rigid {
                return slot.takesInPlace(part.folded.slotUnwrapped, in: table)
            }

            return slot.accepts(part.folded, in: table)
                && part.isHeld(byMembersOf: slot, in: table, asking: whole ? asking : .nothing)
        }
    }

    // The walk. `whole` is whether the part is still the literal the walk
    // began with, which a name, what may be null or a slot's mark leaves as
    // it is, and a list, a record or an attempt's way takes apart.
    private func everyPart(
        along slot: LoweredType,
        inPlace: Bool,
        in table: LoweredTypeTable,
        whole: Bool,
        holds: (LoweredType, LiteralShape, Bool, Bool) -> Bool
    ) -> Bool {
        let slot = inPlace ? slot.slotUnwrapped : slot
        let rigid = inPlace && slot.namesParameter

        switch self {
        case .part:
            return holds(slot, self, rigid, whole)

        case let .either(attempted, rescued):
            return attempted.everyPart(along: slot, inPlace: inPlace, in: table, whole: false, holds: holds)
                && rescued.everyPart(along: slot, inPlace: inPlace, in: table, whole: false, holds: holds)

        case .list, .record:
            break
        }

        switch slot {
        case let .nullable(inner), let .variable(inner):
            return everyPart(along: inner, inPlace: inPlace, in: table, whole: whole, holds: holds)

        case let .named(row):
            return everyPart(along: table.loweredTypes[row], inPlace: inPlace, in: table, whole: whole, holds: holds)

        case let .array(element):
            guard case let .list(items) = self else { break }

            return items.allSatisfy { item in
                item.everyPart(along: element, inPlace: inPlace, in: table, whole: false, holds: holds)
            }

        case let .dictionary(element):
            guard case let .record(fields) = self else { break }

            return fields.values.allSatisfy { field in
                field.everyPart(along: element, inPlace: inPlace, in: table, whole: false, holds: holds)
            }

        case let .record(record) where !rigid:
            guard case let .record(fields) = self else { break }

            return record.named.allSatisfy { name, field in
                fields[name].map { given in
                    given.everyPart(along: field, inPlace: inPlace, in: table, whole: false, holds: holds)
                } ?? false
            }

        default:
            break
        }

        return holds(slot, self, rigid, whole)
    }

    // Whether the bounds a literal stands under take it part by part, as
    // `accepts` reads them whole: a membership by one of its members, and a
    // parameter by every member of one membership bounding it. Asking every
    // member of a bound is not asking whether the literal is one of that
    // membership, so only a membership asked for one of its members joins
    // what is being asked. A membership already being asked of this literal
    // does not take it, the way the run settles a value.
    private func isHeld(byMembersOf slot: LoweredType, in table: LoweredTypeTable, asking: Asking) -> Bool {
        switch (slot, self) {
        case (_, .part):
            return true

        case let (.composition(bounds), _):
            return bounds.allSatisfy { bound in
                guard case let .membership(row) = bound else { return true }

                return isHeld(byMembership: row, in: table, asking: asking)
            }

        case let (.parameter(_, bounds), _):
            return bounds.contains { bound in
                guard case let .membership(row) = bound else { return false }

                return table.constraints[row].allSatisfy { member in
                    isHeld(by: member, inPlace: false, in: table, asking: asking)
                }
            }

        default:
            return true
        }
    }

    // Whether one member of a membership takes it.
    private func isHeld(byMembership row: Int, in table: LoweredTypeTable, asking: Asking) -> Bool {
        guard !asking.contains(row) else { return false }

        let asked = asking.adding(row)

        return table.constraints[row].contains { member in
            isHeld(by: member, inPlace: false, in: table, asking: asked)
        }
    }

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
