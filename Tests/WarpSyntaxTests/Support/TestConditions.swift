//
//  TestConditions.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp
@testable import WarpSyntax

// A notation of the plainest kind: an operator record is a subject and a
// procedure sent to it, `{ of: <expression>, <procedure>: <expression> }`. The
// subject stands first and the operand second, the positions every standard
// procedure the table reaches takes them at.
//
// The table is one line per procedure: a key is the bare name of the declaration it
// reaches, and a key not in the table is sent as written. What a real notation
// does with the same hole, `is` reaching `std.logic.equal`, a connective
// wrapping its sides, a spelling that takes no subject, is that notation's, and
// it is tested where it lives.
struct TestConditions: ExpressionSpelling {
    // MARK: - Property
    static let subjectKey: Name = "of"

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
    // A record carrying a subject is a message written this way, and a record
    // that is not is the expression it is.
    func claims(_ names: Set<Name>, in notation: Notation) -> Bool {
        names.contains(Self.subjectKey)
    }

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
                selector: try Self.procedures[Name(procedure)] ?? Name(procedure),
                arguments: [
                    try container.decode(
                        ExpressionReader.self,
                        forKey: AnyCodingKey(stringValue: Self.subjectKey.spelling)
                    )
                    .expression,
                    try container.decode(
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
