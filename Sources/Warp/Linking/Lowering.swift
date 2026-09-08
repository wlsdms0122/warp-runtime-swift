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

    // Every contract's words, under the spelling a call writes to reach one.
    // A selector in here names no row: it names the table of rows the run
    // picks from.
    let contractWords: [Name: ContractWord]

    // The declared types as the run reads them, for a cast's shape and a
    // closure's row.
    let shapes: ShapeTable

    // MARK: - Initializer
    init(
        table: [Linked],
        rows: [Name: Int],
        words: [Name: Int],
        variables: [Int: [Name: Int]],
        contractWords: [Name: ContractWord] = [:],
        shapes: ShapeTable
    ) {
        self.table = table
        self.rows = rows
        self.words = words
        self.variables = variables
        self.contractWords = contractWords
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
            let allocated = slots.allocateParameter(slot.name)
            scope.slots[slot.name] = allocated
            slots.hold(allocated, slot.shape)
        }

        let body = try lower(block, in: scope, on: slots, label: declared.label, at: place)

        table[row] = Linked(
            label: declared.label,
            origin: declared.origin,
            signature: declared.signature,
            purity: declared.purity,
            isolation: declared.isolation,
            failing: declared.failing,
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

        // What the link proved stands in a slot, for the slots it proved
        // anything about. A path reads its head here, so a field of a shape
        // the link laid out is lowered to the place it stands in.
        private var held: [Int: Shape] = [:]

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

        // A slot holds what the link proved, and holds nothing where it
        // proved nothing.
        func hold(_ slot: Int, _ shape: Shape?) {
            held[slot] = shape
        }

        func shape(of slot: Int) -> Shape? {
            held[slot]
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
                hold(slot, outer.slots.shape(of: taken))

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
            // A name that says what it holds settles to it, so what stands in
            // the slot is the declared shape. One that says nothing holds what
            // the code it was given stands as.
            case let .constant(name, declared)?:
                let slot = slots.allocate(name)
                let settling = declared?.lowered(in: shapes)
                scope.slots[name] = slot
                slots.hold(slot, settling ?? shape(of: code, on: slots))
                binding = .bind(slot, settling: settling)

            // A box that said what it holds is settled to it by its
            // declaration and by every write, so what stands in it is that
            // shape. One that said nothing is retyped by each write.
            case let .variable(name, declared)?:
                let slot = slots.allocate(name)
                let settling = declared?.lowered(in: shapes)
                scope.slots[name] = slot
                slots.hold(slot, settling)
                binding = .declare(slot, settling: settling)

            // A write settles to what the path reaches, so a box that said
            // what it holds holds it after a write as it did after its
            // declaration. A box that said nothing reaches nothing, and what
            // was written stands as it was handed.
            case let .assignment(path)?:
                let (address, reached) = try lower(path, in: scope, on: slots, at: place)
                binding = .assign(address, settling: reached?.slotUnwrapped)

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

    // What lowered code stands as, for the readings the link can prove
    // without judging anything: a record literal stands on the layout this
    // walk made for it, a call on what its row answers, a cast on what it
    // casts to, and a path on what it reaches. Nil everywhere else, which
    // leaves the fields below it to be read by name.
    private func shape(of code: Operation, on slots: Slots) -> Shape? {
        switch code {
        case let .record(held):
            return .record(
                RecordShape(
                    layout: held.layout,
                    fields: held.fields.map { field in shape(of: field, on: slots) ?? .any }
                )
            )

        case let .local(address):
            return address.steps.reduce(slots.shape(of: address.slot)) { reached, step in
                switch step {
                case let .field(_, name, _):
                    return reached?.place(of: name, in: shapes)?.shape

                case .index, .at:
                    return reached?.element(in: shapes)

                case let .word(row, _, _):
                    return table[row].returns

                case .key:
                    return nil
                }
            }

        case let .call(call):
            return table[call.procedure].returns

        case let .cast(_, shape, optional):
            return optional ? nil : shape

        default:
            return nil
        }
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
            let (address, _) = try lower(path, in: scope, on: slots, at: place)

            return .local(address)

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
                    failing: procedure.failing,
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
            slots.hold(slot, .record(.round))

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
            // A selector naming a contract's word names no row. Which row
            // answers is the receiver's, so every one the link found is
            // lowered here and the run picks by the name it reads.
            if let asked = contractWords[call.selector] {
                return .dispatch(
                    try lower(call, through: asked, in: scope, on: slots, label: label, at: place)
                )
            }

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
        through asked: ContractWord,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> DispatchOperation {
        guard let written = call.receiver else {
            throw unjudged("a call to '\(call.selector)' with nothing in front of it", at: place)
        }

        let receiver = try lower(written, in: scope, on: slots, label: label, at: place)

        if let stray = call.arguments.keys.first(where: { name in asked.signature.parameters[name] == nil }) {
            throw unjudged("an argument '\(stray)' that '\(call.selector)' does not declare", at: place)
        }

        // The receiver is dropped from the arguments: it is read once here,
        // and the run hands what it read to whichever row it picked.
        return DispatchOperation(
            contract: asked.contract,
            word: asked.word,
            receiver: receiver,
            arguments: try arguments(
                of: call,
                in: scope,
                on: slots,
                label: label,
                at: place
            )
        )
    }

    // What a call was written with, lowered once and under the names it was
    // written under. In name order, so which slots a nested body takes is the
    // text's fact rather than a dictionary's.
    private func arguments(
        of call: Call,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> [Name: Argument] {
        try call.arguments
            .sorted { left, right in left.key < right.key }
            .reduce(into: [Name: Argument]()) { lowered, entry in
                lowered[entry.key] = try argument(
                    entry.value,
                    in: scope,
                    on: slots,
                    label: label,
                    at: place
                )
            }
    }

    // One argument, kept as the place it names where it names one: a slot
    // taking it in place takes the caller's hold, and which slots do is the
    // callee's to say.
    private func argument(
        _ expression: Expression,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Argument {
        guard case let .reference(path) = expression else {
            return .value(try lower(expression, in: scope, on: slots, label: label, at: place))
        }

        let (address, _) = try lower(path, in: scope, on: slots, at: place)

        return .reference(address)
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

        return try CallOperation(
            handing: try arguments(of: call, in: scope, on: slots, label: label, at: place),
            receiver: try call.receiver.map { written in
                try argument(written, in: scope, on: slots, label: label, at: place)
            },
            to: callee,
            row: row,
            in: shapes,
            at: place
        )
    }

    private func lower(
        _ path: [PathSegment],
        in scope: Names,
        on slots: Slots,
        at place: Place
    ) throws -> (address: Address, reached: Shape?) {
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

        // What stands where the walk is, so a field of a shape the link laid
        // out is lowered to the place it stands in. It runs out as soon as the
        // walk reaches something the link did not prove, and every step from
        // there reads by name.
        var reached = slots.shape(of: slot)

        let steps = try path.dropFirst().map { segment -> Step in
            switch segment {
            case let .key(name, optional):
                guard let place = reached?.place(of: name, in: shapes) else {
                    reached = nil

                    return .key(name, optional: optional)
                }

                reached = place.shape

                return .field(place.position, name, optional: optional)

            case let .index(index, optional):
                reached = reached?.element(in: shapes)

                return .index(index, optional: optional)

            case let .indexRef(inner, optional):
                let (address, _) = try lower(inner, in: scope, on: slots, at: place)
                reached = reached?.element(in: shapes)

                return .at(address, optional: optional)

            case let .word(name, optional):
                guard let row = words[name] else {
                    throw unjudged("a word '\(name)' in '\(path.rendered)' that no path may reach", at: place)
                }

                reached = table[row].returns

                return .word(row, name, optional: optional)
            }
        }

        return (Address(slot: slot, steps: steps), reached)
    }

    // What the link should have refused before lowering and did not. Not a
    // sentence for an author to act on: it names the judgment that was
    // skipped, for whoever reads the link.
    private func unjudged(_ what: String, at place: Place) -> LinkError {
        LinkError("the link lowered \(what) without judging it", at: place)
    }
}
