//
//  ClosureAnswering.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// A closure a value holds, answered with the row it stands at: found by its
// spelling, held to that row's frame, and standing as the row is once the
// row itself is answered. One door for the link and for a compile laying
// objects down, so a third asker answers alike without hearing of it.
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

    private var answered: [Linked?]
    private var underway: [Bool]

    // MARK: - Initializer
    init(spelled: ClosureRows, table: [Linked], documents: [Place.Document]) {
        self.spelled = spelled
        self.table = table
        self.documents = documents
        self.answered = Array(repeating: nil, count: table.count)
        self.underway = Array(repeating: false, count: table.count)
    }

    // MARK: - Public
    // The row at a position, answered once. The rewriting says what
    // answering a row is for whoever asks, handed the row as it stands.
    func row(at row: Int, rewriting: (Linked) throws -> Linked) throws -> Linked {
        if let done = answered[row] { return done }

        guard !underway[row] else {
            throw BuildError.unjudged(
                "a closure closing a ring of rows through the values they hold",
                at: .procedure(table[row].label.spelling, in: documents[table[row].origin])
            )
        }

        underway[row] = true
        defer { underway[row] = false }

        let done = try rewriting(table[row])

        answered[row] = done

        return done
    }

    // A closure a value holds, standing as the row the link answers for it.
    func answered(_ closure: Closure, at place: Place, rewriting: (Linked) throws -> Linked) throws -> Closure {
        let row = try spelled.row(of: closure, at: place)

        try held(closure, to: table[row], at: place)

        return closure.standing(as: try self.row(at: row, rewriting: rewriting))
    }

    // MARK: - Private
    // What a closure took with it fills exactly the slots its frame says a
    // closure fills: no fewer, since a cell left out reads as null, and none
    // other, since a slot a parameter or a variable fills is not one a
    // closure took. A value saying otherwise is a closure no body stood up,
    // and it is refused here rather than read into the frame at the run.
    private func held(_ closure: Closure, to row: Linked, at place: Place) throws {
        guard case let .body(_, frame) = row.implementation else {
            throw BuildError.unjudged("closure \(closure.nth) of '\(closure.writer.name)' standing on a native row", at: place)
        }

        guard closure.captured.count == frame.captures.count,
              Set(closure.captured.map(\.slot)) == Set(frame.captures)
        else {
            throw BuildError(
                "closure \(closure.nth) of '\(closure.writer.name)' holds cells at"
                    + " \(closure.captured.map(\.slot).sorted()), and its frame is filled at \(frame.captures.sorted())",
                at: place
            )
        }
    }
}
