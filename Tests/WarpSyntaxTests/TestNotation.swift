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
// There is no table. A key here *is* the word it names, so nothing in this
// package has to know which words a notation might spell — which is the point of
// these tests using one at all. What a real notation does with the same hole —
// `is` reaching `std.logic.equal`, a connective wrapping its sides, a spelling
// that takes no subject — is that notation's, and it is tested where it lives.
struct TestConditions: ConditionSpelling {
    // MARK: - Property
    static let subjectKey = "of"
    static let operandKey = "value"

    // A record carrying a subject is a condition written this way, and a record
    // that is not is the expression it is.
    let keys: Set<String> = [subjectKey]

    // Nothing stood in for, so nothing owed. Every word this spells is a word
    // the document named itself, and the link asks for those the way it asks
    // for any other.
    let vocabulary: Set<String> = []

    // MARK: - Initializer
    // MARK: - Public
    func condition(from decoder: Decoder) throws -> Warp.Expression {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let found = container.allKeys
            .map(\.stringValue)
            .filter { key in key != Self.subjectKey }

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
                    forKey: AnyCodingKey(stringValue: Self.subjectKey)
                )
                .expression,
                selector: word,
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
        interpolation: Interpolation(read: "text", joined: "joined")
    )
}

// A condition spelling whose keys reach words other than themselves, which is
// what makes its vocabulary observable at all. `TestConditions` names the word
// in the document, so it owes nothing.
struct WordedConditions: ConditionSpelling {
    // MARK: - Property
    let keys: Set<String> = ["holds"]

    let vocabulary: Set<String> = ["example.holds"]

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
