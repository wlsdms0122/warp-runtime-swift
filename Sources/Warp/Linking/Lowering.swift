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
    let rows: [String: Int]
    let words: [String: Int]

    // Each document's variables by name, in the order a run makes their boxes.
    let variables: [Int: [String: Int]]

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [String: Int],
        words: [String: Int],
        variables: [Int: [String: Int]]
    ) {
        self.table = table
        self.rows = rows
        self.words = words
        self.variables = variables
    }

    // MARK: - Public
    // Lowers a declaration's body into its row.
    mutating func settle(
        _ row: Int,
        body block: Block,
        at place: Place
    ) throws {
        let declared = table[row]
        let frame = Slots(origin: declared.origin, variables: variables[declared.origin] ?? [:])
        var scope = Names()

        for (name, _) in declared.parameters {
            scope.slots[name] = frame.allocateParameter(name)
        }

        let body = try lower(block, in: scope, on: frame, label: declared.label, at: place)

        table[row] = Linked(
            label: declared.label,
            origin: declared.origin,
            signature: declared.signature,
            purity: declared.purity,
            isolation: declared.isolation,
            implementation: .body(body, frame.layout)
        )
    }

    // Lowers one expression read against a frame of constants, as a constant's
    // own expression is, and as a body's constant path is when it folds. The
    // frame starts as `names` in slot order and grows with what the
    // expression declares; the layout says how large it is.
    func lower(
        _ expression: Expression,
        reading names: [String],
        origin: Int,
        label: String,
        at place: Place
    ) throws -> (Code, Layout) {
        let frame = Slots(origin: origin, variables: [:])
        var scope = Names()

        for name in names {
            scope.slots[name] = frame.allocate(name)
        }

        let code = try lower(expression, in: scope, on: frame, label: label, at: place)

        return (code, frame.layout)
    }

    // MARK: - Private
    // The names visible at one point of a body, by slot. A value, so a block
    // takes a copy and what it introduces dies with it.
    private struct Names {
        var slots: [String: Int] = [:]
    }

    // The slots of one body being lowered. A closure's slots know the slots
    // and names of the body it was written in, and take a cell from there
    // the first time the closure reads a name it did not declare.
    private final class Slots {
        let origin: Int
        let variables: [String: Int]
        let outer: (slots: Slots, names: Names)?

        private(set) var names: [String] = []
        private(set) var parameters: [Int] = []
        private(set) var reads: [(variable: Int, slot: Int)] = []
        private(set) var captures: [(Int, Int)] = []

        private var variableSlots: [String: Int] = [:]
        private var capturedSlots: [String: Int] = [:]

        init(origin: Int, variables: [String: Int], outer: (slots: Slots, names: Names)? = nil) {
            self.origin = origin
            self.variables = variables
            self.outer = outer
        }

        var size: Int { names.count }

        func allocate(_ name: String) -> Int {
            names.append(name)

            return names.count - 1
        }

        func allocateParameter(_ name: String) -> Int {
            let slot = allocate(name)
            parameters.append(slot)

            return slot
        }

        // The slot a name reads from here, the way scope reads a name: what
        // this body declared, then what the body it was written in holds,
        // then the module's variables. A closure reaches a module variable
        // through the body it was written in, so the hold it takes is that
        // body's.
        func slot(of name: String, in names: Names) -> Int? {
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

        var layout: Layout {
            Layout(size: size, parameters: parameters, variables: reads, names: names)
        }
    }

    private func lower(
        _ block: Block,
        in scope: Names,
        on frame: Slots,
        label: String,
        at place: Place
    ) throws -> Body {
        var inner = scope
        let instructions = try lower(block.body, in: &inner, on: frame, label: label, at: place)
        let result = try block.result.map { result in
            try lower(result, in: inner, on: frame, label: label, at: place)
        }

        return Body(instructions: instructions, result: result)
    }

    // Statements in order: a statement's expression is lowered before the
    // name it binds exists, so a name reads what the statement before it
    // bound.
    private func lower(
        _ statements: [Statement],
        in scope: inout Names,
        on frame: Slots,
        label: String,
        at place: Place
    ) throws -> [Instruction] {
        var instructions: [Instruction] = []

        for (position, statement) in statements.enumerated() {
            let code = try lower(statement.expression, in: scope, on: frame, label: label, at: place)
            let binding: Instruction.Binding?

            switch statement.binding {
            case let .constant(name)?:
                let slot = frame.allocate(name)
                scope.slots[name] = slot
                binding = .bind(slot)

            case let .variable(name)?:
                let slot = frame.allocate(name)
                scope.slots[name] = slot
                binding = .declare(slot)

            case let .assignment(path)?:
                let (slot, steps) = try lower(path, in: scope, on: frame, at: place)
                binding = .assign(slot, steps)

            case nil:
                binding = nil
            }

            instructions.append(
                Instruction(
                    binding: binding,
                    code: code,
                    label: statement.name ?? "[\(position)]"
                )
            )
        }

        return instructions
    }

    private func lower(
        _ expression: Expression,
        in scope: Names,
        on frame: Slots,
        label: String,
        at place: Place
    ) throws -> Code {
        switch expression {
        case let .literal(value):
            return .literal(value)

        case let .reference(path):
            let (slot, steps) = try lower(path, in: scope, on: frame, at: place)

            return .local(slot, steps)

        case let .array(array):
            return .array(try array.map { element in
                try lower(element, in: scope, on: frame, label: label, at: place)
            })

        case let .record(record):
            return .record(try record.sorted { Name.precedes($0.key, $1.key) }.map { name, field in
                (name, try lower(field, in: scope, on: frame, label: label, at: place))
            })

        case let .closure(procedure):
            guard let block = procedure.block else {
                throw unjudged("a closure with no body", at: place)
            }

            let inner = Slots(origin: frame.origin, variables: frame.variables, outer: (frame, scope))
            var innerScope = Names()

            for (name, _) in procedure.signature.ordered {
                innerScope.slots[name] = inner.allocateParameter(name)
            }

            let body = try lower(block, in: innerScope, on: inner, label: label, at: place)
            return .closure(
                Linked(
                    label: label,
                    origin: frame.origin,
                    signature: procedure.signature,
                    purity: procedure.purity,
                    isolation: procedure.isolation,
                    implementation: .body(body, inner.layout)
                ),
                captures: inner.captures
            )

        case let .invoke(callee, arguments):
            return .invoke(
                try lower(callee, in: scope, on: frame, label: label, at: place),
                arguments: try arguments.sorted { $0.key < $1.key }.map { name, argument in
                    (name, try lower(argument, in: scope, on: frame, label: label, at: place))
                }
            )

        case let .cast(value, type, optional):
            return .cast(
                try lower(value, in: scope, on: frame, label: label, at: place),
                as: type,
                optional: optional
            )

        case let .block(block):
            return .block(try lower(block, in: scope, on: frame, label: label, at: place))

        case let .conditional(condition, then, otherwise):
            var thenScope = scope
            var elseScope = scope

            return .conditional(
                try lower(condition, in: scope, on: frame, label: label, at: place),
                then: try lower(then, in: &thenScope, on: frame, label: label, at: place),
                else: try otherwise.map { statements in
                    try lower(statements, in: &elseScope, on: frame, label: label, at: place)
                }
            )

        case let .loop(condition, body, round):
            var inner = scope
            let slot = frame.allocate(round)
            inner.slots[round] = slot

            let taking = try lower(condition, in: inner, on: frame, label: label, at: place)
            let start = frame.size
            let instructions = try lower(body.body, in: &inner, on: frame, label: label, at: place)
            let bound = start ..< frame.size
            let result = try body.result.map { result in
                try lower(result, in: inner, on: frame, label: label, at: place)
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
            let over = try lower(material, in: scope, on: frame, label: label, at: place)
            var inner = scope
            let slot = frame.allocate(element)
            inner.slots[element] = slot

            return .iteration(
                over: over,
                body: try lower(body, in: &inner, on: frame, label: label, at: place),
                element: slot
            )

        case let .attempt(block, rescue, failure):
            let attempted = try lower(block, in: scope, on: frame, label: label, at: place)
            var inner = scope
            let slot = frame.allocate(failure)
            inner.slots[failure] = slot

            return .attempt(
                attempted,
                rescue: try lower(rescue, in: inner, on: frame, label: label, at: place),
                failure: slot
            )

        case let .dispatch(dispatch):
            return .send(try lower(dispatch, in: scope, on: frame, label: label, at: place))

        case let .leave(leave):
            return .leave(
                leave.reach,
                target: leave.target,
                try leave.value.map { value in
                    try lower(value, in: scope, on: frame, label: label, at: place)
                }
            )
        }
    }

    private func lower(
        _ dispatch: Dispatch,
        in scope: Names,
        on frame: Slots,
        label: String,
        at place: Place
    ) throws -> Send {
        guard let row = rows[dispatch.selector] else {
            throw unjudged("a send to '\(dispatch.selector)', which has no row", at: place)
        }

        let callee = table[row]

        if let stray = dispatch.arguments.keys.first(where: { name in callee.signature.parameters[name] == nil }) {
            throw unjudged("an argument '\(stray)' that '\(dispatch.selector)' does not declare", at: place)
        }

        var receiver: Code?
        var arguments: [Code?] = []
        var handed: [Send.Handed] = []

        for (position, (name, parameter)) in callee.parameters.enumerated() {
            let written = dispatch.handed(name, to: callee.signature)

            if parameter.declared.isInout {
                guard case let .reference(path)? = written else {
                    throw unjudged("'\(name)' handed to '\(dispatch.selector)' in place without a variable", at: place)
                }

                let (slot, steps) = try lower(path, in: scope, on: frame, at: place)
                handed.append(Send.Handed(position: position, slot: slot, path: steps))
                arguments.append(nil)

                continue
            }

            if name == callee.signature.receiver, let sent = dispatch.receiver {
                guard dispatch.arguments[name] == nil else {
                    throw unjudged("'\(name)' sent to '\(dispatch.selector)' both in front and by name", at: place)
                }

                receiver = try lower(sent, in: scope, on: frame, label: label, at: place)
                arguments.append(nil)

                continue
            }

            arguments.append(try written.map { argument in
                try lower(argument, in: scope, on: frame, label: label, at: place)
            })
        }

        return Send(procedure: row, receiver: receiver, arguments: arguments, handed: handed)
    }

    private func lower(
        _ path: [PathSegment],
        in scope: Names,
        on frame: Slots,
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

        guard let slot = frame.slot(of: head, in: scope) else {
            throw unjudged("a name '\(head)' in '\(path.rendered)' that nothing declares", at: place)
        }

        let steps = try path.dropFirst().map { segment -> Step in
            switch segment {
            case let .key(name, optional):
                return .key(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .indexRef(inner, optional):
                let (slot, steps) = try lower(inner, in: scope, on: frame, at: place)

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
