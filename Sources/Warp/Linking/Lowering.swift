//
//  Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Writes what the link proved into a body. Every name becomes the slot the
// frame holds it in, every selector the row it names, every path word the
// row it sends, every argument the position of its parameter. Nothing is
// judged here: a name this walk cannot place is a body the link let through
// unjudged, and is refused as the link's own mistake.
//
// The table has one row per declaration. A closure literal is a body of its
// own with its own frame, lowered into a row the closure code holds itself.
struct Lowering {
    // MARK: - Property
    private(set) var table: [Linked]

    // Rows by declared spelling, and by the bare spelling a path word writes.
    let rows: [Name: Int]
    let words: [Name: Int]

    // Each document's variables by name, in the order a run makes their boxes.
    let variables: [Int: [Name: Int]]

    // The declared types as the run reads them, for a cast's shape and a
    // closure's row.
    let shapes: ShapeTable

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        variables: [Int: [Name: Int]],
        shapes: ShapeTable
    ) {
        self.table = table
        self.rows = rows
        self.words = words
        self.variables = variables
        self.shapes = shapes
    }

    // MARK: - Public
    // Lowers a declaration's body into its row.
    mutating func settle(
        _ row: Int,
        body block: Block,
        at place: Place
    ) throws {
        let declared = table[row]
        let slots = Slots(origin: declared.origin, variables: variables[declared.origin] ?? [:])
        var scope = Names()

        for slot in declared.slots {
            scope.slots[slot.name] = slots.allocateParameter(slot.name)
        }

        let body = try lower(block, in: scope, on: slots, label: declared.label, at: place)

        table[row] = Linked(
            label: declared.label,
            origin: declared.origin,
            signature: declared.signature,
            purity: declared.purity,
            isolation: declared.isolation,
            implementation: .body(body, slots.frame),
            in: shapes
        )
    }

    // Lowers one expression read against a frame of constants, as a constant's
    // own expression is, and as a body's constant path is when it folds. The
    // frame starts as `names` in slot order and grows with what the
    // expression declares; the frame says how large it is.
    func lower(
        _ expression: Expression,
        reading names: [Name],
        origin: Int,
        label: Name,
        at place: Place
    ) throws -> (Operation, Frame) {
        let slots = Slots(origin: origin, variables: [:])
        var scope = Names()

        for name in names {
            scope.slots[name] = slots.allocate(name)
        }

        let code = try lower(expression, in: scope, on: slots, label: label, at: place)

        return (code, slots.frame)
    }

    // MARK: - Private
    // The names visible at one point of a body, by slot. A value, so a block
    // takes a copy and what it introduces dies with it.
    private struct Names {
        var slots: [Name: Int] = [:]
    }

    // The slots of one body being lowered. A closure's slots know the slots
    // and names of the body it was written in, and take a cell from there
    // the first time the closure reads a name it did not declare.
    private final class Slots {
        let origin: Int
        let variables: [Name: Int]
        let outer: (slots: Slots, names: Names)?

        private(set) var names: [Name] = []
        private(set) var parameters: [Int] = []
        private(set) var reads: [(variable: Int, slot: Int)] = []
        private(set) var captures: [(Int, Int)] = []

        private var variableSlots: [Name: Int] = [:]
        private var capturedSlots: [Name: Int] = [:]

        init(origin: Int, variables: [Name: Int], outer: (slots: Slots, names: Names)? = nil) {
            self.origin = origin
            self.variables = variables
            self.outer = outer
        }

        var size: Int { names.count }

        func allocate(_ name: Name) -> Int {
            names.append(name)

            return names.count - 1
        }

        func allocateParameter(_ name: Name) -> Int {
            let slot = allocate(name)
            parameters.append(slot)

            return slot
        }

        // The slot a name reads from here, the way scope reads a name: what
        // this body declared, then what the body it was written in holds,
        // then the module's variables. A closure reaches a module variable
        // through the body it was written in, so the hold it takes is that
        // body's.
        func slot(of name: Name, in names: Names) -> Int? {
            if let slot = names.slots[name] { return slot }

            if let slot = capturedSlots[name] { return slot }

            if let outer, let taken = outer.slots.slot(of: name, in: outer.names) {
                let slot = allocate(name)
                capturedSlots[name] = slot
                captures.append((taken, slot))

                return slot
            }

            if let slot = variableSlots[name] { return slot }

            guard let variable = variables[name] else { return nil }

            let slot = allocate(name)
            variableSlots[name] = slot
            reads.append((variable: variable, slot: slot))

            return slot
        }

        var frame: Frame {
            Frame(size: size, parameters: parameters, variables: reads, names: names)
        }
    }

    private func lower(
        _ block: Block,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Body {
        var inner = scope
        let instructions = try lower(block.body, in: &inner, on: slots, label: label, at: place)
        let result = try block.result.map { result in
            try lower(result, in: inner, on: slots, label: label, at: place)
        }

        return Body(instructions: instructions, result: result)
    }

    // Statements in order: a statement's expression is lowered before the
    // name it binds exists, so a name reads what the statement before it
    // bound.
    private func lower(
        _ statements: [Statement],
        in scope: inout Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> [Instruction] {
        var instructions: [Instruction] = []

        for (position, statement) in statements.enumerated() {
            let code = try lower(statement.expression, in: scope, on: slots, label: label, at: place)
            let binding: Instruction.Binding?

            switch statement.binding {
            case let .constant(name, declared)?:
                let slot = slots.allocate(name)
                scope.slots[name] = slot
                binding = .bind(slot, settling: declared?.lowered(in: shapes))

            case let .variable(name, declared)?:
                let slot = slots.allocate(name)
                scope.slots[name] = slot
                binding = .declare(slot, settling: declared?.lowered(in: shapes))

            case let .assignment(path)?:
                let (slot, steps) = try lower(path, in: scope, on: slots, at: place)
                binding = .assign(slot, steps)

            case nil:
                binding = nil
            }

            instructions.append(
                Instruction(
                    binding: binding,
                    code: code,
                    label: statement.name?.spelling ?? "[\(position)]"
                )
            )
        }

        return instructions
    }

    private func lower(
        _ expression: Expression,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        switch expression {
        case let .literal(value):
            return .literal(value)

        case let .reference(path):
            let (slot, steps) = try lower(path, in: scope, on: slots, at: place)

            return .local(slot, steps)

        case let .array(array):
            return .array(try array.map { element in
                try lower(element, in: scope, on: slots, label: label, at: place)
            })

        case let .record(record):
            let ordered = record.sorted { $0.key < $1.key }

            return .record(
                RecordOperation(
                    layout: Layout(name: nil, ordered: ordered.map(\.key)),
                    fields: try ordered.map { _, field in
                        try lower(field, in: scope, on: slots, label: label, at: place)
                    }
                )
            )

        case let .closure(procedure):
            guard let block = procedure.block else {
                throw unjudged("a closure with no body", at: place)
            }

            let inner = Slots(origin: slots.origin, variables: slots.variables, outer: (slots, scope))
            var innerScope = Names()

            for (name, _) in procedure.signature.ordered {
                innerScope.slots[name] = inner.allocateParameter(name)
            }

            let body = try lower(block, in: innerScope, on: inner, label: label, at: place)
            return .closure(
                Linked(
                    label: label,
                    origin: slots.origin,
                    signature: procedure.signature,
                    purity: procedure.purity,
                    isolation: procedure.isolation,
                    implementation: .body(body, inner.frame),
                    in: shapes
                ),
                captures: inner.captures
            )

        case let .apply(callee, arguments):
            return .apply(
                try lower(callee, in: scope, on: slots, label: label, at: place),
                arguments: try arguments.sorted { $0.key < $1.key }.map { name, argument in
                    (name, try lower(argument, in: scope, on: slots, label: label, at: place))
                }
            )

        case let .cast(value, type, optional):
            return .cast(
                try lower(value, in: scope, on: slots, label: label, at: place),
                as: type.lowered(in: shapes),
                optional: optional
            )

        case let .block(block):
            return .block(try lower(block, in: scope, on: slots, label: label, at: place))

        case let .conditional(condition, then, otherwise):
            var thenScope = scope
            var elseScope = scope

            return .conditional(
                try lower(condition, in: scope, on: slots, label: label, at: place),
                then: try lower(then, in: &thenScope, on: slots, label: label, at: place),
                else: try otherwise.map { statements in
                    try lower(statements, in: &elseScope, on: slots, label: label, at: place)
                }
            )

        case let .loop(condition, body, round):
            var inner = scope
            let slot = slots.allocate(round)
            inner.slots[round] = slot

            let taking = try lower(condition, in: inner, on: slots, label: label, at: place)
            let start = slots.size
            let instructions = try lower(body.body, in: &inner, on: slots, label: label, at: place)
            let bound = start ..< slots.size
            let result = try body.result.map { result in
                try lower(result, in: inner, on: slots, label: label, at: place)
            }

            // A round that ends early has bound part of what a full round
            // binds. The result reads the last finished round, so where it
            // reads the body's slots, the run puts them back after a round
            // cut short. Whether a round can end early is the run's fact.
            let keeps = result.map { result in result.reads(bound) ? bound : nil } ?? nil

            return .loop(
                while: taking,
                body: Body(instructions: instructions, result: result),
                round: slot,
                keeps: keeps
            )

        case let .iteration(material, body, element):
            let over = try lower(material, in: scope, on: slots, label: label, at: place)
            var inner = scope
            let slot = slots.allocate(element)
            inner.slots[element] = slot

            return .iteration(
                over: over,
                body: try lower(body, in: &inner, on: slots, label: label, at: place),
                element: slot
            )

        case let .attempt(block, rescue, failure):
            let attempted = try lower(block, in: scope, on: slots, label: label, at: place)
            var inner = scope
            let slot = slots.allocate(failure)
            inner.slots[failure] = slot

            return .attempt(
                attempted,
                rescue: try lower(rescue, in: inner, on: slots, label: label, at: place),
                failure: slot
            )

        case let .call(call):
            return .call(try lower(call, in: scope, on: slots, label: label, at: place))

        case let .leave(leave):
            return .leave(
                leave.reach,
                target: leave.target,
                try leave.value.map { value in
                    try lower(value, in: scope, on: slots, label: label, at: place)
                }
            )
        }
    }

    private func lower(
        _ call: Call,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> CallOperation {
        guard let row = rows[call.selector] else {
            throw unjudged("a call to '\(call.selector)', which has no row", at: place)
        }

        let callee = table[row]

        if let stray = call.arguments.keys.first(where: { name in callee.signature.parameters[name] == nil }) {
            throw unjudged("an argument '\(stray)' that '\(call.selector)' does not declare", at: place)
        }

        var receiver: Operation?
        var arguments: [Operation?] = []
        var handed: [CallOperation.Handed] = []

        for (position, slot) in callee.slots.enumerated() {
            let name = slot.name
            let written = call.handed(name, to: callee.signature)

            if case .inout = slot.shape {
                guard case let .reference(path)? = written else {
                    throw unjudged("'\(name)' handed to '\(call.selector)' in place without a variable", at: place)
                }

                let (slot, steps) = try lower(path, in: scope, on: slots, at: place)
                handed.append(CallOperation.Handed(position: position, slot: slot, path: steps))
                arguments.append(nil)

                continue
            }

            if name == callee.signature.receiver, let sent = call.receiver {
                guard call.arguments[name] == nil else {
                    throw unjudged("'\(name)' sent to '\(call.selector)' both in front and by name", at: place)
                }

                receiver = try lower(sent, in: scope, on: slots, label: label, at: place)
                arguments.append(nil)

                continue
            }

            // A literal argument is a value the link knows, so the image
            // holds it as the slot takes it rather than as it was written.
            arguments.append(try written.map { argument in
                let code = try lower(argument, in: scope, on: slots, label: label, at: place)

                guard case let .literal(value) = code else { return code }

                return .literal(try slot.taking(value, in: shapes))
            })
        }

        return CallOperation(procedure: row, receiver: receiver, arguments: arguments, handed: handed)
    }

    private func lower(
        _ path: [PathSegment],
        in scope: Names,
        on slots: Slots,
        at place: Place
    ) throws -> (Int, [Step]) {
        // A mark on the head expects a name to be missing, which is not
        // absence but a reading gone wrong.
        if let refusal = path.markedHead {
            throw LinkError(refusal, at: place)
        }

        guard case let .key(head, _)? = path.first else {
            throw unjudged("a path '\(path.rendered)' with no name at its head", at: place)
        }

        guard let slot = slots.slot(of: head, in: scope) else {
            throw unjudged("a name '\(head)' in '\(path.rendered)' that nothing declares", at: place)
        }

        let steps = try path.dropFirst().map { segment -> Step in
            switch segment {
            case let .key(name, optional):
                return .key(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .indexRef(inner, optional):
                let (slot, steps) = try lower(inner, in: scope, on: slots, at: place)

                return .at(slot, steps, optional: optional)

            case let .word(name, optional):
                guard let row = words[name] else {
                    throw unjudged("a word '\(name)' in '\(path.rendered)' that no path may reach", at: place)
                }

                return .word(row, name, optional: optional)
            }
        }

        return (slot, steps)
    }

    // What the link should have refused before lowering and did not. Not a
    // sentence for an author to act on: it names the judgment that was
    // skipped, for whoever reads the link.
    private func unjudged(_ what: String, at place: Place) -> LinkError {
        LinkError("the link lowered \(what) without judging it", at: place)
    }
}
