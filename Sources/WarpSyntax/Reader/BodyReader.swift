//
//  BodyReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// A statement sequence, read as a body. Every body a document writes comes
// through here — a construct's, a block's, a fragment read on its own — because
// the one rule only a sequence can see lives where the sequence is read:
// nothing runs after a statement that leaves, so nothing may be written after
// one. A single statement cannot see its neighbours, which is why the rule is
// not `StatementReader`'s.
public struct BodyReader: Decodable {
    // MARK: - Property
    public let statements: [Statement]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let statements = try [StatementReader](from: decoder).map(\.statement)

        for (position, statement) in statements.dropLast().enumerated()
        where statement.expression.alwaysLeaves {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "[\(position)]: every way through this statement"
                        + " leaves, and what follows it here would never run"
                )
            )
        }

        self.statements = statements
    }

    // MARK: - Public
    // MARK: - Private
}

extension Block {
    // The other adjacency the same rule names: a result runs after the body,
    // so a body that always leaves would never reach it. Held where a
    // document's body/result pair is joined — every reader that assembles the
    // two comes through here, the way every statement sequence comes through
    // `BodyReader` — so the pair rule cannot be forgotten one assembler at a
    // time.
    static func reading(
        body: [Statement],
        result: Expression?,
        at codingPath: [any CodingKey]
    ) throws -> Block {
        if body.alwaysLeaves, result != nil {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "result: nothing runs after leaving,"
                        + " and this result would never be reached"
                )
            )
        }

        return Block(body: body, result: result)
    }
}
