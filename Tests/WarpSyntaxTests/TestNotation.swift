//
//  TestNotation.swift
//  WarpSyntaxTests
//
//  Created by JSilver
//

import Foundation
import Warp
import WarpSyntax

// A notation of the plainest kind: a condition is a subject and a word sent to
// it, `{ of: <expression>, <word>: <expression> }`, and the operand lands under
// `value`.
//
// The table is one line per word: a key is the bare name of the declaration it
// reaches, and a key not in the table is sent as written. What a real notation
// does with the same hole, `is` reaching `std.logic.equal`, a connective
// wrapping its sides, a spelling that takes no subject, is that notation's, and
// it is tested where it lives.
struct TestConditions: ConditionSpelling {
    // MARK: - Property
    static let subjectKey: Name = "of"
    static let operandKey: Name = "value"

    // A record carrying a subject is a condition written this way, and a record
    // that is not is the expression it is.
    let keys: Set<Name> = [subjectKey]

    // What the table stands in for, and so what this spelling owes the link.
    var vocabulary: Set<Name> { Set(Self.words.values) }

    // The word a condition is spelled with, and the declaration it names.
    static let words: [Name: Name] = [
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
    func condition(from decoder: Decoder) throws -> Warp.Expression {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = container.allKeys
            .map(\.stringValue)
            .filter { key in key != Self.subjectKey.spelling }

        guard found.count == 1, let word = found.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "a condition is one word and its subject —"
                        + " { of: <expression>, <word>: <expression> }; found: \(found.sorted())"
                )
            )
        }

        return .dispatch(
            Dispatch(
                receiver: try container.decode(
                    ExpressionReader.self,
                    forKey: AnyCodingKey(stringValue: Self.subjectKey.spelling)
                )
                .expression,
                selector: try Self.words[Name(word)] ?? Name(word),
                arguments: [
                    Self.operandKey: try container.decode(
                        ExpressionReader.self,
                        forKey: AnyCodingKey(stringValue: word)
                    )
                    .expression
                ]
            )
        )
    }

    // MARK: - Private
}

extension Notation {
    // What these tests read with. The words are the standard ones because the
    // fixtures link against the standard modules, not because this notation
    // knows anything about them.
    static let testing = Notation(
        condition: TestConditions(),
        interpolation: Interpolation(read: "std.text.text", joined: "std.text.joined")
    )
}

// A condition spelling with one key of its own, `holds`, reaching a word no
// standard bundle declares, so what it owes is told apart from what the
// standard table owes.
struct WordedConditions: ConditionSpelling {
    // MARK: - Property
    let keys: Set<Name> = ["holds"]

    let vocabulary: Set<Name> = ["example.holds"]

    // MARK: - Initializer
    // MARK: - Public
    func condition(from decoder: Decoder) throws -> Warp.Expression {
        .dispatch(
            Dispatch(
                receiver: try decoder.container(keyedBy: AnyCodingKey.self)
                    .decode(ExpressionReader.self, forKey: AnyCodingKey(stringValue: "holds"))
                    .expression,
                selector: "example.holds"
            )
        )
    }

    // MARK: - Private
}
