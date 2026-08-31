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
        // The elements as the document wrote them, beside what they read as.
        // A walk into an array knows it descended by position and no more; this
        // is the one reader that knows the positions hold statements, so the
        // names an author knows them by are its to put on — and the only ones
        // it puts on, since everywhere else an element is a position.
        let written = (try ValueReader(from: decoder).value.elements).map(Array.init) ?? []
        let depth = decoder.steps.count

        func name(at position: Int) -> String? {
            written.indices.contains(position) ? StatementReader.name(of: written[position]) : nil
        }

        let statements: [Statement]

        do {
            statements = try [StatementReader](from: decoder).map(\.statement)
        } catch let refusal as ReadingError {
            throw refusal.naming(at: depth, name(at:))
        }

        for (position, statement) in statements.dropLast().enumerated()
        where statement.expression.alwaysLeaves {
            throw ReadingError(
                "every way through this statement leaves,"
                    + " and what follows it here would never run",
                at: decoder.steps + [.statement(name(at: position), at: position)]
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
        at steps: [Place.Step]
    ) throws -> Block {
        if body.alwaysLeaves, result != nil {
            throw ReadingError(
                "result: nothing runs after leaving,"
                    + " and this result would never be reached",
                at: steps
            )
        }

        return Block(body: body, result: result)
    }
}
