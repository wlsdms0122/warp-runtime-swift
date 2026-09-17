//
//  ClosureAnswering.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// A closure a value holds, answered with the row it stands at: found by its
// spelling, held to that row's frame, and standing as the row is once the
// row itself is answered. Answering a row is the closures its body's literal
// values hold answered the same way, which is every asker's rule, and the
// numbers its code carries read as the asker reads them, which is the
// asker's: a compile reads them against its own table as they are, and a
// link reads them into rows of its own. One door for both, so a third asker
// answers closures alike without hearing of it.
//
// Rows are answered once each, whichever asks first, and a row asked for
// again while its own answering is underway is a ring of rows holding
// closures of one another through the values in their bodies, which no
// build lowers. A class, since the rows answered are remembered across the
// askings that share one.
final class ClosureAnswering {
    // MARK: - Property
    private let spelled: ClosureRows
    private let table: [Linked]
    private let documents: [Place.Document]

    // What the asker makes of a row beyond its closures, where its numbers
    // read differently from how the table has them. One rule per door, since
    // a row is answered once and remembered.
    private let rewriting: ((Linked) throws -> Linked)?

    private var answered: [Linked?]
    private var underway: [Bool]

    // MARK: - Initializer
    init(
        spelled: ClosureRows,
        table: [Linked],
        documents: [Place.Document],
        rewriting: ((Linked) throws -> Linked)? = nil
    ) {
        self.spelled = spelled
        self.table = table
        self.documents = documents
        self.rewriting = rewriting
        self.answered = Array(repeating: nil, count: table.count)
        self.underway = Array(repeating: false, count: table.count)
    }

    // MARK: - Public
    // The row at a position, answered once.
    func row(at row: Int) throws -> Linked {
        if let done = answered[row] { return done }

        guard !underway[row] else {
            throw BuildError.unjudged(
                "a closure closing a ring of rows through the values they hold",
                at: .procedure(table[row].label.spelling, in: documents[table[row].origin])
            )
        }

        underway[row] = true
        defer { underway[row] = false }

        let done = try rewriting.map { rewriting in try rewriting(table[row]) } ?? standing(table[row])

        answered[row] = done

        return done
    }

    // A closure a value holds, standing as the row answered for it.
    func answered(_ closure: Closure, at place: Place) throws -> Closure {
        let row = try spelled.row(of: closure, at: place)

        try held(closure, to: table[row], at: place)

        return closure.standing(as: try self.row(at: row))
    }

    // A body with the closures its literal values hold answered, and every
    // other operation and every type read as the asker reads them. One pass,
    // since a body is rebuilt by the rewriting and the asker's reading rides
    // on the same one.
    func answered(
        _ body: Body,
        at place: Place,
        operation reading: (Operation) throws -> Operation = { operation in operation },
        type: (LoweredType) throws -> LoweredType = { type in type }
    ) throws -> Body {
        try body.rewritten(
            operation: { operation in
                guard case let .literal(value) = operation, value.holdsProcedure else { return try reading(operation) }

                return .literal(try value.rewritten { closure in try answered(closure, at: place) })
            },
            type: type
        )
    }

    // MARK: - Private
    // A row whose numbers stand as they are: its literal values answered and
    // nothing else touched. A body holding no procedure in a literal is the
    // row as it is, and is not rebuilt to find that out.
    private func standing(_ row: Linked) throws -> Linked {
        guard case let .body(body, frame) = row.implementation,
              body.contains(where: { node in
                  if case let .operation(.literal(value)) = node { return value.holdsProcedure }

                  return false
              })
        else {
            return row
        }

        return Linked(
            row,
            implementation: .body(
                try answered(body, at: .procedure(row.label.spelling, in: documents[row.origin])),
                frame
            ),
            sends: row.sends
        )
    }

    // What a closure took with it fills exactly the slots its frame says a
    // closure fills. A value saying otherwise is a closure no body stood up,
    // and it is refused here rather than read into the frame at the run.
    private func held(_ closure: Closure, to row: Linked, at place: Place) throws {
        guard case let .body(_, frame) = row.implementation else {
            throw BuildError.unjudged("closure \(closure.nth) of '\(closure.writer.name)' standing on a native row", at: place)
        }

        guard frame.fills(closure.captured.map(\.slot)) else {
            throw BuildError(
                "closure \(closure.nth) of '\(closure.writer.name)' holds cells at"
                    + " \(closure.captured.map(\.slot).sorted()), and its frame is filled at \(frame.captures.sorted())",
                at: place
            )
        }
    }
}
