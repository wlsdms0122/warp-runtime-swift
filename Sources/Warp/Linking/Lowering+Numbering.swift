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
        var types: [Int: Set<Int>] = [:]
        var memberships: [Int: Set<Int>] = [:]

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
            let declared = held.declared ?? (types: [], memberships: [])

            places[origin] = (
                types: Self.placed(stood.types, among: declared.types, spelling: shapes.labels),
                memberships: Self.placed(
                    stood.memberships,
                    among: declared.memberships,
                    spelling: shapes.constraintLabels
                )
            )
        }

        let numbered = try table.map { row -> Linked in
            guard case .body = row.implementation else { return row }
            guard let place = places[row.origin] else {
                throw LinkError.unjudged(
                    "a shape in a document that numbered none",
                    at: Place.procedure(row.label.spelling, in: .assembled)
                )
            }

            return try shaped(row) { shape in
                try shape.renumbered(
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

    // One row with every shape its body stands on answered again. The body
    // only: what a row's slots and answer lower to is its signature read
    // against a table, which is the link's reading and not a number the
    // document gave. That holds for a native, which has no body at all, and
    // for a written one.
    private func shaped(
        _ row: Linked,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Linked {
        guard case let .body(body, frame) = row.implementation else { return row }

        return Linked(
            row,
            implementation: .body(try shaped(body, answer), frame),
            sends: row.sends
        )
    }

    private func shaped(
        _ body: Body,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Body {
        Body(
            instructions: try body.instructions.map { instruction in
                try shaped(instruction, answer)
            },
            result: try body.result.map { result in try shaped(result, answer) }
        )
    }

    private func shaped(
        _ instruction: Instruction,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Instruction {
        Instruction(
            binding: try shaped(instruction.binding, answer),
            code: try shaped(instruction.code, answer),
            label: instruction.label
        )
    }

    private func shaped(
        _ binding: Instruction.Binding?,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Instruction.Binding? {
        switch binding {
        case let .bind(slot, settling)?:
            return .bind(slot, settling: try settling.map { shape in try answer(shape) })

        case let .declare(slot, settling)?:
            return .declare(slot, settling: try settling.map { shape in try answer(shape) })

        case let .assign(address, settling)?:
            return .assign(address, settling: try settling.map { shape in try answer(shape) })

        case nil:
            return nil
        }
    }

    private func shaped(
        _ operation: Operation,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Operation {
        switch operation {
        case .literal, .local:
            return operation

        case let .array(elements):
            return .array(try elements.map { element in try shaped(element, answer) })

        case let .record(held):
            return .record(
                RecordOperation(
                    layout: held.layout,
                    fields: try held.fields.map { field in try shaped(field, answer) }
                )
            )

        // A closure is a body of its own, written in the same document.
        case let .closure(linked, captures):
            return .closure(try shaped(linked, answer), captures: captures)

        case let .apply(callee, arguments):
            return .apply(
                try shaped(callee, answer),
                arguments: try arguments.map { name, argument in
                    (name, try shaped(argument, answer))
                }
            )

        case let .cast(value, shape, optional):
            return .cast(
                try shaped(value, answer),
                as: try answer(shape),
                optional: optional
            )

        case let .block(body):
            return .block(try shaped(body, answer))

        case let .conditional(condition, then, otherwise):
            return .conditional(
                try shaped(condition, answer),
                then: try then.map { instruction in try shaped(instruction, answer) },
                else: try otherwise.map { instructions in
                    try instructions.map { instruction in try shaped(instruction, answer) }
                }
            )

        case let .loop(condition, body, round, keeps):
            return .loop(
                while: try shaped(condition, answer),
                body: try shaped(body, answer),
                round: round,
                keeps: keeps
            )

        case let .attempt(body, rescue, failure):
            return .attempt(
                try shaped(body, answer),
                rescue: try shaped(rescue, answer),
                failure: failure
            )

        case let .call(call):
            return .call(try shaped(call, answer))

        // The calls a dispatch picks from are the link's to fill, so there is
        // nothing here for a document to number.
        case let .dispatch(dispatch):
            return .dispatch(
                DispatchOperation(
                    contract: dispatch.contract,
                    word: dispatch.word,
                    receiver: try shaped(dispatch.receiver, answer),
                    arguments: try dispatch.arguments.mapValues { argument in
                        try shaped(argument, answer)
                    },
                    calls: dispatch.calls
                )
            )

        case let .leave(reach, target, value):
            return .leave(
                reach,
                target: target,
                try value.map { value in try shaped(value, answer) }
            )
        }
    }

    private func shaped(
        _ call: CallOperation,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> CallOperation {
        CallOperation(
            procedure: call.procedure,
            receiver: try call.receiver.map { receiver in try shaped(receiver, answer) },
            arguments: try call.arguments.map { argument in
                try argument.map { operation in try shaped(operation, answer) }
            },
            handed: call.handed
        )
    }

    private func shaped(
        _ argument: Argument,
        _ answer: (Shape) throws -> Shape
    ) rethrows -> Argument {
        switch argument {
        case let .value(operation):
            return .value(try shaped(operation, answer))

        case .reference:
            return argument
        }
    }
}
