//
//  Slot.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A parameter as the run reads it: what the boundary asks of an argument,
// and nothing else. The name for a refusal, the shape to settle against,
// the default where nothing was given, and the members the settled value
// must be one of. The declaration's type is not here; its lowering is.
final class Slot: Sendable {
    // MARK: - Property
    let name: Name
    let type: LoweredType
    let `default`: Value?
    let candidates: [Candidate]?

    // MARK: - Initializer
    init(name: Name, type: LoweredType, default: Value?, candidates: [Candidate]?) {
        self.name = name
        self.type = type
        self.default = `default`
        self.candidates = candidates
    }

    // MARK: - Public
    func mustBeGiven(in table: LoweredTypeTable) -> Bool {
        type.mustBeGiven(default: `default`, in: table)
    }

    // An argument as given, or the default where nothing was.
    func taking(_ value: Value, in table: LoweredTypeTable) throws -> Value {
        guard value != .null else {
            guard let fallback = self.default else {
                // A type that declares null holds it as a value, so a null
                // here is what was given rather than the absence of anything.
                guard type.declaresNull(in: table) else {
                    throw ArgumentError("input '\(name)': required, and nothing was given")
                }

                return try checking(value, in: table)
            }

            // The fallback walks through the same gate an argument does, so
            // the body reads the declared representation either way.
            return try checking(fallback, in: table)
        }

        return try checking(value, in: table)
    }

    // A receiver checked as this slot, except that nothing passes through. A
    // word decides for itself what being sent to nothing means: `contains`
    // says false rather than failing, and a path that reached null is
    // absence rather than misuse.
    func checking(receiver value: Value, in table: LoweredTypeTable) throws -> Value {
        guard value != .null else { return value }

        return try checking(value, in: table)
    }

    // The value settled to the declared representation, and held to the
    // spellings where the declaration lists them.
    func checking(_ value: Value, in table: LoweredTypeTable) throws -> Value {
        if value == .null {
            // Null passes where the declaration says it is a value: a `T?`
            // slot, or the legacy spelling of the same fact, an explicitly
            // null default.
            guard self.default == .null || type.declaresNull(in: table) else {
                throw ArgumentError("input '\(name)': expected \(type.rendered(in: table)), got null")
            }

            return value
        }

        let settled = try type.settling(value, at: "input '\(name)'", in: table)

        if let candidates {
            let written = candidates.map(\.spelling)

            switch settled {
            // A number meets the members by worth. Only the canonical
            // spellings name one, because an alias is a dead member the link
            // already refused.
            case .int, .double:
                guard candidates.contains(where: { candidate in
                    candidate.numeral.map { numeral in
                        Value.order(numeral, settled) == .orderedSame
                    } ?? false
                }) else {
                    throw ArgumentError(
                        "input '\(name)': '\(Self.shown(settled))' not in enum \(written)"
                    )
                }

            default:
                let scalar = Self.scalar(settled)

                guard let scalar, written.contains(scalar) else {
                    throw ArgumentError(
                        "input '\(name)': '\(scalar ?? "\(settled.type)")' not in enum \(written)"
                    )
                }
            }
        }

        return settled
    }

    // MARK: - Private
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

    // A number as a refusal shows it: the value's own spelling.
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

extension Array where Element == Slot {
    // Where the receiver stands among these, for a declaration that takes
    // one. A position is a fact about the lowered slots, so it is read off
    // them rather than worked out from the declaration a second time.
    func position(of receiver: Name?) -> Int? {
        receiver.flatMap { name in firstIndex { slot in slot.name == name } }
    }
}

extension Parameter {
    // This parameter as the run reads it. An undeclared type lowers to
    // `any`: the boundary tells "nothing written" from "`any` written" in no
    // way, so the slot does not either.
    func lowered(named name: Name, in table: LoweredTypeTable) -> Slot {
        slot(named: name, holding: declared.lowered(in: table), in: table)
    }

    // The same, with what a call put in the type parameters written in. A
    // parameter nothing filled reads `any`, which is what the call said about
    // it by saying nothing.
    func lowered(named name: Name, in table: LoweredTypeTable, filling bound: [Name: LoweredType]) -> Slot {
        slot(named: name, holding: declared.lowered(in: table).filling(bound), in: table)
    }

    private func slot(named name: Name, holding type: LoweredType, in table: LoweredTypeTable) -> Slot {
        Slot(
            name: name,
            type: type,
            default: `default`,
            candidates: candidates.map { written in
                written.map { spelling in Candidate(spelling, in: type, reading: table) }
            }
        )
    }
}
