//
//  LiteralShape.swift
//  Warp
//
//  Created by JSilver on 10/4/26.
//

import Foundation

// What a list or map literal holds where it is written into a slot, part by
// part. A part that is no literal holds what it reads as, a struct literal
// the declared struct it was read as.
enum LiteralShape: Sendable {
    case list([LiteralShape])
    case map([(key: LiteralShape, value: LiteralShape)])
    case part(LoweredType)

    // MARK: - Property
    // The literal as one type, for a slot that judges it whole and for a
    // call filling a type parameter from it. An empty list holds no element,
    // so it is a list of `Never`, and the parts beside each other join.
    var folded: LoweredType {
        switch self {
        case let .list(items):
            return .array(items.reduce(.never) { held, item in held.joined(item.folded) })

        case let .map(entries):
            return .dictionary(
                key: entries.reduce(.never) { held, entry in held.joined(entry.key.folded) },
                value: entries.reduce(.never) { held, entry in held.joined(entry.value.folded) }
            )

        case let .part(reading):
            return reading
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
        everyPart(along: slot, inPlace: inPlace, in: table) { slot, part, inPlaceAtParameter in
            if inPlaceAtParameter {
                return slot.takesInPlace(part.folded.slotUnwrapped, in: table)
            }

            return slot.accepts(part.folded, in: table)
        }
    }

    // Whether every part of it, along the structure it shares with the slot,
    // `holds` what the slot asks of it there: a list by its elements, a map
    // by its keys and its values, and what may be null by what it is
    // besides. A slot handed in place that
    // names a type parameter is told so, for `holds` to judge there what
    // `takesInPlace` takes.
    func everyPart(
        along slot: LoweredType,
        inPlace: Bool,
        in table: LoweredTypeTable,
        holds: (LoweredType, LiteralShape, Bool) -> Bool
    ) -> Bool {
        let slot = inPlace ? slot.slotUnwrapped : slot
        let inPlaceAtParameter = inPlace && slot.namesParameter

        if case .part = self {
            return holds(slot, self, inPlaceAtParameter)
        }

        switch slot {
        case let .nullable(inner), let .variable(inner):
            return everyPart(along: inner, inPlace: inPlace, in: table, holds: holds)

        case let .array(element):
            guard case let .list(items) = self else { break }

            return items.allSatisfy { item in
                item.everyPart(along: element, inPlace: inPlace, in: table, holds: holds)
            }

        case let .dictionary(key, element):
            guard case let .map(entries) = self else { break }

            return entries.allSatisfy { entry in
                entry.key.everyPart(along: key, inPlace: inPlace, in: table, holds: holds)
                    && entry.value.everyPart(along: element, inPlace: inPlace, in: table, holds: holds)
            }

        default:
            break
        }

        return holds(slot, self, inPlaceAtParameter)
    }

    // The literal as it reads once written where `place` is declared: each
    // part as `LoweredType.written` reads it there, so a whole literal the
    // place reads as a fraction is the fraction it names.
    func written(into place: LoweredType, in table: LoweredTypeTable) -> LiteralShape {
        if case let .nullable(inner) = place {
            return written(into: inner, in: table)
        }

        switch self {
        case let .part(reading):
            return .part(place.written(reading, in: table))

        case let .list(items):
            guard let element = place.element else { return self }

            return .list(items.map { item in item.written(into: element, in: table) })

        case let .map(entries):
            guard case let .dictionary(key, value) = place else { return self }

            return .map(entries.map { entry in
                (key: entry.key.written(into: key, in: table), value: entry.value.written(into: value, in: table))
            })
        }
    }

    // How a refusal names it: written as the literal is, a list in brackets
    // and a map as its entries under `dictionary`, with each part spelled as
    // the type it reads as.
    func rendered(in table: LoweredTypeTable) -> String {
        switch self {
        case let .list(items):
            return "[" + items.map { item in item.rendered(in: table) }.joined(separator: ", ") + "]"

        case let .map(entries):
            let written = entries.map { entry in
                "[\(entry.key.rendered(in: table)), \(entry.value.rendered(in: table))]"
            }

            return "{ dictionary: [" + written.joined(separator: ", ") + "] }"

        case let .part(reading):
            return reading.rendered(in: table)
        }
    }

    // MARK: - Private
}
