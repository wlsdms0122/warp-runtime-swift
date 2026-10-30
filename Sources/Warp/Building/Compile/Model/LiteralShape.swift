//
//  LiteralShape.swift
//  Warp
//
//  Created by JSilver on 10/4/26.
//

import Foundation

// What a list or dictionary literal holds where it is written into a slot, part by
// part. A part that is no literal holds what it reads as, a struct literal
// the declared struct it was read as.
enum LiteralShape: Sendable {
    case list([LiteralShape])
    case dictionary([(key: LiteralShape, value: LiteralShape)])
    case part(LoweredType)

    // The first part a slot does not take: the steps from the literal's own
    // place to it, what the slot asks there, and what the part reads as. A
    // refusal stands at the part and spells both sides as types.
    struct Misfit {
        // MARK: - Property
        let steps: [Expression.Child]
        let slot: LoweredType
        let part: LoweredType

        // MARK: - Initializer
        // MARK: - Public
        // Where the part stands, below the place the literal stands at.
        func place(under place: Place) -> Place {
            steps.reduce(place) { reached, step in reached.child(step) }
        }

        // The part named below what names the whole literal, its steps
        // spelled as a place spells them.
        func naming(_ whole: String) -> String {
            Place([.key(whole)] + steps.flatMap(\.steps), in: .assembled).rendered ?? whole
        }

        // The same part, seen from the literal one step above the one it
        // was found in.
        func below(_ step: Expression.Child) -> Misfit {
            Misfit(steps: [step] + steps, slot: slot, part: part)
        }

        // MARK: - Private
    }

    // MARK: - Property
    // The literal as one type, for a slot that judges it whole and for a
    // call filling a type parameter from it. An empty list holds no element,
    // so it is a list of `Never`, and the parts beside each other join.
    var folded: LoweredType {
        switch self {
        case let .list(items):
            return .array(items.reduce(.never) { held, item in held.joined(item.folded) })

        case let .dictionary(entries):
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
    // The first part a slot does not take, along `misfit(along:)`, or nil
    // where it takes every part. A slot handed in place that names a type
    // parameter takes what `takesInPlace` takes there, since the parts beside
    // each other need not be one type for each to be a value of what the
    // slot asks there. Every other slot takes what it accepts.
    func misfit(heldBy slot: LoweredType, inPlace: Bool, in table: LoweredTypeTable) -> Misfit? {
        misfit(along: slot, inPlace: inPlace, in: table) { slot, part, inPlaceAtParameter in
            if inPlaceAtParameter {
                return slot.takesInPlace(part.folded.slotUnwrapped, in: table)
            }

            return slot.accepts(part.folded, in: table)
        }
    }

    // The first part, along the structure it shares with the slot, that
    // `holds` refuses what the slot asks of it there, or nil: a list by its
    // elements, a dictionary by each entry's key and then its value, and an
    // Optional by what it is besides. A slot handed in place that names a
    // type parameter is told so, for `holds` to judge there what
    // `takesInPlace` takes.
    func misfit(
        along slot: LoweredType,
        inPlace: Bool,
        in table: LoweredTypeTable,
        holds: (LoweredType, LiteralShape, Bool) -> Bool
    ) -> Misfit? {
        let slot = inPlace ? slot.slotUnwrapped : slot
        let inPlaceAtParameter = inPlace && slot.namesParameter

        switch (self, slot) {
        case (.part, _):
            break

        case let (_, .optional(inner)), let (_, .variable(inner)):
            return misfit(along: inner, inPlace: inPlace, in: table, holds: holds)

        case let (.list(items), .array(element)):
            for (position, item) in items.enumerated() {
                if let found = item.misfit(along: element, inPlace: inPlace, in: table, holds: holds) {
                    return found.below(.element(position))
                }
            }

            return nil

        case let (.dictionary(entries), .dictionary(key, element)):
            for (position, entry) in entries.enumerated() {
                if let found = entry.key.misfit(along: key, inPlace: inPlace, in: table, holds: holds) {
                    return found.below(.entryKey(position))
                }

                if let found = entry.value.misfit(along: element, inPlace: inPlace, in: table, holds: holds) {
                    return found.below(.entryValue(position))
                }
            }

            return nil

        default:
            break
        }

        guard !holds(slot, self, inPlaceAtParameter) else { return nil }

        return Misfit(steps: [], slot: slot, part: folded)
    }

    // The literal as it reads once written where `place` is declared: each
    // part as `LoweredType.written` reads it there, so an integer literal the
    // place reads as a `Double` is the floating-point number it names.
    func written(into place: LoweredType, in table: LoweredTypeTable) -> LiteralShape {
        if case let .optional(inner) = place {
            return written(into: inner, in: table)
        }

        switch self {
        case let .part(reading):
            return .part(place.written(reading, in: table))

        case let .list(items):
            guard let element = place.element else { return self }

            return .list(items.map { item in item.written(into: element, in: table) })

        case let .dictionary(entries):
            guard case let .dictionary(key, value) = place else { return self }

            return .dictionary(entries.map { entry in
                (key: entry.key.written(into: key, in: table), value: entry.value.written(into: value, in: table))
            })
        }
    }

    // What becomes of it where it lands in a place declared `declared`, by
    // the place each part stands at, along the structure it shares with the
    // place: a part read as no contract is held beside its reading where the
    // place reads a contract, and one whose value may hold a type beside it
    // drops them where the place holds none.
    func coercions(landingIn declared: LoweredType, at place: Place, in table: LoweredTypeTable) -> JudgementTable {
        var coercions = JudgementTable()

        record(landingIn: declared, at: place, in: table, into: &coercions)

        return coercions
    }

    // MARK: - Private
    private func record(
        landingIn declared: LoweredType,
        at place: Place,
        in table: LoweredTypeTable,
        into coercions: inout JudgementTable
    ) {
        let declared = declared.slotUnwrapped

        switch (self, declared) {
        case let (.list, .optional(inner)), let (.dictionary, .optional(inner)):
            record(landingIn: inner, at: place, in: table, into: &coercions)

        case let (.list(items), .array(element)):
            for (position, item) in items.enumerated() {
                item.record(landingIn: element, at: place.child(.element(position)), in: table, into: &coercions)
            }

        case let (.dictionary(entries), .dictionary(key, value)):
            for (position, entry) in entries.enumerated() {
                entry.key.record(landingIn: key, at: place.child(.entryKey(position)), in: table, into: &coercions)
                entry.value.record(landingIn: value, at: place.child(.entryValue(position)), in: table, into: &coercions)
            }

        default:
            if let coercion = Coercion(folded.asHeld, landingIn: declared, in: table) {
                coercions.record(coercion, at: place)
            }
        }
    }
}
