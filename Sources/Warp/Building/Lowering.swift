//
//  Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Writes what the build proved into a body. Every name becomes the slot the
// frame holds it in, every selector the row it names, every argument the
// position of its parameter. Nothing is judged here: a name this walk cannot
// place is a body the build let through unjudged, and is refused as the
// build's own mistake.
//
// The table has one row per procedure. A closure literal is a procedure the
// document wrote inside another, so it is lifted out into a row of its own and
// the code that made it holds the number that reaches it.
struct Lowering {
    // MARK: - Property
    private(set) var table: [Linked]

    // Rows by declared spelling. Read for what a callee takes, which is what
    // judging a call against it needs. What a body is written with is the
    // document's own numbering.
    //
    // Held here and nowhere else while a compile lays its documents down. A
    // second holder of a growing table makes every write to it copy the whole
    // thing.
    private(set) var rows: [Name: Int] = [:]

    // Where each document's calls are numbered from. A body carries these
    // numbers rather than the rows above, so a document lowers the same way
    // whatever else the build was handed.
    private(set) var numbering: [Int: Numbering] = [:]

    // Each document's variables by name, in the order a run makes their boxes.
    private(set) var variables: [Int: [Name: Int]] = [:]

    // Every contract's procedures, under the spelling a call writes to reach one.
    // A selector in here names no row: it names the table of rows the run
    // picks from.
    let contractProcedures: [Name: ContractProcedure]

    // The declared types as the run reads them, for a cast's type and a
    // closure's row.
    let loweredTypes: LoweredTypeTable

    // What each document's lowered bodies stand on, by the rows of the table
    // above. Noted where a type is written into a body, which is where the
    // document that wrote it is known; the document's own numbering is worked
    // out from it once everything is lowered.
    private(set) var standing: [Int: Standing] = [:]

    // Which row of this table each document's closures took, in the order the
    // document numbers them. A closure is a row like any other; what tells it
    // apart is that no declared spelling reaches it, so this stands beside
    // `rows` rather than in it.
    private(set) var closureRows: [Int: [Int]] = [:]

    // How many closures each declaration has been lowered so far, by the
    // document that declared it. A closure's number is its declaration's start
    // plus this, so nesting counts with the rest: a closure inside a closure is
    // still one its declaration wrote.
    private var written: [Int: [Name: Int]] = [:]

    // MARK: - Initializer
    init(
        table: [Linked] = [],
        contractProcedures: [Name: ContractProcedure] = [:],
        loweredTypes: LoweredTypeTable
    ) {
        self.table = table
        self.contractProcedures = contractProcedures
        self.loweredTypes = loweredTypes
    }

    // The documents already laid down, read against the table this compile is
    // asking with. Where a row stands and what number reaches it are the
    // documents' own and move for nothing laid after them, so only the rows
    // are read again.
    init(
        _ carried: Carried,
        contractProcedures: [Name: ContractProcedure],
        loweredTypes: LoweredTypeTable
    ) {
        self.table = carried.table.map { row in Linked(row, in: loweredTypes) }
        self.rows = carried.rows
        self.numbering = carried.numbering
        self.variables = carried.variables
        self.closureRows = carried.closureRows
        self.contractProcedures = contractProcedures
        self.loweredTypes = loweredTypes
    }

    // A lowering standing on tables something else holds: an expression
    // folded beside a document's bodies rather than into a row of its own.
    init(
        table: [Linked],
        rows: [Name: Int],
        numbering: [Int: Numbering],
        loweredTypes: LoweredTypeTable
    ) {
        self.table = table
        self.rows = rows
        self.numbering = numbering
        self.contractProcedures = [:]
        self.loweredTypes = loweredTypes
    }

    // MARK: - Public
    // One document laid down: its declarations take the rows after the ones
    // already here, in the order they are handed over, then the closures its
    // bodies lifted, and its numbering says what the bodies it lowers are
    // written with.
    //
    // A document being compiled lifts its closures as it lowers, so it hands
    // none over here. One already compiled hands over the block it left.
    @discardableResult
    mutating func hold(
        _ origin: Int,
        standing block: [Linked],
        closures lifted: [Linked] = [],
        numbering held: Numbering,
        variables ordered: [Name]
    ) -> Range<Int> {
        let start = table.count

        for (offset, row) in block.enumerated() {
            rows[row.label] = start + offset
        }

        closureRows[origin] = lifted.indices.map { offset in start + block.count + offset }

        table.append(contentsOf: block)
        table.append(contentsOf: lifted)
        numbering[origin] = held
        variables[origin] = ordered.enumerated().reduce(into: [Name: Int]()) { positions, name in
            positions[name.element] = name.offset
        }

        return start ..< start + block.count
    }

    // The same rows, answered. One per row, in place: what stands in the
    // table is what every number of it already reaches.
    mutating func replace(table answered: [Linked]) {
        assert(answered.count == table.count, "a table is answered row for row")

        table = answered
    }

    // A type the build read off a body rather than out of a signature. It is
    // written into no body, so what it stands on is noted here: its document
    // numbers it beside the types its bodies stand on.
    mutating func stands(on type: LoweredType, of origin: Int) {
        var stood = standing[origin] ?? Standing()

        type.standing(into: &stood.types, and: &stood.memberships)

        standing[origin] = stood
    }

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
            slots.hold(allocated, slot.type)
        }

        let body = try lower(block, in: scope, on: slots, label: declared.label, at: place)

        standing[declared.origin, default: Standing()].types.formUnion(slots.types)
        standing[declared.origin, default: Standing()].memberships.formUnion(slots.memberships)

        table[row] = Linked(declared, implementation: .body(body, slots.frame), sends: declared.sends)
    }

    // Lowers one expression read against a frame of constants, as a constant's
    // own expression is, and as a body's constant path is when it folds. The
    // frame starts as `names` in slot order and grows with what the
    // expression declares; the frame says how large it is.
    mutating func lower(
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

    // MARK: - Internal
    // What one document's lowered bodies stand on, by the rows of the table
    // they were lowered against.
    struct Standing {
        var types: Set<Int> = []
        var memberships: Set<Int> = []
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

        // What the build proved stands in a slot, for the slots it proved
        // anything about. A path reads its head here, so a field of a type
        // the build laid out is lowered to the place it stands in.
        private var held: [Int: LoweredType] = [:]

        // The declarations the types written into this body stand on, by the
        // rows of the table it was lowered against. Read where the document's
        // own numbering is worked out.
        private(set) var types: Set<Int> = []
        private(set) var memberships: Set<Int> = []

        init(origin: Int, variables: [Name: Int], outer: (slots: Slots, names: Names)? = nil) {
            self.origin = origin
            self.variables = variables
            self.outer = outer
        }

        var size: Int { names.count }

        // Notes what a type written into this body stands on. A closure notes
        // into the body it was written in: the two are one document, and a
        // document has one numbering.
        //
        // Read through the walk that rewrites a type's rows, so which cases
        // hold a row is answered in one place. What that walk rebuilds is
        // dropped here.
        func note(_ type: LoweredType?) {
            guard let type else { return }

            note(type)
        }

        func note(_ type: LoweredType) {
            let root = self.root

            _ = type.renumbered(
                type: { row in
                    root.types.insert(row)

                    return row
                },
                membership: { row in
                    root.memberships.insert(row)

                    return row
                }
            )
        }

        private var root: Slots {
            outer?.slots.root ?? self
        }

        func allocate(_ name: Name) -> Int {
            names.append(name)

            return names.count - 1
        }

        // A slot holds what the build proved, and holds nothing where it
        // proved nothing.
        func hold(_ slot: Int, _ type: LoweredType?) {
            held[slot] = type
        }

        func held(at slot: Int) -> LoweredType? {
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
                hold(slot, outer.slots.held(at: taken))

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
            Frame(size: size, parameters: parameters, variables: reads, captures: captures.map { _, inner in inner }, names: names)
        }
    }

    private mutating func lower(
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
    private mutating func lower(
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
            // the slot is the declared type. One that says nothing holds what
            // the code it was given stands as.
            case let .constant(name, declared)?:
                let slot = slots.allocate(name)
                let settling = declared?.lowered(in: loweredTypes)
                slots.note(settling)
                scope.slots[name] = slot
                slots.hold(slot, settling ?? standing(code, on: slots))
                binding = .bind(slot, settling: settling)

            // A box that said what it holds is settled to it by its
            // declaration and by every write, so what stands in it is that
            // type. One that said nothing is retyped by each write.
            case let .variable(name, declared)?:
                let slot = slots.allocate(name)
                let settling = declared?.lowered(in: loweredTypes)
                slots.note(settling)
                scope.slots[name] = slot
                slots.hold(slot, settling)
                binding = .declare(slot, settling: settling)

            // A write settles to what the path reaches, so a box that said
            // what it holds holds it after a write as it did after its
            // declaration. A box that said nothing reaches nothing, and what
            // was written stands as it was handed.
            case let .assignment(path)?:
                let (address, reached) = try lower(path, in: scope, on: slots, at: place)
                let settling = reached?.slotUnwrapped
                slots.note(settling)
                binding = .assign(address, settling: settling)

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

    // What lowered code stands as, for the readings the build can prove
    // without judging anything: a record literal stands on the layout this
    // walk made for it, a call on what its row answers, a cast on what it
    // casts to, and a path on what it reaches. Nil everywhere else, which
    // leaves the fields below it to be read by name.
    private func standing(_ code: Operation, on slots: Slots) -> LoweredType? {
        switch code {
        case let .record(held):
            return .record(
                LoweredRecord(
                    layout: held.layout,
                    fields: held.fields.map { field in standing(field, on: slots) ?? .any }
                )
            )

        case let .local(address):
            return address.steps.reduce(slots.held(at: address.slot)) { reached, step in
                switch step {
                case let .field(_, name, _):
                    return reached?.place(of: name, in: loweredTypes)?.type

                case .index, .at:
                    return reached?.element(in: loweredTypes)

                case .key:
                    return nil
                }
            }

        // The call carries its document's number, so what it answers is read
        // by the row that number stands for here.
        case let .call(call):
            return reached(call.procedure, on: slots).map { row in table[row].returns } ?? nil

        case let .cast(_, type, optional):
            return optional ? nil : type

        default:
            return nil
        }
    }

    private mutating func lower(
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
            return try lower(record: record, in: scope, on: slots, label: label, at: place)

        case let .closure(procedure):
            return try lower(closure: procedure, in: scope, on: slots, label: label, at: place)

        case let .apply(callee, arguments):
            return try lower(apply: callee, arguments: arguments, in: scope, on: slots, label: label, at: place)

        case let .cast(value, type, optional):
            return try lower(cast: value, as: type, optional: optional, in: scope, on: slots, label: label, at: place)

        case let .block(block):
            return .block(try lower(block, in: scope, on: slots, label: label, at: place))

        case let .conditional(condition, then, otherwise):
            return try lower(conditional: condition, then: then, else: otherwise, in: scope, on: slots, label: label, at: place)

        case let .loop(condition, body, round):
            return try lower(loop: condition, body: body, round: round, in: scope, on: slots, label: label, at: place)

        case let .attempt(block, rescue, failure):
            return try lower(attempt: block, rescue: rescue, failure: failure, in: scope, on: slots, label: label, at: place)

        case let .call(call):
            // A selector naming a contract's procedure names no row. Which row
            // answers is the receiver's, so every one the build found is
            // lowered here and the run picks by the name it reads.
            if let asked = contractProcedures[call.selector] {
                return .dispatch(try lower(call, through: asked, in: scope, on: slots, label: label, at: place))
            }

            return .call(try lower(call, in: scope, on: slots, label: label, at: place))

        case let .leave(leave):
            return try lower(leave: leave, in: scope, on: slots, label: label, at: place)
        }
    }

    // A construct with locals of its own is lowered in a function of its
    // own. The switch above is what every nested expression passes through
    // on the way down, and it carries no construct's locals but the one it
    // is lowering.
    private mutating func lower(
        record: [Name: Expression],
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        let ordered = record.sorted { $0.key < $1.key }

        return .record(
            RecordOperation(
                layout: Layout(name: nil, ordered: ordered.map(\.key)),
                fields: try ordered.map { _, field in
                    try lower(field, in: scope, on: slots, label: label, at: place)
                }
            )
        )
    }

    private mutating func lower(
        closure procedure: Procedure,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        guard let block = procedure.block else {
            throw BuildError.unjudged("a closure with no body", at: place)
        }

        let inner = Slots(origin: slots.origin, variables: slots.variables, outer: (slots, scope))
        var innerScope = Names()

        for name in procedure.signature.names {
            innerScope.slots[name] = inner.allocateParameter(name)
        }

        let body = try lower(block, in: innerScope, on: inner, label: label, at: place)

        // Taken before the body is lowered would number a closure before
        // the ones it holds; taken after numbers the innermost first. The
        // count read off the document walks the same way, so this reads it
        // here.
        let count = written[slots.origin, default: [:]][label, default: 0]
        written[slots.origin, default: [:]][label] = count + 1

        let held = numbered(slots.origin)
        let row = table.count
        let stands: (number: Int, nth: Int)?

        if held.numbersAreRows {
            stands = nil
        } else if let given = held.closure(count, of: label) {
            stands = given
        } else if let counted = held.count(of: label) {
            throw BuildError.unjudged("closure \(count) of a declaration whose document numbered \(counted)", at: place)
        } else {
            throw BuildError.unjudged("a closure in a declaration whose document numbered none", at: place)
        }

        table.append(
            Linked(
                label: label,
                origin: slots.origin,
                signature: procedure.signature,
                constness: procedure.constness,
                isolation: procedure.isolation,
                failing: procedure.failing,
                implementation: .body(body, inner.frame),
                foldable: true,
                nth: count,
                in: loweredTypes
            )
        )

        guard let stands else { return .closure(row, captures: inner.captures) }

        var taken = closureRows[slots.origin] ?? []

        if taken.count <= stands.nth {
            taken.append(contentsOf: Array(repeating: row, count: stands.nth + 1 - taken.count))
        }

        taken[stands.nth] = row
        closureRows[slots.origin] = taken

        return .closure(stands.number, captures: inner.captures)
    }

    private mutating func lower(
        apply callee: Expression,
        arguments: [Name: Expression],
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        return .apply(
            try lower(callee, in: scope, on: slots, label: label, at: place),
            arguments: try arguments.sorted { $0.key < $1.key }.map { name, argument in
                (name, try lower(argument, in: scope, on: slots, label: label, at: place))
            }
        )
    }

    private mutating func lower(
        cast value: Expression,
        as type: TypeExpression,
        optional: Bool,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        let lowered = type.lowered(in: loweredTypes)
        slots.note(lowered)

        return .cast(
            try lower(value, in: scope, on: slots, label: label, at: place),
            as: lowered,
            optional: optional
        )
    }

    private mutating func lower(
        conditional condition: Expression,
        then: [Statement],
        else otherwise: [Statement]?,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        var thenScope = scope
        var elseScope = scope

        return .conditional(
            try lower(condition, in: scope, on: slots, label: label, at: place),
            then: try lower(then, in: &thenScope, on: slots, label: label, at: place),
            else: try otherwise.map { statements in
                try lower(statements, in: &elseScope, on: slots, label: label, at: place)
            }
        )
    }

    private mutating func lower(
        loop condition: Expression,
        body: Block,
        round: Name,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
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
    }

    private mutating func lower(
        attempt block: Block,
        rescue: Block,
        failure: Name,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        let attempted = try lower(block, in: scope, on: slots, label: label, at: place)
        var inner = scope
        let slot = slots.allocate(failure)
        inner.slots[failure] = slot

        return .attempt(
            attempted,
            rescue: try lower(rescue, in: inner, on: slots, label: label, at: place),
            failure: slot
        )
    }

    private mutating func lower(
        leave: Leave,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> Operation {
        return .leave(
            leave.reach,
            target: leave.target,
            try leave.value.map { value in
                try lower(value, in: scope, on: slots, label: label, at: place)
            }
        )
    }

    private mutating func lower(
        _ call: Call,
        through asked: ContractProcedure,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> DispatchOperation {
        guard let written = call.receiver else {
            throw BuildError.unjudged("a call to '\(call.selector)' with nothing in front of it", at: place)
        }

        let receiver = try lower(written, in: scope, on: slots, label: label, at: place)

        if let stray = call.arguments.keys.first(where: { name in asked.signature.parameters[name] == nil }) {
            throw BuildError.unjudged("an argument '\(stray)' that '\(call.selector)' does not declare", at: place)
        }

        // The receiver is dropped from the arguments: it is read once here,
        // and the run hands what it read to whichever row it picked.
        return DispatchOperation(
            contract: asked.contract,
            procedure: asked.procedure,
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
    private mutating func arguments(
        of call: Call,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> [Name: Argument] {
        var lowered: [Name: Argument] = [:]

        for (name, written) in call.arguments.sorted(by: { left, right in left.key < right.key }) {
            lowered[name] = try argument(written, in: scope, on: slots, label: label, at: place)
        }

        return lowered
    }

    // One argument, kept as the place it names where it names one: a slot
    // taking it in place takes the caller's hold, and which slots do is the
    // callee's to say.
    private mutating func argument(
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

    private mutating func lower(
        _ call: Call,
        in scope: Names,
        on slots: Slots,
        label: Name,
        at place: Place
    ) throws -> CallOperation {
        guard let row = rows[call.selector] else {
            throw BuildError.unjudged("a call to '\(call.selector)', which has no row", at: place)
        }

        let callee = table[row]

        guard let stands = numbered(slots.origin).call(call.selector) else {
            throw BuildError.unjudged("a call to '\(call.selector)', which the document never asked for", at: place)
        }

        return try CallOperation(
            handing: { name in
                try call.arguments[name].map { written in
                    try argument(written, in: scope, on: slots, label: label, at: place)
                }
            },
            written: call.arguments.keys,
            receiver: try call.receiver.map { written in
                try argument(written, in: scope, on: slots, label: label, at: place)
            },
            to: callee,
            row: stands,
            in: loweredTypes,
            at: place
        )
    }

    private mutating func lower(
        _ path: [PathSegment],
        in scope: Names,
        on slots: Slots,
        at place: Place
    ) throws -> (address: Address, reached: LoweredType?) {
        // A mark on the head expects a name to be missing, which is not
        // absence but a reading gone wrong.
        if let refusal = path.markedHead {
            throw BuildError(refusal, at: place)
        }

        guard case let .key(head, _)? = path.first else {
            throw BuildError.unjudged("a path '\(path.rendered)' with no name at its head", at: place)
        }

        guard let slot = slots.slot(of: head, in: scope) else {
            throw BuildError.unjudged("a name '\(head)' in '\(path.rendered)' that nothing declares", at: place)
        }

        // What stands where the walk is, so a field of a type the build laid
        // out is lowered to the place it stands in. It runs out as soon as the
        // walk reaches something the build did not prove, and every step from
        // there reads by name.
        var reached = slots.held(at: slot)

        let steps = try path.dropFirst().map { segment -> Step in
            switch segment {
            case let .key(name, optional):
                guard let place = reached?.place(of: name, in: loweredTypes) else {
                    reached = nil

                    return .key(name, optional: optional)
                }

                reached = place.type

                return .field(place.position, name, optional: optional)

            case let .index(index, optional):
                reached = reached?.element(in: loweredTypes)

                return .index(index, optional: optional)

            case let .indexRef(inner, optional):
                let (address, _) = try lower(inner, in: scope, on: slots, at: place)
                reached = reached?.element(in: loweredTypes)

                return .at(address, optional: optional)

            }
        }

        return (Address(slot: slot, steps: steps), reached)
    }

    // Which row of the link a number in a lowered body stands for. The body
    // carries its document's numbering, and this walk reads what it just
    // wrote.
    private func reached(_ number: Int, on slots: Slots) -> Int? {
        guard case let .row(row) = numbered(slots.origin).row(
            number,
            rows: rows,
            closures: closureRows[slots.origin] ?? []
        ) else {
            return nil
        }

        return row
    }

    // Where the document being lowered numbers its calls from. A document
    // with nothing to number has none, and a call in a body it never held is
    // the link's own mistake.
    private func numbered(_ origin: Int) -> Numbering {
        numbering[origin] ?? Numbering(sends: [], declared: [])
    }

}
