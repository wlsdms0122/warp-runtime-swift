//
//  TypeExpression+Binding.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Working out what a call put in a declaration's type parameters, and reading
// the answer with those parameters filled.
//
// This is the whole of what a type parameter costs. Nothing infers across
// statements and nothing is solved: a call site is one place, what it hands over
// is already known there, and the parameters are read off by walking the
// declaration beside what arrived.
extension TypeExpression {
    // What the type parameters in this declaration stand for, given what
    // arrived. Walked in step: where the declaration has a parameter, whatever
    // sits opposite it is what the parameter stands for; where both have a
    // shape, the walk goes inside.
    //
    // A parameter reached twice has to be read the same both times. Two readings are
    // a disagreement rather than a reason to give up: widening to `any` was the
    // checker announcing it had stopped checking, and it announced it silently —
    // a list of strings handed an int to append read `Element` as `any` and the
    // call went through.
    //
    // Refusing instead is what one signature needs to say what several would
    // have said. `plus` declaring `some N` on both sides and answering `some N`
    // is a whole number added to a whole number answering a whole number, and a
    // whole number added to a fraction refused — without the language growing a
    // way to declare a name twice.
    func binding(
        against given: TypeExpression,
        into bound: inout [String: TypeExpression],
        disagreeing: inout [String: TypeExpression],
        in table: ShapeTable
    ) {
        switch (self, given) {
        case let (.parameter(name, _), _):
            guard let already = bound[name] else {
                bound[name] = given

                return
            }

            guard already != given else { return }

            // Two readings agree when one takes the other — a list of numbers
            // and a whole number are not a disagreement, they are a parameter
            // read once loosely and once tightly, and the loose reading is the
            // one that holds both.
            // `any` first, because it is the loosest reading there is and
            // `accepts` cannot order it: everything takes `any` and `any` takes
            // everything, so asking which is looser answers yes both ways and
            // whichever was read first would win. A parameter read as `any`
            // anywhere is `any`, which is what a list of anything says about
            // what may be put in it.
            guard already != .any else { return }

            guard given != .any else {
                bound[name] = .any

                return
            }

            // With the table, because a reading may be a name a module
            // declared and the shape that name stands for. Asking without it
            // would call those two a disagreement, which is the same question
            // the link asks elsewhere and answers correctly.
            if already.accepts(given, in: table) { return }

            if given.accepts(already, in: table) {
                bound[name] = given

                return
            }

            // The first reading is kept so that what is reported names both,
            // and so that everything downstream sees one answer rather than a
            // parameter that is two things.
            disagreeing[name] = given

        // A parameter inside a nullable slot is read from the declared half —
        // null carries no reading, and a nullable arrival reads by its own
        // declared half for the same reason.
        case let (.nullable(mine), .nullable(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.nullable(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        // `bytes` is `array<byte>` in a compact spelling, so an element
        // parameter reads a byte from it — `first` on bytes answers one.
        case (.array(let mine), .bytes):
            mine.binding(against: .byteElement, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.object(mine), .object(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.sorted(by: { Name.precedes($0.key, $1.key) }) {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &bound, disagreeing: &disagreeing, in: table)
            }

        case let (.variable(mine), _), let (.inout(mine), _):
            mine.binding(against: given, into: &bound, disagreeing: &disagreeing, in: table)

        case let (_, .variable(theirs)), let (_, .inout(theirs)):
            binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: table)

        case let (.procedure(.some(mine), _, _), .procedure(.some(theirs), _, _)):
            for (name, parameter) in mine.parameters.sorted(by: { Name.precedes($0.key, $1.key) }) {
                guard let opposite = theirs.parameters[name] else { continue }

                parameter.declared.binding(against: opposite.declared, into: &bound, disagreeing: &disagreeing, in: table)
            }

            (mine.returns ?? .any).binding(against: theirs.returns ?? .any, into: &bound, disagreeing: &disagreeing, in: table)

        default:
            return
        }
    }

    // This type with every parameter replaced by what it was read as. A
    // parameter nothing filled reads `any`, which is what a declaration says
    // when it says nothing.
    func filling(_ bound: [String: TypeExpression]) -> TypeExpression {
        switch self {
        case let .parameter(name, _):
            return bound[name] ?? .any

        // Nothing fills a walk through a parameter — it is named for a path
        // only the body that wrote it can read, and no call site says
        // anything about that. So the caller reads what a declaration saying
        // nothing says.
        case .reading:
            return .any

        case let .array(element):
            return .array(element.filling(bound))

        case let .object(entry):
            return .object(entry.filling(bound))

        case let .record(fields):
            return .record(fields.mapValues { field in field.filling(bound) })

        case let .procedure(signature, purity, isolation):
            return .procedure(signature?.filling(bound), purity, isolation)

        case let .variable(inner):
            return .variable(inner.filling(bound))

        case let .inout(inner):
            return .inout(inner.filling(bound))

        case let .nullable(inner):
            return .nullable(inner.filling(bound))

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return self
        }
    }

    // Every type parameter mentioned in here, each with the constraint names
    // carried on it. A set per name, because occurrences carry the bound
    // separately: `some T` bounded in one slot and bare in another are one
    // parameter bounded once, and two occurrences carrying different
    // constraints are two claims about one name — a disagreement the link
    // refuses rather than picks from.
    func parameterConstraints(into table: inout [String: Set<String>]) {
        switch self {
        case let .parameter(name, constraint):
            table[name, default: []].formUnion(constraint.map { bound in [bound] } ?? [])

        // Not a slot a signature declares, and it carries no bound to claim
        // — there is nothing here for a `bounds` to speak for.
        case .reading:
            return

        case let .array(element), let .object(element), let .nullable(element):
            element.parameterConstraints(into: &table)

        case let .record(fields):
            for field in fields.values {
                field.parameterConstraints(into: &table)
            }

        case let .procedure(signature, _, _):
            signature?.parameterConstraints(into: &table)

        case let .variable(inner), let .inout(inner):
            inner.parameterConstraints(into: &table)

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return
        }
    }

    // Whether anything in here is a type parameter. A declaration without one
    // is read the way it always was, so nothing pays for a feature it does not
    // use.
    var isGeneric: Bool {
        switch self {
        // Both are shapes a call decides, and the deep question is only
        // whether this declaration has to be filled at all.
        case .parameter, .reading:
            return true

        case let .array(element), let .object(element), let .nullable(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(signature, _, _):
            return signature?.isGeneric ?? false

        case let .variable(inner), let .inout(inner):
            return inner.isGeneric

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return false
        }
    }
}

public extension Signature {
    func filling(_ bound: [String: TypeExpression]) -> Signature {
        Signature(
            receiver: receiver,
            parameters: parameters.mapValues { parameter in
                Parameter(
                    type: parameter.type?.filling(bound),
                    oneOf: parameter.oneOf,
                    default: parameter.default,
                    hint: parameter.hint
                )
            },
            returns: returns?.filling(bound)
        )
    }

    var isGeneric: Bool {
        parameters.values.contains { parameter in parameter.declared.isGeneric }
            || (returns?.isGeneric ?? false)
    }

    // The type parameters this signature declares, by mention, with every
    // constraint name written on each. One name may be mentioned bare and
    // bounded; the bound mention speaks for both.
    //
    // A nested signature's parameters merge into the same table on purpose —
    // they are this signature's own slots: `map` takes `array<some Element>`
    // beside a procedure whose `item` is the same `some Element`, and it is
    // one parameter filled by one call. Only a parameter behind a `named`
    // type is not collected, because the link refuses one anywhere but a
    // procedure signature and never fills one through the name.
    func parameterConstraints(into table: inout [String: Set<String>]) {
        for parameter in parameters.values {
            parameter.declared.parameterConstraints(into: &table)
        }

        returns?.parameterConstraints(into: &table)
    }

    // This signature with each type parameter's occurrences carrying the
    // constraint declared for its name. The signature owns the bound and the
    // occurrences read it — a notation writes `bounds: { N: Numeric }` once and
    // `some N` in the slots, and this is where the one meets the many.
    //
    // An occurrence already carrying a bound keeps it: a nested signature may
    // have declared its own, and overwriting would silently pick between two
    // claims the link refuses out loud.
    func bounded(by bounds: [String: String]) -> Signature {
        guard !bounds.isEmpty else { return self }

        return Signature(
            receiver: receiver,
            parameters: parameters.mapValues { parameter in
                Parameter(
                    type: parameter.type?.bounded(by: bounds),
                    oneOf: parameter.oneOf,
                    default: parameter.default,
                    hint: parameter.hint
                )
            },
            returns: returns?.bounded(by: bounds)
        )
    }
}

extension TypeExpression {
    // The occurrence side of `Signature.bounded(by:)`, walked through every
    // place a type parameter may sit — a nested signature's parameters
    // included, because they are the outer signature's own slots.
    func bounded(by bounds: [String: String]) -> TypeExpression {
        switch self {
        case let .parameter(name, constraint):
            return .parameter(name: name, constraint: constraint ?? bounds[name])

        case .reading:
            return self

        case let .array(element):
            return .array(element.bounded(by: bounds))

        case let .object(entry):
            return .object(entry.bounded(by: bounds))

        case let .record(fields):
            return .record(fields.mapValues { field in field.bounded(by: bounds) })

        case let .procedure(signature, purity, isolation):
            return .procedure(signature?.bounded(by: bounds), purity, isolation)

        case let .nullable(inner):
            return .nullable(inner.bounded(by: bounds))

        case let .variable(inner):
            return .variable(inner.bounded(by: bounds))

        case let .inout(inner):
            return .inout(inner.bounded(by: bounds))

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .ranged, .named:
            return self
        }
    }
}
