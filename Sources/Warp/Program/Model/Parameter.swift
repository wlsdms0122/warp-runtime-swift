//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    // What this takes, or nil where nothing was declared. `any` is a claim that
    // any shape is welcome; nil is the absence of a claim. Neither is checked,
    // and keeping them apart is what lets the ones written on purpose be told
    // from the ones nobody got around to.
    public let type: TypeExpression?
    public let oneOf: [String]?
    public let `default`: Value?
    public let hint: String?

    // Whether a call must write this argument — the one question, answered in
    // one place for the call check, the boundary and path reachability alike.
    // A default answers omission with a value; a type that declares null
    // (`T?`) answers it with the null it holds. Without either, omission is a
    // missing argument. Optionality has no third axis.
    public func mustBeGiven(in types: TypeTable) -> Bool {
        `default` == nil && !declared.declaresNull(in: types)
    }

    // What this reads as where a type is needed regardless. An undeclared
    // parameter accepts what it is handed, which is what `any` says.
    public var declared: TypeExpression { type ?? .any }

    // MARK: - Initializer
    public init(
        type: TypeExpression? = nil,
        oneOf: [String]? = nil,
        default: Value? = nil,
        hint: String? = nil
    ) {
        self.type = type
        self.oneOf = oneOf
        self.default = `default`
        self.hint = hint
    }

    // MARK: - Public
    public func taking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        guard value != .null else {
            guard let fallback = self.default else {
                // A type that declares null holds it as a value, so a null
                // here is what was given rather than the absence of anything.
                guard declared.declaresNull(in: types) else {
                    throw ArgumentError("input '\(name)': required, and nothing was given")
                }

                return try checking(value, called: name, in: types)
            }

            // The fallback walks through the same gate an argument does, so the
            // body reads the declared representation either way — a default is
            // a value the call left out, not a value the declaration skips.
            return try checking(fallback, called: name, in: types)
        }

        return try checking(value, called: name, in: types)
    }

    // A receiver checked as this parameter, except that nothing passes
    // through. A word decides for itself what being sent to nothing means:
    // `contains` says false rather than failing, and a path that reached null
    // is absence rather than misuse.
    public func checking(
        receiver value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        guard value != .null else { return value }

        return try checking(value, called: name, in: types)
    }

    public func checking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        if value == .null {
            // Null passes where the declaration says it is a value — a `T?`
            // slot, or the legacy spelling of the same fact, an explicitly
            // null default. Both gatekeepers ask the type first, so what the
            // link accepted the boundary accepts too.
            guard self.default == .null || declared.declaresNull(in: types) else {
                throw ArgumentError("input '\(name)': expected \(declared), got null")
            }

            return value
        }

        // Settling means the inside reads the declared type — a passing value is
        // normalized to the declared representation, not just waved through, and
        // the walk goes as deep as the declaration does. Undeclared has no
        // representation to normalize to, so the value stands as it arrived.
        let settled = try type.map { type in
            try type.settling(value, at: "input '\(name)'", in: types)
        } ?? value

        if let allowed = oneOf {
            switch settled {
            // A number meets the candidates by worth, the way the language
            // compares numbers — `-0.0` is in a list that writes `0.0`. How
            // a candidate is *written* was the link's question: only the
            // canonical spellings read here, because an alias is a dead
            // member the link already refused.
            case .int, .double:
                guard allowed.contains(where: { candidate in
                    Self.numeral(candidate, as: type, in: types).map { numeral in
                        Value.order(numeral, settled) == .orderedSame
                    } ?? false
                }) else {
                    throw ArgumentError(
                        "input '\(name)': '\(Self.shown(settled))' not in oneOf \(allowed)"
                    )
                }

            default:
                let scalar = Self.scalar(settled)

                guard let scalar, allowed.contains(scalar) else {
                    throw ArgumentError(
                        "input '\(name)': '\(scalar ?? "\(settled.type)")' not in oneOf \(allowed)"
                    )
                }
            }
        }

        return settled
    }

    // MARK: - Private
    // A candidate read as the number its canonical spelling names *for the
    // declared slot* — a fraction slot reads only fraction spellings, so the
    // boundary and the link agree on which members exist: what the link
    // called a dead member, this answers nil for, and nothing else. Internal
    // because the link's candidate judge reads through this same door.
    static func numeral(
        _ candidate: String,
        as declared: TypeExpression?,
        in types: TypeTable
    ) -> Value? {
        switch declared {
        case .int:
            return Int(spelling: candidate).map(Value.int)

        // A range is a condition on a number, so the spelling it reads is the
        // spelling of the kind under it.
        case let .ranged(refinement):
            return numeral(candidate, as: refinement.kind, in: types)

        case .double:
            return Double(spelling: candidate).map(Value.double)

        case let .named(name):
            return types.resolve(name).flatMap { resolved in
                numeral(candidate, as: resolved, in: types)
            }

        case let .nullable(inner):
            return numeral(candidate, as: inner, in: types)

        // `number`, a parameter a constraint bounds, and the slots that
        // declare no numeric shape at all: the slot does not name one kind,
        // so a numeral is whichever kind's one spelling the text is, and
        // membership is worth across the kinds the way the language compares
        // numbers — deliberately the same reading the link's candidate judge
        // takes for these slots.
        default:
            if let word = Int(spelling: candidate) { return .int(word) }

            return Double(spelling: candidate).map(Value.double)
        }
    }

    private static func scalar(_ value: Value) -> String? {
        switch value {
        case let .string(string):
            return string

        case let .bool(bool):
            return String(bool)

        default:
            return nil
        }
    }

    // A number as a refusal shows it — the value's own spelling, not the
    // template layer's, so a declaration model owes nothing to the runtime's
    // rendering rules.
    private static func shown(_ settled: Value) -> String {
        switch settled {
        case let .int(integer):
            return String(integer)

        case let .double(double):
            return double.spelling ?? "\(double)"

        default:
            return "\(settled.type)"
        }
    }
}
