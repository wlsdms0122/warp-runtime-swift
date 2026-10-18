//
//  Lowering.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

// Writes what the build proved into a body. Every name becomes the slot the
// frame holds it in, every selector the row it names, every argument the
// position of its parameter, and every path the steps the type check placed
// it at. Nothing is judged here: a name this walk cannot place is a body the
// build let through unjudged, and is refused as the build's own mistake.
//
// The table has one row per procedure. A closure literal is a procedure the
// document wrote inside another, so it is lifted out into a row of its own and
// the code that made it holds the number that reaches it.
struct Lowering {
    // One document as it was held: where its calls are numbered from, its
    // declarations by row, private ones included, its variables by name in
    // the order a run makes their boxes, and which row each of its closures
    // took, in the order it numbers them.
    struct Document: Sendable {
        // MARK: - Property
        let numbering: Numbering
        let owned: [Name: Int]
        let variables: [Name: Int]

        var closureRows: [Int]

        // Which row each name it numbers stands for, once resolved. The names
        // and the closures get their rows at different times: a name's row is the
        // link's before anything is lowered, and a closure's row is made by
        // lowering.
        var named: [Int?]?

        // Which row each number it gave stands for: its names, then its
        // closures. A closure with no row yet stands as nothing, the same as a
        // name with none, and so does every number before its names resolve.
        var resolved: [Int?] {
            guard let named else { return [] }

            return named + (0..<numbering.closureCount).map { written in
                closureRows.indices.contains(written) ? closureRows[written] : nil
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // The names visible at one point of a body, by slot. A value, so a block
    // takes a copy and what it introduces dies with it.
    private struct SlotScope {
        // MARK: - Property
        var slots: [Name: Int] = [:]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // The slots of one body being lowered. A closure's slots know the slots
    // and names of the body it was written in, and take a cell from there
    // the first time the closure reads a name it did not declare.
    private final class SlotAllocator {
        // MARK: - Property
        let origin: Int
        let variables: [Name: Int]

        // The document's constants, settled, for the slots of a declaration's
        // own body. A body names one only where the fold could not settle the
        // read, an index the run reads, and then the constant takes a slot
        // the body binds before its first statement.
        let constants: [Name: Value]
        let outer: (slots: SlotAllocator, names: SlotScope)?

        private(set) var names: [Name] = []
        private(set) var parameters: [Int] = []
        private(set) var reads: [(variable: Int, slot: Int)] = []
        private(set) var captures: [(Int, Int)] = []
        private(set) var constantBindings: [(slot: Int, value: Value)] = []

        private var variableSlots: [Name: Int] = [:]
        private var capturedSlots: [Name: Int] = [:]
        private var constantSlots: [Name: Int] = [:]

        var size: Int { names.count }

        var frame: Frame {
            Frame(
                size: size,
                parameters: parameters,
                variables: reads,
                captures: captures.map { _, inner in inner },
                names: names
            )
        }

        // MARK: - Initializer
        init(
            origin: Int,
            variables: [Name: Int],
            constants: [Name: Value],
            outer: (slots: SlotAllocator, names: SlotScope)? = nil
        ) {
            self.origin = origin
            self.variables = variables
            self.constants = constants
            self.outer = outer
        }

        // MARK: - Public
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
        // through the body it was written in, so the slot it captures is
        // that body's.
        func slot(of name: Name, in names: SlotScope) -> Int? {
            if let slot = names.slots[name] { return slot }

            if let slot = capturedSlots[name] { return slot }

            if let outer, let taken = outer.slots.slot(of: name, in: outer.names) {
                let slot = allocate(name)
                capturedSlots[name] = slot
                captures.append((taken, slot))

                return slot
            }

            if let slot = variableSlots[name] { return slot }

            if let variable = variables[name] {
                let slot = allocate(name)
                variableSlots[name] = slot
                reads.append((variable: variable, slot: slot))

                return slot
            }

            if let slot = constantSlots[name] { return slot }

            guard let constant = constants[name] else { return nil }

            let slot = allocate(name)
            constantSlots[name] = slot
            constantBindings.append((slot: slot, value: constant))

            return slot
        }

        // The body with the constants it reads bound before its first
        // statement, so a read the fold could not settle stands on a slot the
        // way any name's does.
        func binding(_ body: LoweredBody) -> LoweredBody {
            guard !constantBindings.isEmpty else { return body }

            let bindings = constantBindings.map { slot, value in
                Instruction(binding: .bind(slot), code: .literal(value), label: names[slot].spelling)
            }

            return LoweredBody(instructions: bindings + body.instructions, result: body.result)
        }

        // MARK: - Private
    }

    // What lowering one body reads beside the names in scope: the slots it
    // allocates, the declaration its closures are numbered under, and what
    // the type check judged at each place in it. One per body: a closure is
    // lowered on slots of its own and shares the other two with the body it
    // was written in.
    private struct Context {
        // MARK: - Property
        let slots: SlotAllocator
        let writer: Closure.Declaration
        let judgements: JudgementTable

        // MARK: - Initializer
        // MARK: - Public
        // The same context with other slots, the way a closure's body is
        // lowered on slots of its own.
        func with(slots: SlotAllocator) -> Context {
            Context(slots: slots, writer: writer, judgements: judgements)
        }

        // MARK: - Private
    }

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

    // Every document held, by origin. A body carries its document's numbers
    // rather than the rows above, so a document lowers the same way whatever
    // else the build was handed.
    private(set) var documents: [Document] = []

    // Every contract's procedures, under the spelling a call writes to reach one.
    // A selector in here names no row: it names the table of rows the run
    // picks from.
    let contractProcedures: [Name: LoweredContractProcedure]

    // The declared types as the run reads them, for a cast's type and a
    // closure's row, answering with the claims the document being lowered
    // stands on.
    private(set) var loweredTypes: LoweredTypeTable

    // Each document's constants, settled.
    private var constants: [Int: [Name: Value]] = [:]

    // The spellings only a private declaration wears, of every document this
    // lowering holds, for the refusal alone: not in `rows`, since nothing
    // outside their documents names them, and read only after a row lookup
    // has failed, to say why it did.
    let concealed: Set<Name>

    // How many closures each declaration has been lowered so far, by the
    // document that declared it. A closure's number is its declaration's start
    // plus this, so nesting counts with the rest: a closure inside a closure is
    // still one its declaration wrote.
    private var written: [Int: [Closure.Declaration: Int]] = [:]

    // MARK: - Initializer
    init(
        table: [Linked] = [],
        concealing concealed: Set<Name> = [],
        contractProcedures: [Name: LoweredContractProcedure] = [:],
        loweredTypes: LoweredTypeTable
    ) {
        self.table = table
        self.concealed = concealed
        self.contractProcedures = contractProcedures
        self.loweredTypes = loweredTypes
    }

    // The documents already laid down, read against the table this compile is
    // asking with. Where a row stands and what number reaches it are the
    // documents' own and move for nothing laid after them, so only the rows
    // are read again.
    init(
        _ carried: Carried,
        concealing concealed: Set<Name>,
        contractProcedures: [Name: LoweredContractProcedure],
        loweredTypes: LoweredTypeTable
    ) {
        self.table = carried.table.map { row in Linked(row, in: loweredTypes) }
        self.rows = carried.rows
        self.concealed = concealed
        self.documents = carried.documents
        self.contractProcedures = contractProcedures
        self.loweredTypes = loweredTypes
    }

    // MARK: - Public
    // The document lowered next answers with the claims it stands on. The
    // rows are the same rows.
    mutating func answer(with loweredTypes: LoweredTypeTable) {
        self.loweredTypes = loweredTypes
    }

    // One document laid down: its declarations take the rows after the ones
    // already here, in the order they are handed over, then the closures its
    // bodies lifted, and its numbering says what the bodies it lowers are
    // written with.
    //
    // A document being compiled lifts its closures as it lowers, so it hands
    // none over here. One already compiled hands over the block it left.
    //
    // Its origin is where it is held, which is what this answers beside the
    // rows its declarations took.
    mutating func hold(
        standing block: [Linked],
        closures lifted: [Linked] = [],
        numbering held: Numbering,
        variables ordered: [Name]
    ) -> (origin: Int, block: Range<Int>) {
        let start = table.count

        // A private declaration takes no spelling from the link: its own
        // document reaches it by the block, and nothing else reaches it.
        var own: [Name: Int] = [:]

        for (offset, row) in block.enumerated() {
            own[row.label] = start + offset

            guard row.access.reachesOtherDocuments else { continue }

            rows[row.label] = start + offset
        }

        documents.append(
            Document(
                numbering: held,
                owned: own,
                variables: ordered.enumerated().reduce(into: [Name: Int]()) { positions, name in
                    positions[name.element] = name.offset
                },
                closureRows: lifted.indices.map { offset in start + block.count + offset }
            )
        )

        table.append(contentsOf: block)
        table.append(contentsOf: lifted)

        return (origin: documents.count - 1, block: start ..< start + block.count)
    }

    // Which row each number a document gave stands for. A number of its own
    // reaches a name it declared or one behind it, so the resolution never
    // moves after this.
    mutating func resolve(_ origin: Int) {
        documents[origin].named = documents[origin].numbering.resolved(rows: rows, own: own(origin))
    }

    // Every call a document's lowered bodies stand, held to the row its
    // number now stands for. A document compiled already is laid with its
    // bodies, and a fold may run one before any link counts it.
    func refuseMiscountedCalls(of origin: Int, at document: Place.Document) throws {
        let held = documents[origin]
        let resolved = held.resolved

        for row in held.owned.values.sorted() + held.closureRows {
            guard case let .body(body, _) = table[row].implementation else { continue }

            for call in body.standing.calls {
                guard resolved.indices.contains(call.number), let callee = resolved[call.number] else { continue }

                try table[callee].refuseCall(
                    standing: call.arguments,
                    at: .procedure(table[row].label.spelling, in: document)
                )
            }
        }
    }

    // The same rows, answered. One per row, in place: what stands in the
    // table is what every number of it already reaches.
    mutating func replace(table answered: [Linked]) {
        assert(answered.count == table.count, "a table is answered row for row")

        table = answered
    }

    // A document's constants, once they settle.
    mutating func settle(constants settled: [Name: Value], of origin: Int) {
        constants[origin] = settled
    }

    // Lowers a declaration's body into its row. `judgements` is what the type
    // check judged at each place in it.
    mutating func lower(_ row: Int, body block: Block, judgements: JudgementTable, at place: Place) throws {
        let declared = table[row]
        let slots = SlotAllocator(
            origin: declared.origin,
            variables: documents[declared.origin].variables,
            constants: constants[declared.origin] ?? [:]
        )
        var scope = SlotScope()

        for slot in declared.slots {
            scope.slots[slot.name] = slots.allocateParameter(slot.name)
        }

        let body = try lower(
            block,
            in: scope,
            on: Context(slots: slots, writer: .procedure(declared.label), judgements: judgements),
            at: place
        )

        table[row] = Linked(declared, implementation: .body(slots.binding(body), slots.frame))
    }

    // A document's own declarations by row, as they were held.
    func own(_ origin: Int) -> [Name: Int] {
        documents[origin].owned
    }

    // Lowers one expression read against a frame of constants, as a constant's
    // own expression is. The frame starts as `names` in slot order and grows
    // with what the expression declares; the frame says how large it is.
    mutating func lower(
        _ expression: Expression,
        reading names: [Name],
        origin: Int,
        writer: Closure.Declaration,
        judgements: JudgementTable,
        at place: Place
    ) throws -> (Operation, Frame) {
        let slots = SlotAllocator(origin: origin, variables: [:], constants: [:])
        var scope = SlotScope()

        for name in names {
            scope.slots[name] = slots.allocate(name)
        }

        let code = try lower(
            expression,
            naming: nil,
            in: scope,
            on: Context(slots: slots, writer: writer, judgements: judgements),
            at: place
        )

        return (code, slots.frame)
    }

    // Lowers a path read against a frame of constants in slot order, as a
    // body's constant path is when it folds.
    func lower(
        _ path: LoweredPath,
        reading names: [Name],
        origin: Int,
        at place: Place
    ) throws -> (Operation, Frame) {
        let slots = SlotAllocator(origin: origin, variables: [:], constants: [:])
        var scope = SlotScope()

        for name in names {
            scope.slots[name] = slots.allocate(name)
        }

        let address = try lower(path, in: scope, on: slots, at: place)

        return (.local(address), slots.frame)
    }

    // One document's rows with the types in them numbered by that document,
    // beside the numbering that says what those numbers stand for.
    //
    // Lowering reads the link's table to judge, so the type rows it writes
    // are that link's. This turns them into the document's own, which is what
    // leaves compiling: a body carries its document's numbers and nothing
    // about the graph it was linked into.
    //
    // A document's numbering is its names in name order, and no name is in
    // order until every one of them is known, so this runs once the
    // document's last body is lowered and not while one is.
    func numbered(_ rows: [Int]) throws -> (table: [Linked], numbering: LoweredTypeNumbering) {
        // What the document stands on is what it numbers: every type in its
        // rows' bodies. Read through the walks that rewrite them, so which
        // cases hold a type is answered in one place; what those walks
        // rebuild is dropped.
        var types: Set<Int> = []

        func stand(_ type: LoweredType) -> LoweredType {
            type.standing(into: &types)

            return type
        }

        for row in rows {
            guard case let .body(body, _) = table[row].implementation else { continue }

            _ = body.rewritten(operation: { operation in operation }, type: stand)
        }

        let numbering = LoweredTypeNumbering(types: Set(types.map { row in loweredTypes.labels[row] }))

        // Which number each row of this link stands at, so the walk that
        // writes them reads a place rather than hashing a name at every
        // type it meets.
        let place = Self.placed(types, among: numbering.types, spelling: loweredTypes.labels)

        let numbered = try rows.map { row -> Linked in
            let held = table[row]

            guard case .body = held.implementation else { return held }

            return try held.renumbered { type in
                try renumbered(type, in: place, of: held.label)
            }
        }

        return (numbered, numbering)
    }

    // MARK: - Private
    private mutating func lower(
        _ block: Block,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> LoweredBody {
        var inner = scope
        let instructions = try lower(block.body, in: &inner, on: context, at: place.child(.body))
        let result = try block.result.map { result in
            try lower(result, naming: nil, in: inner, on: context, at: place.child(.result))
        }

        return LoweredBody(instructions: instructions, result: result)
    }

    // Statements in order: a statement's expression is lowered before the
    // name it binds exists, so a name reads what the statement before it
    // bound.
    private mutating func lower(
        _ body: Body,
        in scope: inout SlotScope,
        on context: Context,
        at place: Place
    ) throws -> [Instruction] {
        var instructions: [Instruction] = []

        for (position, statement) in body.statements.enumerated() {
            let here = place.statement(statement, at: position)
            let code = try lower(statement.expression, naming: statement.binding?.introduced, in: scope, on: context, at: here)
            let binding: Instruction.Binding?

            switch statement.bindingAfter {
            case let .constant(name, _)?:
                let slot = context.slots.allocate(name)
                scope.slots[name] = slot
                binding = .bind(slot)

            case let .variable(name, _)?:
                let slot = context.slots.allocate(name)
                scope.slots[name] = slot
                binding = .declare(slot)

            // A write lands where the build placed it.
            case let .assignment(path)?:
                guard let placed = context.judgements.path(writtenAt: here) else {
                    throw BuildError.unjudged("a path '\(path.rendered)' the build did not place", at: here)
                }

                binding = .assign(try lower(placed, in: scope, on: context.slots, at: here))

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

    // `name` is what the statement this expression is the value of
    // introduces, which a loop binds its round under and an attempt its
    // failure.
    private mutating func lower(
        _ expression: Expression,
        naming name: Name?,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        switch expression {
        case let .literal(value):
            return .literal(value)

        case let .reference(path):
            return .local(try lower(reference: path, in: scope, on: context, at: place))

        case let .array(array):
            return .array(try array.enumerated().map { position, element in
                try lower(element, naming: nil, in: scope, on: context, at: place.child(.element(position)))
            })

        case let .struct(literal):
            return try lower(literal: literal, in: scope, on: context, at: place)

        case let .dictionary(entries):
            return .dictionary(try entries.enumerated().map { position, entry in
                (
                    key: try lower(entry.key, naming: nil, in: scope, on: context, at: place.child(.entryKey(position))),
                    value: try lower(entry.value, naming: nil, in: scope, on: context, at: place.child(.entryValue(position)))
                )
            })

        case let .closure(procedure):
            return try lower(closure: procedure, in: scope, on: context, at: place)

        case let .apply(callee, arguments):
            return try lower(
                apply: callee,
                arguments: arguments,
                in: scope,
                on: context,
                at: place
            )

        case let .cast(value, type, optional):
            return try lower(cast: value, as: type, optional: optional, in: scope, on: context, at: place)

        case let .conditional(condition, then, otherwise):
            return try lower(conditional: condition, then: then, else: otherwise, in: scope, on: context, at: place)

        case let .loop(condition, body):
            return try lower(loop: condition, body: body, round: name, in: scope, on: context, at: place)

        case let .attempt(block, rescue):
            return try lower(attempt: block, rescue: rescue, failure: name, in: scope, on: context, at: place)

        case let .call(call):
            // A selector naming a contract's procedure names no row. Which row
            // answers is the first argument's, so every one the build found is
            // lowered here and the run picks by the name it reads.
            if let asked = contractProcedures[call.selector] {
                return .dispatch(try lower(call, through: asked, in: scope, on: context, at: place))
            }

            return .call(try lower(call, in: scope, on: context, at: place))

        case let .leave(leave):
            return try lower(leave: leave, in: scope, on: context, at: place)
        }
    }

    // A construct with locals of its own is lowered in a function of its
    // own. The switch above is what every nested expression passes through
    // on the way down, and it carries no construct's locals but the one it
    // is lowering.
    private mutating func lower(
        literal: [Name: Expression],
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        let ordered = literal.sorted { $0.key < $1.key }

        // The type check read the literal as the declared struct its place
        // reads, which the struct is built under.
        guard let name = context.judgements.name(ofStructAt: place) else {
            throw BuildError.unjudged("a struct literal", at: place)
        }

        return .struct(
            StructOperation(
                layout: Layout(name: name, ordered: ordered.map(\.key)),
                fields: try ordered.map { name, field in
                    try lower(field, naming: nil, in: scope, on: context, at: place.child(.field(name)))
                }
            )
        )
    }

    private mutating func lower(
        closure procedure: Procedure,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        // The Validator refuses a closure literal that is not a body.
        guard case let .body(block) = procedure.implementation else {
            throw BuildError.unjudged("a closure literal", at: place)
        }

        // A closure reaches a constant the way it reaches a module variable,
        // through the body it was written in, so the slot it takes is that
        // body's and the binding is that body's.
        let inner = SlotAllocator(
            origin: context.slots.origin,
            variables: [:],
            constants: [:],
            outer: (context.slots, scope)
        )
        var innerScope = SlotScope()

        for name in procedure.signature.names {
            innerScope.slots[name] = inner.allocateParameter(name)
        }

        let body = try lower(block, in: innerScope, on: context.with(slots: inner), at: place.child(.closure))

        // Taken before the body is lowered would number a closure before
        // the ones it holds; taken after numbers the innermost first. The
        // count read off the document walks the same way, so this reads it
        // here.
        let count = written[context.slots.origin, default: [:]][context.writer, default: 0]
        written[context.slots.origin, default: [:]][context.writer] = count + 1

        let held = documents[context.slots.origin].numbering
        let row = table.count

        guard let stands = held.closure(count, of: context.writer) else {
            guard let counted = held.count(of: context.writer) else {
                throw BuildError.unjudged("a closure in a declaration whose document numbered none", at: place)
            }

            throw BuildError.unjudged("closure \(count) of a declaration whose document numbered \(counted)", at: place)
        }

        table.append(
            Linked(
                label: context.writer.name,
                origin: context.slots.origin,
                signature: procedure.signature,
                access: .private,
                implementation: .body(body, inner.frame),
                foldable: true,
                closure: (by: context.writer, nth: count),
                in: loweredTypes
            )
        )

        var taken = documents[context.slots.origin].closureRows

        if taken.count <= stands.nth {
            taken.append(contentsOf: Array(repeating: row, count: stands.nth + 1 - taken.count))
        }

        taken[stands.nth] = row
        documents[context.slots.origin].closureRows = taken

        return .closure(stands.number, captures: inner.captures)
    }

    // A position the build found handed in place keeps the place its path
    // names, and every other argument is read as a value.
    private mutating func lower(
        apply callee: Expression,
        arguments: [Expression],
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        guard case let .apply(handed, declared)? = context.judgements[place] else {
            throw BuildError.unjudged("a call of a value the build did not judge", at: place)
        }

        return .apply(
            try lower(callee, naming: nil, in: scope, on: context, at: place.child(.callee)),
            arguments: try arguments.enumerated().map { position, argument in
                let here = place.child(.argument(position))

                guard handed.contains(position) else {
                    return .value(try lower(argument, naming: nil, in: scope, on: context, at: here))
                }

                guard case let .reference(path) = argument else {
                    throw BuildError.unjudged("a call of a value handing in place what is no path", at: here)
                }

                return .reference(try lower(reference: path, in: scope, on: context, at: here))
            },
            declared: declared
        )
    }

    private mutating func lower(
        cast value: Expression,
        as type: TypeExpression,
        optional: Bool,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        let lowered = type.lowered(in: loweredTypes)

        return .cast(
            try lower(value, naming: nil, in: scope, on: context, at: place.child(.subject(optional: optional))),
            as: lowered,
            optional: optional
        )
    }

    private mutating func lower(
        conditional condition: Expression,
        then: Body,
        else otherwise: Body?,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        var thenScope = scope
        var elseScope = scope

        return .conditional(
            try lower(condition, naming: nil, in: scope, on: context, at: place.child(.condition(of: .conditional))),
            then: try lower(then, in: &thenScope, on: context, at: place.child(.then)),
            else: try otherwise.map { otherwise in
                try lower(otherwise, in: &elseScope, on: context, at: place.child(.otherwise))
            }
        )
    }

    private mutating func lower(
        loop condition: Expression,
        body: Body,
        round: Name?,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        var inner = scope
        let slot = round.map { round in context.slots.allocate(round) }

        if let round, let slot {
            inner.slots[round] = slot
        }

        let taking = try lower(condition, naming: nil, in: inner, on: context, at: place.child(.condition(of: .loop)))
        let instructions = try lower(body, in: &inner, on: context, at: place.child(.round))

        return .loop(while: taking, body: instructions, round: slot)
    }

    private mutating func lower(
        attempt block: Block,
        rescue: Block,
        failure: Name?,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        let attempted = try lower(block, in: scope, on: context, at: place.child(.held))
        var inner = scope
        let slot = failure.map { failure in context.slots.allocate(failure) }

        if let failure, let slot {
            inner.slots[failure] = slot
        }

        return .attempt(
            attempted,
            rescue: try lower(rescue, in: inner, on: context, at: place.child(.rescue)),
            failure: slot
        )
    }

    private mutating func lower(
        leave: Leave,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Operation {
        return .leave(
            leave.reach,
            target: leave.target,
            try leave.value.map { value in
                try lower(value, naming: nil, in: scope, on: context, at: place.child(.held))
            }
        )
    }

    private mutating func lower(
        _ call: Call,
        through asked: LoweredContractProcedure,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> DispatchOperation {
        guard let written = call.arguments.first else {
            throw BuildError.unjudged("a call to '\(call.selector)' with nothing at its first position", at: place)
        }

        guard call.arguments.count == asked.signature.parameters.count else {
            throw BuildError.unjudged("a call to '\(call.selector)' with another count than it asks", at: place)
        }

        // The first is read here, once, and the run hands what it read to
        // whichever row it picked.
        return DispatchOperation(
            contract: asked.contract,
            procedure: asked.procedure,
            first: try lower(written, naming: nil, in: scope, on: context, at: place.child(.argument(0))),
            arguments: try call.arguments.enumerated().dropFirst().map { position, written in
                try argument(written, in: scope, on: context, at: place.child(.argument(position)))
            }
        )
    }

    // One argument, kept as the place it names where it names one: a slot
    // taking it in place takes the caller's hold, and which slots do is the
    // callee's to say.
    private mutating func argument(
        _ expression: Expression,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Argument {
        guard case let .reference(path) = expression else {
            return .value(try lower(expression, naming: nil, in: scope, on: context, at: place))
        }

        return .reference(try lower(reference: path, in: scope, on: context, at: place))
    }

    private mutating func lower(
        _ call: Call,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> CallOperation {
        guard let stands = documents[context.slots.origin].numbering.call(call.selector) else {
            throw BuildError.unjudged("a call to '\(call.selector)', which the document never asked for", at: place)
        }

        // The document's own declaration by its block, another document's by
        // its spelling.
        guard let row = reached(stands, on: context.slots) else {
            throw BuildError.unjudged("a call to '\(call.selector)', which has no row", at: place)
        }

        let callee = table[row]
        let argumentPlaces = call.arguments.indices.map { position in place.child(.argument(position)) }

        return try CallOperation(
            handing: try zip(call.arguments, argumentPlaces).map { written, at in
                try argument(written, in: scope, on: context, at: at)
            },
            to: callee,
            row: stands,
            in: loweredTypes,
            at: place
        )
    }

    // The path a reference at this place reads, as the build placed it.
    private func lower(
        reference path: Path,
        in scope: SlotScope,
        on context: Context,
        at place: Place
    ) throws -> Address {
        guard case let .reference(placed)? = context.judgements[place] else {
            throw BuildError.unjudged("a path '\(path.rendered)' the build did not place", at: place)
        }

        return try lower(placed, in: scope, on: context.slots, at: place)
    }

    private func lower(
        _ path: LoweredPath,
        in scope: SlotScope,
        on slots: SlotAllocator,
        at place: Place
    ) throws -> Address {
        guard let head = path.head else {
            throw BuildError.unjudged("a path '\(path.path.rendered)' with no name at its head", at: place)
        }

        guard let slot = slots.slot(of: head, in: scope) else {
            throw BuildError.unjudged("a name '\(head)' in '\(path.path.rendered)' that nothing declares", at: place)
        }

        let steps = try path.segments.dropFirst().map { segment -> Step in
            switch segment {
            case let .field(position, name, optional):
                return .field(position, name, optional: optional)

            case let .name(name, optional):
                return .name(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .at(inner, optional):
                return .at(try lower(inner, in: scope, on: slots, at: place), optional: optional)
            }
        }

        return Address(slot: slot, steps: steps)
    }

    // Which row of the link a number in a lowered body stands for. The body
    // carries its document's numbering, and this walk reads what it just
    // wrote.
    private func reached(_ number: Int, on slots: SlotAllocator) -> Int? {
        guard case let .row(row) = documents[slots.origin].numbering.row(
            number,
            rows: rows,
            own: own(slots.origin),
            closures: documents[slots.origin].closureRows
        ) else {
            return nil
        }

        return row
    }

    // One type written as the numbers its document gave the rows it stands
    // on. A row the document never numbered is the build having lowered
    // something it did not read, which is this pass's own mistake.
    private func renumbered(
        _ type: LoweredType,
        in place: [Int: Int],
        of label: Name
    ) throws -> LoweredType {
        try type.replacingRows { number in
            guard let stands = place[number] else {
                throw BuildError.unjudged(
                    "type '\(loweredTypes.labels[number])', which its document never numbered",
                    at: Place.procedure(label.spelling, in: .assembled)
                )
            }

            return .named(stands)
        }
    }

    // Where each of a link's rows stands in the document's numbering, read
    // off the names once rather than at every type the walk meets.
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
