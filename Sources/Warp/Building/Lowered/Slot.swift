//
//  Slot.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// A parameter as the run reads it: what the boundary asks of an argument,
// and nothing else. The name for a refusal, the type to settle against, and
// the members the settled value must be one of. The declaration's type is
// not here; its lowering is.
final class Slot: Sendable {
    // MARK: - Property
    let name: Name
    let type: LoweredType
    let candidates: [Candidate]?

    // MARK: - Initializer
    init(name: Name, type: LoweredType, candidates: [Candidate]?) {
        self.name = name
        self.type = type
        self.candidates = candidates
    }

    // MARK: - Public
    // Whether a call must write this argument: the type's one answer, for
    // the call check, the boundary and path reachability alike.
    func mustBeGiven(in table: LoweredTypeTable) -> Bool {
        type.mustBeGiven(in: table)
    }

    // An argument as given, or the null a nullable declares where nothing
    // was. Nil is the absence: a key the call never wrote. A null is a value
    // like any other and goes to the type, which says whether it holds one.
    func taking(_ value: Value?, in table: LoweredTypeTable) throws -> Value {
        guard let value else {
            guard type.declaresNull(in: table) else {
                throw ArgumentError("input '\(name)': required, and nothing was given")
            }

            return try checking(.null, at: "input '\(name)'", in: table)
        }

        return try checking(value, at: "input '\(name)'", in: table)
    }

    // The value settled to the declared representation, and held to the
    // spellings where the declaration lists them. `locus` is where a refusal
    // says the value stood, in the caller's terms: an argument is named by
    // its key, and a receiver by the procedure it was sent to.
    func checking(_ value: Value, at locus: String, in table: LoweredTypeTable) throws -> Value {
        if value == .null {
            guard type.admitsNull(in: table) else {
                throw ArgumentError("\(locus): expected \(type.rendered(in: table)), got null")
            }

            return value
        }

        let settled = try type.settling(value, at: locus, in: table)

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
                        "\(locus): '\(Self.shown(settled))' not in enum \(written)"
                    )
                }

            default:
                let scalar = Self.scalar(settled)

                guard let scalar, written.contains(scalar) else {
                    throw ArgumentError(
                        "\(locus): '\(scalar ?? "\(settled.type)")' not in enum \(written)"
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
