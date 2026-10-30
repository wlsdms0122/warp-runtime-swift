//
//  Coercion.swift
//  Warp
//
//  Created by JSilver on 10/23/26.
//

import Foundation

// What becomes of a value where its reading meets a place that reads it
// another way, as the type check judged it and lowering writes it down.
indirect enum Coercion: Sendable, Equatable {
    // One step of the walk to a part a promotion stands at: into each
    // element of a list, or into each key or each value of a dictionary.
    enum Step: Sendable, Equatable {
        case element
        case value
        case key
    }

    // A reading that is no contract, at a place reading a contract here or
    // in a list's, a dictionary's or an Optional's part: the value is held beside
    // what it was read as wherever the place reads a contract.
    case held(LoweredType, in: LoweredType)

    // A reading holding a contract, at `Any`: every type held in the value
    // drops.
    case dropped

    // A reading that may hold a none, at an Optional it meets as its some,
    // here or in the parts the steps walk to: what becomes of the value
    // first, then each part the steps reach as the Optional's some.
    case wrapped(Coercion?, steps: [Step])

    // MARK: - Property
    // What of this changes the value, each promotion and a drop, with the
    // holds left out, or nil where it only holds.
    var change: Coercion? {
        switch self {
        case .held:
            return nil

        case .dropped:
            return self

        case let .wrapped(inner, steps):
            return .wrapped(inner?.change, steps: steps)
        }
    }

    // MARK: - Initializer
    // What a reading landing in a declared type comes to, or nil where the
    // value lands as it came. A promotion a part needs stands after what
    // becomes of the whole, and the innermost first.
    init?(_ reading: LoweredType, landingIn declared: LoweredType, in table: LoweredTypeTable) {
        let coercion = declared.promotions(of: reading, wrappingOnly: true, in: table).reduce(Coercion(holding: reading, at: declared, in: table)) {
            inner, steps in .wrapped(inner, steps: steps)
        }

        guard let coercion else { return nil }

        self = coercion
    }

    // MARK: - Public
    // The value as it lands, `filling` reading a type parameter as what
    // fills it where the value lands.
    func applied(to value: Value, filling: (LoweredType) -> LoweredType, in table: LoweredTypeTable) -> Value {
        switch self {
        case let .held(reading, place):
            return place.holding(value, readAs: reading, filling: filling, in: table)

        case .dropped:
            return value.dropped

        case let .wrapped(inner, steps):
            return promoted(inner?.applied(to: value, filling: filling, in: table) ?? value, along: steps[...])
        }
    }

    func rewritten(type: (LoweredType) throws -> LoweredType) rethrows -> Coercion {
        switch self {
        case let .held(reading, place):
            return .held(try type(reading), in: try type(place))

        case .dropped:
            return self

        case let .wrapped(inner, steps):
            return .wrapped(try inner?.rewritten(type: type), steps: steps)
        }
    }

    // MARK: - Private
    // What becomes of a reading's value where the place reads a contract or
    // holds no type beside a value, or nil where neither.
    private init?(holding reading: LoweredType, at declared: LoweredType, in table: LoweredTypeTable) {
        if declared.holdsContract {
            guard reading != declared, !reading.isContract, reading != .never else { return nil }

            self = .held(reading, in: declared)
        } else if !declared.mayHoldExistential(in: table), reading.mayHoldExistential(in: table) {
            self = .dropped
        } else {
            return nil
        }
    }

    // The value with each part the steps reach as an Optional's some. A
    // step finding no list or no dictionary there passes the value as it is: the
    // none of an Optional around the part, or bytes, whose integers hold no
    // none.
    private func promoted(_ value: Value, along steps: ArraySlice<Step>) -> Value {
        guard let step = steps.first else { return value.asSome }

        switch (step, value) {
        case let (.element, .array(elements)):
            return .array(elements.map { element in promoted(element, along: steps.dropFirst()) })

        // A promotion keeps two keys two, and may move a key among the
        // others, so the entries are put in key order again.
        case let (.key, .dictionary(dictionary)):
            let entries = dictionary.entries.map { entry in (key: promoted(entry.key, along: steps.dropFirst()), value: entry.value) }

            return .dictionary(
                Value.Dictionary(
                    ordered: entries.sorted { one, other in
                        Value.Dictionary.order(one.key, other.key) == .orderedAscending
                    }
                )
            )

        case let (.value, .dictionary(dictionary)):
            return .dictionary(
                Value.Dictionary(
                    ordered: dictionary.entries.map { entry in
                        (key: entry.key, value: promoted(entry.value, along: steps.dropFirst()))
                    }
                )
            )

        default:
            return value
        }
    }
}
