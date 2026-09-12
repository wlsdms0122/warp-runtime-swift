//
//  LoweredType+Binding.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// Working out what a call put in a declaration's type parameters, and reading
// the answer with those parameters filled.
//
// This is the whole of what a type parameter costs. Nothing infers across
// statements and nothing is solved: a call site is one place, what it hands over
// is already known there, and the parameters are read off by walking the
// declaration beside what arrived.
extension LoweredType {
    // What the type parameters in this declaration stand for, given what
    // arrived. Walked in step: where the declaration has a parameter, whatever
    // sits opposite it is what the parameter stands for; where both have a
    // shape, the walk goes inside.
    //
    // A parameter reached twice has to be read the same both times. Two
    // readings are a disagreement rather than a reason to give up: widening to
    // `any` was the checker announcing it had stopped checking, and it
    // announced it silently. A list of strings handed an int to append read
    // `Element` as `any` and the call went through.
    //
    // Refusing instead is what one signature needs to say what several would
    // have said. `plus` declaring `some N` on both sides and answering `some N`
    // is a whole number added to a whole number answering a whole number, and a
    // whole number added to a fraction refused, without the language growing a
    // way to declare a name twice.
    func binding(
        against given: LoweredType,
        into bound: inout [Name: LoweredType],
        disagreeing: inout [Name: LoweredType],
        in table: LoweredTypeTable
    ) {
        switch (self, given) {
        case let (.parameter(name, _), _):
            guard let already = bound[name] else {
                bound[name] = given

                return
            }

            guard already != given else { return }

            // Two readings agree when one takes the other. A list of numbers
            // and a whole number are not a disagreement, they are a parameter
            // read once loosely and once tightly, and the loose reading is the
            // one that holds both. `any` first, because it is the loosest
            // reading there is and `accepts` cannot order it: everything takes
            // `any` and `any` takes everything, so asking which is looser
            // answers yes both ways and whichever was read first would win. A
            // parameter read as `any` anywhere is `any`, which is what a list
            // of anything says about what may be put in it.
            guard already != .any else { return }

            guard given != .any else {
                bound[name] = .any

                return
            }

            // With the table, because a reading may stand on a row and the
            // shape that row holds. Asking without it would call those two a
            // disagreement, which is the same question the link asks elsewhere
            // and answers correctly.
            if already.accepts(given, in: table) { return }

            if given.accepts(already, in: table) {
                bound[name] = given

                return
            }

            // The first reading is kept so that what is reported names both,
            // and so that everything downstream sees one answer rather than a
            // parameter that is two things.
            disagreeing[name] = given

        // A parameter inside a nullable slot is read from the declared half.
        // Null carries no reading, and a nullable arrival reads by its own
        // declared half for the same reason.
        case let (.nullable(mine), .nullable(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.nullable(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        // `bytes` is `array<byte>` in a compact spelling, so an element
        // parameter reads a byte from it. `first` on bytes answers one.
        case (.array(let mine), .bytes):
            mine.binding(against: .byteElement, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.dictionary(mine), .dictionary(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.named {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &bound, disagreeing: &disagreeing, in: table)
            }

        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, in: table)

        case let (_, .variable(theirs)), let (_, .inout(theirs)):
            binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.procedure(.some(mine), myAnswer, _, _), .procedure(.some(theirs), theirAnswer, _, _)):
            let opposite = Dictionary(theirs.map { slot in (slot.name, slot.type) }) { first, _ in first }

            for parameter in mine {
                guard let against = opposite[parameter.name] else { continue }

                parameter.type.binding(against: against, into: &bound, disagreeing: &disagreeing, in: table)
            }

            (myAnswer ?? .any).binding(
                against: theirAnswer ?? .any,
                into: &bound,
                disagreeing: &disagreeing,
                in: table
            )

        default:
            return
        }
    }

    // This shape with every parameter replaced by what it was read as. A
    // parameter nothing filled reads `any`, which is what a declaration says
    // when it says nothing.
    func filling(_ bound: [Name: LoweredType]) -> LoweredType {
        switch self {
        case let .parameter(name, _):
            return bound[name] ?? .any

        // Nothing fills a walk through a parameter. It is named for a path only
        // the body that wrote it can read, and no call site says anything about
        // that. So the caller reads what a declaration saying nothing says.
        case .reading:
            return .any

        case let .array(element):
            return .array(element.filling(bound))

        case let .dictionary(entry):
            return .dictionary(entry.filling(bound))

        case let .record(fields):
            return .record(
                LoweredRecord(
                    layout: fields.layout,
                    fields: fields.fields.map { field in field.filling(bound) }
                )
            )

        case let .procedure(parameters, returns, purity, isolation):
            return .procedure(
                parameters: parameters?.map { parameter in
                    (name: parameter.name, type: parameter.type.filling(bound), mustBeGiven: parameter.mustBeGiven)
                },
                returns: returns?.filling(bound),
                purity: purity,
                isolation: isolation
            )

        case let .variable(inner):
            return .variable(inner.filling(bound))

        case let .inout(inner):
            return .inout(inner.filling(bound))

        case let .nullable(inner):
            return .nullable(inner.filling(bound))

        default:
            return self
        }
    }
}
