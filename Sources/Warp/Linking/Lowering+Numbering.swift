//
//  Lowering+Numbering.swift
//  Warp
//
//  Created by JSilver on 9/8/26.
//

import Foundation

extension Lowering {
    // The lowered table with the shapes in it numbered by the document that
    // wrote them, beside the numberings that say what those numbers stand for.
    //
    // Lowering reads the link's table to judge, so the shape rows it writes
    // are that link's. This turns them into the document's own, which is what
    // leaves compiling: a body carries its document's numbers and nothing
    // about the world it was linked into.
    //
    // The order is the whole reason this stands apart from the lowering. A
    // document's numbering is its names in name order, and no name is in order
    // until every one of them is known, so the numbers are written once the
    // last body is lowered and not while one is.
    func numbered() throws -> (table: [Linked], numbering: [Int: ShapeNumbering]) {
        // Every document holding a body, and not only the ones that turned out
        // to stand on a declared name: a body standing on nothing declared has
        // an empty numbering, which is a different thing from a document this
        // link never compiled.
        let origins = table.reduce(into: Set<Int>()) { origins, row in
            guard case .body = row.implementation else { return }

            origins.insert(row.origin)
        }

        var numbering: [Int: ShapeNumbering] = [:]
        var places: [Int: (types: [Int: Int], memberships: [Int: Int])] = [:]

        for origin in origins {
            let stood = standing[origin] ?? Standing()
            let held = ShapeNumbering(
                types: Set(stood.types.map { row in shapes.labels[row] }),
                memberships: Set(stood.memberships.map { row in shapes.constraintLabels[row] })
            )

            numbering[origin] = held

            // Which number each row of this link stands at, so the walk that
            // writes them reads a place rather than hashing a name at every
            // shape it meets.
            places[origin] = (
                types: Self.placed(stood.types, among: held.types, spelling: shapes.labels),
                memberships: Self.placed(
                    stood.memberships,
                    among: held.memberships,
                    spelling: shapes.constraintLabels
                )
            )
        }

        let numbered = try table.map { row in
            try shaped(row) { origin, shape in
                guard let place = places[origin] else {
                    throw LinkError.unjudged(
                        "a shape in a document that numbered none",
                        at: Place.procedure(row.label.spelling, in: .assembled)
                    )
                }

                return try shape.renumbered(
                    type: { number in
                        guard let stands = place.types[number] else {
                            throw LinkError.unjudged(
                                "type \'\(shapes.labels[number])\', which its document never numbered",
                                at: Place.procedure(row.label.spelling, in: .assembled)
                            )
                        }

                        return stands
                    },
                    membership: { number in
                        guard let stands = place.memberships[number] else {
                            throw LinkError.unjudged(
                                "membership \'\(shapes.constraintLabels[number])\',"
                                    + " which its document never numbered",
                                at: Place.procedure(row.label.spelling, in: .assembled)
                            )
                        }

                        return stands
                    }
                )
            }
        }

        return (numbered, numbering)
    }

    // MARK: - Private
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

    // One row with every shape its body stands on answered again. A native
    // holds no body and stands on no shape a document numbered: its slots are
    // its signature lowered, which is the link's reading of it and not
    // something the row carries out of one.
    private func shaped(
        _ row: Linked,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Linked {
        guard case let .body(body, frame) = row.implementation else { return row }

        return Linked(
            row,
            implementation: .body(try shaped(body, of: row.origin, answer), frame),
            sends: row.sends
        )
    }

    private func shaped(
        _ body: Body,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                try shaped(instruction, of: origin, answer)
            },
            result: try body.result.map { result in try shaped(result, of: origin, answer) }
        )
    }

    private func shaped(
        _ instruction: Instruction,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Instruction {
        Instruction(
            binding: try shaped(instruction.binding, of: origin, answer),
            code: try shaped(instruction.code, of: origin, answer),
            label: instruction.label
        )
    }

    private func shaped(
        _ binding: Instruction.Binding?,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Instruction.Binding? {
        switch binding {
        case let .bind(slot, settling)?:
            return .bind(slot, settling: try settling.map { shape in try answer(origin, shape) })

        case let .declare(slot, settling)?:
            return .declare(slot, settling: try settling.map { shape in try answer(origin, shape) })

        case let .assign(address, settling)?:
            return .assign(address, settling: try settling.map { shape in try answer(origin, shape) })

        case nil:
            return nil
        }
    }

    private func shaped(
        _ operation: Operation,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Operation {
        switch operation {
        case .literal, .local:
            return operation

        case let .array(elements):
            return .array(try elements.map { element in try shaped(element, of: origin, answer) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try shaped(field, of: origin, answer) }
                )
            )

        // A closure is a body of its own, written in the same document.
        case let .closure(linked, captures):
            return .closure(try shaped(linked, answer), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try shaped(callee, of: origin, answer),
                arguments: try arguments.map { name, argument in
                    (name, try shaped(argument, of: origin, answer))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(
                try shaped(value, of: origin, answer),
                as: try answer(origin, shape),
                optional: optional
            )

        case let .block(body):
            return .block(try shaped(body, of: origin, answer))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try shaped(condition, of: origin, answer),
                then: try then.map { instruction in try shaped(instruction, of: origin, answer) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try shaped(instruction, of: origin, answer) }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try shaped(condition, of: origin, answer),
                body: try shaped(body, of: origin, answer),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try shaped(body, of: origin, answer),
                rescue: try shaped(rescue, of: origin, answer),
                failure: failure
            )

        case let .call(call):
            return .call(try shaped(call, of: origin, answer))

        // The calls a dispatch picks from are the link's to fill, so there is
        // nothing here for a document to number.
        case let .dispatch(dispatch):
            return .dispatch(
                DispatchOperation(
                    contract: dispatch.contract,
                    word: dispatch.word,
                    receiver: try shaped(dispatch.receiver, of: origin, answer),
                    arguments: try dispatch.arguments.mapValues { argument in
                        try shaped(argument, of: origin, answer)
                    },
                    calls: dispatch.calls
                )
            )

        case let .leave(reach, target, value):
            return .leave(
                reach,
                target: target,
                try value.map { value in try shaped(value, of: origin, answer) }
            )
        }
    }

    private func shaped(
        _ call: CallOperation,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> CallOperation {
        CallOperation(
            procedure: call.procedure,
            receiver: try call.receiver.map { receiver in try shaped(receiver, of: origin, answer) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try shaped(operation, of: origin, answer) }
            },
            handed: call.handed
        )
    }

    private func shaped(
        _ argument: Argument,
        of origin: Int,
        _ answer: (Int, Shape) throws -> Shape
    ) rethrows -> Argument {
        switch argument {
        case let .value(operation):
            return .value(try shaped(operation, of: origin, answer))

        case .reference:
            return argument
        }
    }
}
