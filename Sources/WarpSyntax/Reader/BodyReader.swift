//
//  BodyReader.swift
//  WarpSyntax
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

// A statement sequence, read as a body. Every body a document writes comes
// through here (a construct's, a block's, a fragment read on its own) because
// the one rule only a sequence can see lives where the sequence is read:
// nothing runs after a statement that leaves, so nothing may be written after
// one. A single statement cannot see its neighbours, which is why the rule is
// not `StatementReader`'s.
public struct BodyReader: Decodable {
    // MARK: - Property
    public let body: Body

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        // Nothing is done to what a statement refuses with. Each one names
        // itself as it is read, so a refusal arrives already wearing the name
        // the author knows it by.
        let statements = try decoder.read([StatementReader].self).map(\.statement)

        // What is refused here is a pair and not a statement, so the name is
        // read off the statement that was made rather than off the document a
        // second time.
        for (position, statement) in statements.dropLast().enumerated()
        where statement.expression.alwaysLeaves {
            throw ReadingError(
                "every way through this statement leaves,"
                    + " and what follows it here would never run",
                at: decoder.steps + [.statement(statement.name?.spelling, at: position)]
            )
        }

        self.body = Body(statements)
    }

    // MARK: - Public
    // MARK: - Private
}
