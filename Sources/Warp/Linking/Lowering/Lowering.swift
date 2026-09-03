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
// The table starts with one row per declaration and grows by one per closure
// literal, since a closure body is a body of its own with its own frame.
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
        let frame = Frame(origin: declared.origin, variables: variables[declared.origin] ?? [:])
        var scope = Scope()

        for (name, _) in declared.parameters {
            scope.slots[name] = frame.allocate(name)
        }

        let body = try lower(block, in: scope, on: frame, label: declared.label, at: place)

        table[row] = Linked(
            label: declared.label,
            origin: declared.origin,
            signature: declared.signature,
            purity: declared.purity,
            isolation: declared.isolation,
            implementation: .body(body, frame.layout(parameters: declared.parameters.map(\.name)))
        )
    }

    // Lowers one expression read against a frame of constants, as a constant's
    // own expression is, and as a body's constant path is when it folds. The
    // frame is `names` in slot order.
    mutating func lower(
        _ expression: Expression,
        reading names: [String],
        origin: Int,
        label: String,
        at place: Place
    ) throws -> Code {
        let frame = Frame(origin: origin, variables: [:])
        var scope = Scope()

        for name in names {
            scope.slots[name] = frame.allocate(name)
        }

        return try lower(expression, in: scope, on: frame, label: label, at: place)
    }

    // MARK: - Private
    // The names visible at one point of a body, by slot. A value, so a block
    // takes a copy and what it introduces dies with it.
    private struct Scope {
        var slots: [String: Int] = [:]
    }

    // The frame of one body being lowered. A closure's frame knows the frame
    // and scope it was written in, and takes a cell from there the first
    // time its body reads a name it did not declare.
    private final class Frame {
        let origin: Int
        let variables: [String: Int]
        let outer: (frame: Frame, scope: Scope)?

        private(set) var names: [String] = []
        private(set) var reads: [(variable: Int, slot: Int)] = []
        private(set) var captures: [(Int, Int)] = []

        private var variableSlots: [String: Int] = [:]
        private var capturedSlots: [String: Int] = [:]

        init(origin: Int, variables: [String: Int], outer: (frame: Frame, scope: Scope)? = nil) {
            self.origin = origin
            self.variables = variables
            self.outer = outer
        }

        var size: Int { names.count }

        func allocate(_ name: String) -> Int {
            names.append(name)

            return names.count - 1
        }

        // The slot a name reads from here: declared in this body, a module
        // variable, or a name the body it was written in holds.
        func slot(of name: String, in scope: Scope) -> Int? {
            if let slot = scope.slots[name] { return slot }

            if let slot = variableSlots[name] { return slot }

            if let variable = variables[name] {
                let slot = allocate(name)
                variableSlots[name] = slot
                reads.append((variable: variable, slot: slot))

                return slot
            }

            if let slot = capturedSlots[name] { return slot }

            guard let outer, let taken = outer.frame.slot(of: name, in: outer.scope) else { return nil }

            let slot = allocate(name)
            capturedSlots[name] = slot
            captures.append((taken, slot))

            return slot
        }

        func layout(parameters: [String]) -> Layout {
            Layout(
                size: size,
                parameters: parameters.map { name in names.firstIndex(of: name) ?? 0 },
                variables: reads,
                names: names
            )
        }
    }

    private mutating func lower(
        _ block: Block,
        in scope: Scope,
        on frame: Frame,
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
    private mutating func lower(
        _ statements: [Statement],
        in scope: inout Scope,
        on frame: Frame,
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

    private mutating func lower(
        _ expression: Expression,
        in scope: Scope,
        on frame: Frame,
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
            return .record(try record.sorted { $0.key < $1.key }.map { name, field in
                (name, try lower(field, in: scope, on: frame, label: label, at: place))
            })

        case let .closure(procedure):
            guard let block = procedure.block else {
                throw LinkError("a closure is a body, and this one is native", at: place)
            }

            let inner = Frame(origin: frame.origin, variables: frame.variables, outer: (frame, scope))
            var innerScope = Scope()
            let parameters = procedure.signature.parameters.keys.sorted()

            for name in parameters {
                innerScope.slots[name] = inner.allocate(name)
            }

            let body = try lower(block, in: innerScope, on: inner, label: label, at: place)
            let row = Linked(
                label: label,
                origin: frame.origin,
                signature: procedure.signature,
                purity: procedure.purity,
                isolation: procedure.isolation,
                implementation: .body(body, inner.layout(parameters: parameters))
            )

            table.append(row)

            return .closure(row, captures: inner.captures)

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
            // binds. The result reads the last finished round, so the range
            // it reads is put back where a round can end early.
            let keeps = result.map { result in
                result.reads(bound) && body.body.leavesARound ? bound : nil
            } ?? nil

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

    private mutating func lower(
        _ dispatch: Dispatch,
        in scope: Scope,
        on frame: Frame,
        label: String,
        at place: Place
    ) throws -> Send {
        guard let row = rows[dispatch.selector] else {
            throw LinkError("'\(dispatch.selector)' names no declaration the link knows", at: place)
        }

        let callee = table[row]

        if let stray = dispatch.arguments.keys.first(where: { name in callee.signature.parameters[name] == nil }) {
            throw LinkError("'\(dispatch.selector)' declares no parameter '\(stray)'", at: place)
        }

        var receiver: Code?
        var arguments: [Code?] = []
        var handed: [Send.Handed] = []

        for (position, (name, parameter)) in callee.parameters.enumerated() {
            let written = dispatch.handed(name, to: callee.signature)

            if parameter.declared.isInout {
                guard case let .reference(path)? = written else {
                    throw LinkError(
                        "'\(dispatch.selector)' takes '\(name)' in place, and was not handed a variable",
                        at: place
                    )
                }

                let (slot, steps) = try lower(path, in: scope, on: frame, at: place)
                handed.append(Send.Handed(position: position, slot: slot, path: steps))
                arguments.append(nil)

                continue
            }

            if name == callee.signature.receiver, let sent = dispatch.receiver {
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

    private mutating func lower(
        _ path: [PathSegment],
        in scope: Scope,
        on frame: Frame,
        at place: Place
    ) throws -> (Int, [Step]) {
        // A mark on the head expects a name to be missing, which is not
        // absence but a reading gone wrong.
        if let refusal = path.markedHead {
            throw LinkError(refusal, at: place)
        }

        guard case let .key(head, _)? = path.first else {
            throw LinkError("'\(path.rendered)' starts with no name", at: place)
        }

        guard let slot = frame.slot(of: head, in: scope) else {
            throw LinkError("'\(path.rendered)' reads '\(head)', which nothing here declares", at: place)
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
                    throw LinkError("'\(path.rendered)' sends '\(name)', which no path may reach", at: place)
                }

                return .word(row, name, optional: optional)
            }
        }

        return (slot, steps)
    }
}

extension Code {
    // Whether this reads any slot in the range, through a path's index
    // references as well. A closure's captures are reads of its own.
    func reads(_ slots: Range<Int>) -> Bool {
        switch self {
        case .literal:
            return false

        case let .local(slot, steps):
            return slots.contains(slot) || steps.contains { step in step.reads(slots) }

        case let .array(elements):
            return elements.contains { element in element.reads(slots) }

        case let .record(fields):
            return fields.contains { _, field in field.reads(slots) }

        case let .closure(_, captures):
            return captures.contains { outer, _ in slots.contains(outer) }

        case let .invoke(callee, arguments):
            return callee.reads(slots) || arguments.contains { _, argument in argument.reads(slots) }

        case let .cast(value, _, _):
            return value.reads(slots)

        case let .block(body):
            return body.reads(slots)

        case let .conditional(condition, then, otherwise):
            return condition.reads(slots)
                || then.contains { instruction in instruction.reads(slots) }
                || otherwise?.contains { instruction in instruction.reads(slots) } == true

        case let .loop(condition, body, _, _):
            return condition.reads(slots) || body.reads(slots)

        case let .iteration(material, body, _):
            return material.reads(slots) || body.contains { instruction in instruction.reads(slots) }

        case let .attempt(body, rescue, _):
            return body.reads(slots) || rescue.reads(slots)

        case let .send(send):
            return send.receiver?.reads(slots) == true
                || send.arguments.contains { argument in argument?.reads(slots) == true }
                || send.handed.contains { handed in
                    slots.contains(handed.slot) || handed.path.contains { step in step.reads(slots) }
                }

        case let .leave(_, _, value):
            return value?.reads(slots) == true
        }
    }
}

extension Step {
    func reads(_ slots: Range<Int>) -> Bool {
        guard case let .at(slot, steps, _) = self else { return false }

        return slots.contains(slot) || steps.contains { step in step.reads(slots) }
    }
}

extension Body {
    func reads(_ slots: Range<Int>) -> Bool {
        instructions.contains { instruction in instruction.reads(slots) }
            || result?.reads(slots) == true
    }
}

extension Instruction {
    func reads(_ slots: Range<Int>) -> Bool {
        if case let .assign(slot, steps)? = binding,
           slots.contains(slot) || steps.contains(where: { step in step.reads(slots) }) {
            return true
        }

        return code.reads(slots)
    }
}

extension [Statement] {
    // Whether a round of this body can end before its last statement: a
    // `break` or `continue` anywhere in it, outside any closure, since a
    // closure's leaving is refused at the link.
    var leavesARound: Bool {
        contains { statement in statement.expression.leavesARound }
    }
}

extension Expression {
    var leavesARound: Bool {
        switch self {
        case let .leave(leave):
            return leave.reach != .procedure

        case let .block(block):
            return block.body.leavesARound

        case let .conditional(_, then, otherwise):
            return then.leavesARound || otherwise?.leavesARound == true

        case let .loop(_, body, _):
            return body.body.leavesARound

        case let .iteration(_, body, _):
            return body.leavesARound

        case let .attempt(block, rescue, _):
            return block.body.leavesARound || rescue.body.leavesARound

        case .literal, .reference, .array, .record, .closure, .invoke, .cast, .dispatch:
            return false
        }
    }
}
