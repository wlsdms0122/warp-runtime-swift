//
//  Lowering+ShapeNumbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

extension Lowering {
    // One document's rows with the shapes in them numbered by that document,
    // beside the numbering that says what those numbers stand for.
    //
    // Lowering reads the link's table to judge, so the shape rows it writes
    // are that link's. This turns them into the document's own, which is what
    // leaves compiling: a body carries its document's numbers and nothing
    // about the graph it was linked into.
    //
    // The order is the whole reason this stands apart from the lowering. A
    // document's numbering is its names in name order, and no name is in
    // order until every one of them is known, so the numbers are written once
    // the document's last body is lowered and not while one is.
    func numbered(
        _ rows: [Int],
        of origin: Int,
        answering answers: [Name: Shape]
    ) throws -> (table: [Linked], numbering: ShapeNumbering, answers: [Name: Shape]) {
        let stood = standing[origin] ?? Standing()
        let numbering = ShapeNumbering(
            types: Set(stood.types.map { row in shapes.labels[row] }),
            memberships: Set(stood.memberships.map { row in shapes.constraintLabels[row] })
        )

        // Which number each row of this link stands at, so the walk that
        // writes them reads a place rather than hashing a name at every
        // shape it meets.
        let place = (
            types: Self.placed(stood.types, among: numbering.types, spelling: shapes.labels),
            memberships: Self.placed(
                stood.memberships,
                among: numbering.memberships,
                spelling: shapes.constraintLabels
            )
        )

        let numbered = try rows.map { row -> Linked in
            let held = table[row]

            guard case .body = held.implementation else { return held }

            return try held.shaped { shape in
                try renumbered(shape, in: place, of: held.label)
            }
        }

        // What the link read off a body, in the numbers of the document that
        // body came out of. Read against the same numbering the bodies are, so
        // a call judged against one of these reads the shape its document
        // stands on.
        let read = try answers.reduce(into: [Name: Shape]()) { read, answer in
            read[answer.key] = try renumbered(answer.value, in: place, of: answer.key)
        }

        return (numbered, numbering, read)
    }

    // MARK: - Private
    // One shape written as the numbers its document gave the rows it stands
    // on. A row the document never numbered is the link having lowered
    // something it did not read, which is this pass's own mistake.
    private func renumbered(
        _ shape: Shape,
        in place: (types: [Int: Int], memberships: [Int: Int]),
        of label: Name
    ) throws -> Shape {
        try shape.renumbered(
            type: { number in
                guard let stands = place.types[number] else {
                    throw LinkError.unjudged(
                        "type \'\(shapes.labels[number])\', which its document never numbered",
                        at: Place.procedure(label.spelling, in: .assembled)
                    )
                }

                return stands
            },
            membership: { number in
                guard let stands = place.memberships[number] else {
                    throw LinkError.unjudged(
                        "membership \'\(shapes.constraintLabels[number])\',"
                            + " which its document never numbered",
                        at: Place.procedure(label.spelling, in: .assembled)
                    )
                }

                return stands
            }
        )
    }

    // Where each of a link's rows stands in the document's numbering, read
    // off the names once rather than at every shape the walk meets.
    private static func placed(
        _ rows: Set<Int>,
        among names: [Name],
        spelling: [Name]
    ) -> [Int: Int] {
        let numbers = names.enumerated().reduce(into: [Name: Int]()) { numbers, entry in
            numbers[entry.element] = entry.offset
        }

        return rows.reduce(into: [Int: Int]()) { places, row in
            places[row] = numbers[spelling[row]]
        }
    }
}
