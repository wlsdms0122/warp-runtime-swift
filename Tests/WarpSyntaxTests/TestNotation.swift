//
//  TestNotation.swift
//  WarpSyntaxTests
//
//  Created by JSilver
//

import Foundation
import Warp
import WarpSyntax

// A notation of the plainest kind: an operator record is a subject and a
// procedure sent to it, `{ of: <expression>, <procedure>: <expression> }`, and
// the operand lands under `value`.
//
// The table is one line per procedure: a key is the bare name of the declaration it
// reaches, and a key not in the table is sent as written. What a real notation
// does with the same hole, `is` reaching `std.logic.equal`, a connective
// wrapping its sides, a spelling that takes no subject, is that notation's, and
// it is tested where it lives.
struct TestConditions: ExpressionSpelling {
    // MARK: - Property
    static let subjectKey: Name = "of"
    static let operandKey: Name = "value"

    // A record carrying a subject is a message written this way, and a record
    // that is not is the expression it is.
    func claims(_ names: Set<Name>) -> Bool {
        names.contains(Self.subjectKey)
    }

    func quoting(record fields: Value.Dictionary) -> Value? { nil }

    // What the table stands in for, and so what this spelling owes the build.
    var vocabulary: Set<Name> { Set(Self.procedures.values) }

    // The key a condition is spelled with, and the declaration it names.
    static let procedures: [Name: Name] = [
        "equal": "std.logic.equal",
        "notEqual": "std.logic.notEqual",
        "contains": "std.collection.contains",
        "startsWith": "std.text.startsWith",
        "lessThan": "std.math.lessThan",
        "greaterThan": "std.math.greaterThan",
        "longerThan": "extra.longerThan"
    ]

    // MARK: - Initializer
    // MARK: - Public
    func expression(from decoder: Decoder) throws -> Warp.Expression {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = container.allKeys
            .map(\.stringValue)
            .filter { key in key != Self.subjectKey.spelling }

        guard found.count == 1, let procedure = found.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "an operator record is one key and its subject."
                        + " { of: <expression>, <procedure>: <expression> }; found: \(found.sorted())"
                )
            )
        }

        return .call(
            Call(
                receiver: try container.decode(
                    ExpressionReader.self,
                    forKey: AnyCodingKey(stringValue: Self.subjectKey.spelling)
                )
                .expression,
                selector: try Self.procedures[Name(procedure)] ?? Name(procedure),
                arguments: [
                    Self.operandKey: try container.decode(
                        ExpressionReader.self,
                        forKey: AnyCodingKey(stringValue: procedure)
                    )
                    .expression
                ]
            )
        )
    }

    // MARK: - Private
}

extension Notation {
    // What these tests read with. The procedures are the standard ones because the
    // fixtures link against the standard modules, not because this notation
    // knows anything about them.
    static let testing = Notation(
        spelling: TestConditions(),
        interpolation: Interpolation(read: "std.text.text", joined: "std.text.joined")
    )
}

// A spelling with one key of its own, `holds`, reaching a procedure no
// standard bundle declares, so what it owes is told apart from what the
// standard table owes.
struct OwnVocabularyConditions: ExpressionSpelling {
    // MARK: - Property
    let vocabulary: Set<Name> = ["example.holds"]

    func claims(_ names: Set<Name>) -> Bool {
        names.contains("holds")
    }

    func quoting(record fields: Value.Dictionary) -> Value? { nil }

    // MARK: - Initializer
    // MARK: - Public
    func expression(from decoder: Decoder) throws -> Warp.Expression {
        .call(
            Call(
                receiver: try decoder.container(keyedBy: AnyCodingKey.self)
                    .decode(ExpressionReader.self, forKey: AnyCodingKey(stringValue: "holds"))
                    .expression,
                selector: "example.holds"
            )
        )
    }

    // MARK: - Private
}
