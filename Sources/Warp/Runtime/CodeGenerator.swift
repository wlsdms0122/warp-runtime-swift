//
//  CodeGenerator.swift
//  Warp
//
//  Created by JSilver on 11/14/26.
//

import Foundation

// Compiles lowered code into the closures a run calls: one per statement and
// one per operation that is more than a literal or a slot, each holding the
// code of what nests in it. What the build wrote into the code (a slot, a
// row, a layout, a type naming no type parameter, where a statement stands)
// is read here once. What only a run can know (a value, the type a value
// holds, the closure a value is) is read where the run reaches it.
//
// A fact that fails here, a number no row stands for, is compiled into code
// that refuses where the run reaches it, so what a run refuses, and in which
// order, is what reading the code there would refuse.
struct CodeGenerator: Sendable {
    // MARK: - Property
    // Unowned, since the table holds the code compiled here.
    unowned let table: CodeTable

    // The document the code came from, whose numbers it carries.
    let origin: Int

    // What each slot of the frame the code runs in was called.
    let names: [Name]

    // What fills the type parameters of the body, where it is compiled for
    // the types a call filled them with, and nil where it is compiled for
    // every call. A type the body names is then read here, once, rather
    // than where the run reaches it.
    private let filled: [Name: LoweredType]?

    // The round slots of the loops in this body that nothing reads but as
    // the round's index. Such a slot holds the index itself, so a round
    // makes no value and a read of its index walks no field.
    private let indexed: Set<Int>

    // The variables this body declares that its slots hold unboxed: no
    // closure takes them with it and no argument hands them in place, so
    // nothing but this frame reaches them, one statement at a time.
    private let unboxed: Set<Int>

    // The unboxed variables no `try` body writes. A statement writing one
    // that fails takes the frame with it, so nothing reads what the variable
    // held, and the statement's read of it may move the value out.
    private let movable: Set<Int>

    // The variable the statement being made reads for the last time before
    // it writes it, where there is one.
    private var moving: Int?

    // The layout of the value a loop binds each round to, made once, and
    // where the index stands in it.
    private static let roundLayout = Struct(name: TypeSpelling.round, [Prelude.index: .int(0)]).layout
    private static let indexPosition = roundLayout.position(of: Prelude.index)

    // MARK: - Initializer
    init(table: CodeTable, origin: Int, names: [Name], filled: [Name: LoweredType]? = nil) {
        self.init(table: table, origin: origin, names: names, filled: filled, indexed: [], unboxed: [], movable: [])
    }

    private init(
        table: CodeTable,
        origin: Int,
        names: [Name],
        filled: [Name: LoweredType]?,
        indexed: Set<Int>,
        unboxed: Set<Int>,
        movable: Set<Int>
    ) {
        self.table = table
        self.origin = origin
        self.names = names
        self.filled = filled
        self.indexed = indexed
        self.unboxed = unboxed
        self.movable = movable
    }

    // MARK: - Public
    // A written body, its statements standing under `place` in its document.
    func body(_ body: LoweredBody, in frame: Frame, standing place: Place?) -> CompiledBody {
        let unboxed = Self.unboxed(body)
        let generator = CodeGenerator(
            table: table,
            origin: origin,
            names: names,
            filled: filled,
            indexed: Self.indexed(body),
            unboxed: unboxed,
            movable: Self.movable(body, among: unboxed)
        )

        return CompiledBody(
            block: generator.block(body.instructions, under: place, in: nil, round: nil, depth: 0, returning: true),
            frame: frame
        )
    }

    // One operation outside any statement: what a fold reads.
    func code(_ operation: Operation) -> CompiledCode {
        code(operation, at: nil, depth: 0)
    }

    // MARK: - Private
    // A type the body names, as the run reads it, where that is known here:
    // the body is compiled for what fills its type parameters, or the type
    // names none. Nil where only the run knows.
    private func reading(_ type: LoweredType) -> LoweredType? {
        if let filled { return Activation.reading(type, filledBy: filled, in: table.loweredTypes) }

        return type.namesParameter ? nil : type
    }

    // Every type, where each is known here.
    private static func all(_ types: [LoweredType?]) -> [LoweredType]? {
        let known = types.compactMap { type in type }

        return known.count == types.count ? known : nil
    }

    // Instructions in order, each landing its value in the slot it binds.
    // `list` is where the list stands in its document, each instruction at
    // its position in it, and nil where its document has no identity. A
    // list that is a loop's body runs a round of the loop at `round`, among
    // the loops `depth` counts around it in this frame. A body's own list
    // `returning` gives what a `return` standing last in it carries as its
    // value rather than throwing it, since nothing between that statement
    // and the body's edge would take it.
    private func block(
        _ instructions: [Instruction],
        under list: Place?,
        in parent: Site?,
        round: Int?,
        depth: Int,
        returning: Bool = false
    ) -> CompiledBlock {
        CompiledBlock(
            instructions.enumerated().map { position, instruction in
                // A statement is called by the name it was written with, or
                // by its position where it names nothing, and stands at its
                // position in the list holding it.
                let name = instruction.naming.map { slot in names[slot].spelling }
                let site = Site(
                    parent: parent,
                    hop: .statement(name ?? "[\(position)]"),
                    place: list.map { list in list.statement(name, at: position) },
                    round: round
                )

                guard
                    returning,
                    position == instructions.count - 1,
                    case nil = instruction.binding,
                    case let .leave(.procedure(returned)) = instruction.code
                else {
                    return statement(instruction, at: site, depth: depth)
                }

                return self.returning(returned, at: site, depth: depth)
            }
        )
    }

    // One statement and where its value lands.
    private func statement(_ instruction: Instruction, at site: Site, depth: Int) -> CompiledStatement {
        let code = moving(instruction).code(instruction.code, at: site, depth: depth)

        switch instruction.binding {
        case let .bind(slot)?:
            return CompiledStatement(code, at: site, landing: .bind(slot))

        case let .declare(slot)?:
            return CompiledStatement(code, at: site, landing: unboxed.contains(slot) ? .bind(slot) : .declare(slot, names[slot]))

        case let .assign(address)?:
            return CompiledStatement(code, at: site, landing: unboxed.contains(address.slot) ? .store(address) : .assign(address))

        case nil:
            return CompiledStatement(code, at: site, landing: .drop)
        }
    }

    // What makes a statement's code: one that moves the variable the
    // statement writes out of its slot, where the statement calls with it,
    // whole, at a slot holding a collection or a declared type, and reads it
    // nowhere else. A value of any other type is copied for nothing.
    private func moving(_ instruction: Instruction) -> CodeGenerator {
        guard
            case let .assign(address)? = instruction.binding,
            address.steps.isEmpty,
            movable.contains(address.slot),
            case let .call(call) = instruction.code,
            let row = try? table.row(call.placed.procedure, from: origin),
            table.linked.indices.contains(row),
            let position = call.placed.arguments.firstIndex(where: { argument in
                guard case let .local(read)? = argument else { return false }

                return read.slot == address.slot
            }),
            table.linked[row].slots.indices.contains(position),
            Self.holdsStorage(table.linked[row].slots[position].type),
            Self.readsOnce(address.slot, in: instruction.code)
        else { return self }

        var generator = self
        generator.moving = address.slot

        return generator
    }

    // Where a call reads the variable this statement moves, and its slot.
    private func moving(in call: PlacedCall) -> (position: Int, slot: Int)? {
        guard
            let moving,
            let position = call.arguments.firstIndex(where: { argument in
                guard case let .local(read)? = argument else { return false }

                return read.slot == moving
            })
        else { return nil }

        return (position: position, slot: moving)
    }

    // A `return` standing last in a body, which answers what it carries.
    private func returning(_ returned: Operation?, at site: Site, depth: Int) -> CompiledStatement {
        CompiledStatement(
            returned.map { returned in code(returned, at: site, depth: depth) } ?? .synchronous(.literal(.null)),
            at: site,
            landing: .answer
        )
    }

    // Every operation a body carries.
    private func code(_ operation: Operation, at site: Site?, depth: Int) -> CompiledCode {
        switch operation {
        case let .literal(value):
            return .synchronous(.literal(value))

        case let .local(address):
            return read(address)

        case let .closure(number, captures):
            return closure(number, captures: captures)

        case let .array(elements):
            let elements = elements.map { element in code(element, at: site, depth: depth) }

            return .running { activation, evaluator in
                var values: [Value] = []
                values.reserveCapacity(elements.count)

                for element in elements {
                    values.append(try await element.run(&activation, evaluator))
                }

                return .array(values)
            }

        case let .struct(held):
            let layout = held.layout
            let fields = held.fields.map { field in code(field, at: site, depth: depth) }

            return .running { activation, evaluator in
                var values: [Value] = []
                values.reserveCapacity(fields.count)

                for field in fields {
                    values.append(try await field.run(&activation, evaluator))
                }

                return .struct(Struct(layout: layout, values: values))
            }

        // Each entry is made in the order written, the key before its value,
        // so a key written twice holds the later value.
        case let .dictionary(entries):
            let entries = entries.map { entry in
                (key: code(entry.key, at: site, depth: depth), value: code(entry.value, at: site, depth: depth))
            }

            return .running { activation, evaluator in
                var held = Value.Dictionary([:])

                for entry in entries {
                    let key = try await entry.key.run(&activation, evaluator)

                    held = try held.writing(key: key, with: try await entry.value.run(&activation, evaluator))
                }

                return .dictionary(held)
            }

        // The run's whole share of a cast: the build already decided what every
        // dot after this means, and the one thing it could not know is what
        // actually arrived, judged against the type with the body's type
        // parameters read as what fills them here. A plain cast lets a
        // mismatch out as `cast_refused`, a failure like any other; an
        // optional one reads it as null, which is the author saying they
        // expected it.
        case let .cast(value, type, optional):
            let value = code(value, at: site, depth: depth)
            let loweredTypes = table.loweredTypes

            if let type = reading(type) {
                return .running { activation, evaluator in
                    try type.reading(await value.run(&activation, evaluator), optional: optional, in: loweredTypes)
                }
            }

            return .running { activation, evaluator in
                let read = activation.reading(type)

                return try read.reading(await value.run(&activation, evaluator), optional: optional, in: loweredTypes)
            }

        case let .coerced(value, coercion):
            let value = code(value, at: site, depth: depth)
            let loweredTypes = table.loweredTypes

            return .running { activation, evaluator in
                let read = try await value.run(&activation, evaluator)

                return coercion.applied(to: read, filling: { type in activation.reading(type) }, in: loweredTypes)
            }

        case let .call(call):
            return self.call(call, at: site, depth: depth)

        case let .dispatch(dispatch):
            return self.dispatch(dispatch, at: site, depth: depth)

        case let .apply(callee, arguments):
            return apply(callee, arguments: arguments, at: site, depth: depth)

        // A conditional has no value: the condition chooses a way through the
        // body, and what an arm keeps it writes to an outer variable.
        case let .conditional(condition, then, otherwise):
            let condition = code(condition, at: site, depth: depth)
            let then = block(then, under: Self.list(of: .conditional, .then, at: site), in: site, round: nil, depth: depth)
            let otherwise = otherwise.map { otherwise in
                block(otherwise, under: Self.list(of: .conditional, .otherwise, at: site), in: site, round: nil, depth: depth)
            }

            return .running { activation, evaluator in
                if try Evaluator.bool(try await condition.run(&activation, evaluator)) {
                    try await then.run(&activation, evaluator)
                } else if let otherwise {
                    try await otherwise.run(&activation, evaluator)
                }

                return .null
            }

        case let .loop(condition, body, round):
            return loop(while: condition, body: body, round: round, at: site, depth: depth)

        // A try has no value: what either way keeps it writes to an
        // outer variable.
        case let .try(body, `catch`, failure):
            return `try`(body, catch: `catch`, failure: failure, at: site, depth: depth)

        // An unwrap with a `then` has no value: `then` reads the payload
        // under the statement's name. With no `then` it gives the payload for
        // the statement to bind, since its `else` leaves.
        case let .unwrap(read, then, otherwise, payload):
            let read = code(read, at: site, depth: depth)
            let then = then.map { then in
                block(then, under: Self.list(of: .unwrap, .then, at: site), in: site, round: nil, depth: depth)
            }
            let otherwise = otherwise.map { otherwise in
                block(otherwise, under: Self.list(of: .unwrap, .otherwise, at: site), in: site, round: nil, depth: depth)
            }

            return .running { activation, evaluator in
                guard let held = try await read.run(&activation, evaluator).payload else {
                    if let otherwise {
                        try await otherwise.run(&activation, evaluator)
                    }

                    return .null
                }

                guard let then else { return held }

                if let payload {
                    activation.cells[payload] = .value(held)
                }

                try await then.run(&activation, evaluator)

                return .null
            }

        case let .switch(held):
            return `switch`(held, at: site, depth: depth)

        // Nothing comes back, so this has no value. What it carries
        // is worked out here, where the names it reads are still in scope.
        case let .leave(.procedure(returned)):
            let returned = returned.map { returned in code(returned, at: site, depth: depth) }

            return .running { activation, evaluator in
                var carried = Value.null

                if let returned {
                    carried = try await returned.run(&activation, evaluator)
                }

                throw Leaving.procedure(carried)
            }

        case let .leave(.loop(target)):
            return .running { _, _ in throw Leaving.loop(target) }

        case let .leave(.round(target)):
            return .running { _, _ in throw Leaving.round(target) }
        }
    }

    // A slot path read, where the code holding it runs. A slot read whole is
    // read from the cell, and so is the index of a round whose slot holds it.
    private func read(_ address: Address) -> CompiledCode {
        let slot = address.slot

        if !address.promoted, address.steps.isEmpty || indexed.contains(slot) {
            return .synchronous(.slot(slot))
        }

        return .synchronous(.path(CompiledPath(address)))
    }

    // Making a closure runs nothing: it is the capture, and the capture is
    // these cells and the types this body holds. Which row it stands on and
    // how it is spelled the code says, so both are read here.
    private func closure(_ number: Int, captures: [(Int, Int)]) -> CompiledCode {
        let row: Int

        do {
            row = try table.row(number, from: origin)
        } catch {
            return Self.refusing(error)
        }

        guard table.linked.indices.contains(row) else { return Self.trapping(row, in: table.linked) }

        let linked = table.linked[row]

        guard let written = linked.closure else {
            return Self.refusing(RunRefused("a closure stands on a row no declaration wrote"))
        }

        guard table.naming.indices.contains(linked.origin) else {
            return Self.refusing(RunRefused("a closure stands in a document this run was not told of"))
        }

        let writer = Closure.Writer(document: table.naming[linked.origin], declaration: written.by)
        let nth = written.nth

        return .running { activation, _ in
            .procedure(
                Closure(
                    writer: writer,
                    nth: nth,
                    resolution: .resolved(linked, types: activation.types),
                    captured: captures.map { outer, inner in (slot: inner, cell: activation.cells[outer]) }
                )
            )
        }
    }

    // One lookup, because there is one table. What happens is decided by how
    // the row is implemented, not by which container it was found in.
    // What fills the callee's type parameters is what the call hands, read in
    // the caller's body: once here where no type the call hands names a type
    // parameter of the body.
    private func call(_ call: CallOperation, at site: Site?, depth: Int) -> CompiledCode {
        let row: Int

        do {
            row = try table.row(call.placed.procedure, from: origin)
        } catch {
            return Self.refusing(error)
        }

        guard table.linked.indices.contains(row) else { return Self.trapping(row, in: table.linked) }

        let parameters = table.linked[row].typeParameters
        let handed = call.types

        if let read = Self.all(handed.map(reading)) {
            let types = Dictionary(zip(parameters, read), uniquingKeysWith: { first, _ in first })

            return placed(call.placed, reaching: row, at: site, depth: depth, filled: types)
        }

        let placed: CompiledCall = placed(call.placed, reaching: row, at: site, depth: depth)

        return .running { activation, evaluator in
            let types = Dictionary(
                zip(parameters, handed.map { type in activation.reading(type) }),
                uniquingKeysWith: { first, _ in first }
            )

            return try await placed.run(&activation, evaluator, nil, types)
        }
    }

    // A call through a contract. Which row it reaches, and what fills the
    // row's type parameters, the name of the type that fills `Self` decides:
    // the link gathered every type whose member satisfies this procedure and
    // lowered a call for each, so nothing is resolved at the run. Where no
    // position names a type parameter of the body and the first names a
    // type the link laid a call out for, the row is chosen here, once.
    // Otherwise the run chooses: a reading of a contract is read as the type
    // the value standing first holds, and a value holding none, as one a door
    // handed at a bounded parameter it left standing, is read as the type it
    // is an instance of, a value of an enum as the enum and not its case.
    private func dispatch(_ dispatch: DispatchOperation, at site: Site?, depth: Int) -> CompiledCode {
        let spelling = dispatch.procedure.spelled(under: dispatch.contract)
        let loweredTypes = table.loweredTypes
        let known = Self.all(dispatch.types.map(reading))

        if
            let positions = known,
            let name = positions.first?.nominal(in: loweredTypes),
            let call = dispatch.calls[name]
        {
            let row: Int

            do {
                row = try table.row(call.procedure, from: origin)
            } catch {
                return Self.refusing(error)
            }

            guard table.linked.indices.contains(row) else { return Self.trapping(row, in: table.linked) }

            return placed(call, reaching: row, at: site, depth: depth, filled: table.types(of: table.linked[row], reading: positions))
        }

        let calls = dispatch.calls.mapValues { call in compiled(call, at: site, depth: depth) }
        let first = code(dispatch.first.read, at: site, depth: depth)

        return .running { [self] activation, evaluator in
            var positions = known ?? dispatch.types.map { type in activation.reading(type) }
            let name: Name
            var read: Value?

            if let named = positions[0].nominal(in: loweredTypes) {
                name = named
            } else {
                let standing = try await first.run(&activation, evaluator)

                read = standing

                if
                    case let .existential(existential) = standing,
                    case let held = try existential.resolved(),
                    let named = held.nominal(in: loweredTypes)
                {
                    positions[0] = held
                    name = named
                } else {
                    positions[0] = LoweredType(of: standing, in: loweredTypes)
                    name = positions[0].nominal(in: loweredTypes) ?? standing.nominal
                }
            }

            let chosen: (callee: Linked?, call: CompiledCall)

            if let laid = calls[name] {
                chosen = laid
            } else if dispatch.calls.isEmpty, let row = table.witnesses[spelling]?[name] {
                chosen = witnessed(dispatch, reaching: row, at: site, depth: depth)
            } else {
                throw Self.unsatisfied(dispatch, spelling: spelling, name: name)
            }

            guard let callee = chosen.callee else {
                return try await chosen.call.run(&activation, evaluator, read, [:])
            }

            let returned = try await chosen.call.run(
                &activation,
                evaluator,
                read,
                table.types(of: callee, reading: positions)
            )

            guard case let .existential(existential)? = read else { return returned }

            return try table.held(returned, through: dispatch, as: spelling, picked: try existential.resolved(), in: activation)
        }
    }

    // A call the link laid out, against the row its number stands for, or
    // the refusal of a number standing for none.
    private func compiled(_ call: PlacedCall, at site: Site?, depth: Int) -> (callee: Linked?, call: CompiledCall) {
        let row: Int

        do {
            row = try table.row(call.procedure, from: origin)
        } catch {
            return (nil, Self.refusing(error))
        }

        guard table.linked.indices.contains(row) else { return (nil, Self.trapping(row, in: table.linked)) }

        return (table.linked[row], placed(call, reaching: row, at: site, depth: depth))
    }

    // Where the link has laid out no call, the row a claim within the
    // folding document's reach names, the call placed against it the way the
    // link would place it.
    private func witnessed(
        _ dispatch: DispatchOperation,
        reaching row: Int,
        at site: Site?,
        depth: Int
    ) -> (callee: Linked?, call: CompiledCall) {
        let callee = table.linked[row]

        do {
            let call = try dispatch.call(
                of: callee,
                at: row,
                in: table.loweredTypes,
                at: .procedure(callee.rendered, in: .assembled)
            )

            return (callee, placed(call, reaching: row, at: site, depth: depth))
        } catch {
            return (nil, Self.refusing(error))
        }
    }

    // A call placed against a row of the table, its arguments read in the
    // statement standing at `site`, and what fills the callee's type
    // parameters known here. A query and a body the call opens nothing for
    // are called straight from the code; any other goes through the call the
    // run would pick.
    private func placed(
        _ call: PlacedCall,
        reaching row: Int,
        at site: Site?,
        depth: Int,
        filled types: [Name: LoweredType]
    ) -> CompiledCode {
        guard table.linked.indices.contains(row) else { return Self.trapping(row, in: table.linked) }

        let callee = table.linked[row]
        let arguments = call.arguments.map { argument in argument.map { argument in code(argument, at: site, depth: depth) } }

        switch callee.implementation {
        case let .native(.query(query), _) where call.handed.isEmpty && !Self.opens(callee, filled: types):
            let returns = callee.returns(filled: types)

            if let computation = query as? any Computation {
                if let synchronous = Self.synchronous(arguments) {
                    let compiled = SynchronousComputation(computation, arguments: synchronous, returning: returns)

                    // A call handing over a moved value stands as a statement's
                    // code, apart from the code every other call reads through.
                    if let moving = moving(in: call) {
                        return .running { activation, evaluator in
                            try compiled.handing(&activation, evaluator, moving: moving)
                        }
                    }

                    return .synchronous(.computing(compiled))
                }

                return .computing(CompiledComputation(computation, arguments: arguments, returning: returns))
            }

            return .running { activation, evaluator in
                let values = try await Self.given(arguments, first: nil, in: &activation, by: evaluator)
                let returned = try await evaluator.evaluate(
                    query,
                    of: callee,
                    arguments: ArgumentList(values: values),
                    returning: returns,
                    at: activation.location(at: site)
                )

                activation.handBack(values)

                return returned
            }

        case let .body(lowered, frame) where !Self.opens(callee, filled: types) && arguments.count <= frame.parameters.count:
            let routine = table.routine(row: row, filled: types)
            let given = Self.given(arguments, into: frame.parameters)
            let handed = call.handed

            return .running { activation, evaluator in
                try await Self.entered(
                    routine,
                    running: lowered,
                    in: frame,
                    given: given,
                    handed: handed,
                    at: site,
                    first: nil,
                    types: types,
                    in: &activation,
                    by: evaluator
                )
            }

        default:
            let placed: CompiledCall = placed(call, reaching: row, at: site, depth: depth)

            return .running { activation, evaluator in
                try await placed.run(&activation, evaluator, nil, types)
            }
        }
    }

    // A call placed against a row of the table, its arguments read in the
    // statement standing at `site`, handed what was read first and what
    // fills the callee's type parameters where it runs.
    private func placed(_ call: PlacedCall, reaching row: Int, at site: Site?, depth: Int) -> CompiledCall {
        guard table.linked.indices.contains(row) else { return Self.trapping(row, in: table.linked) }

        let callee = table.linked[row]
        let arguments = call.arguments.map { argument in argument.map { argument in code(argument, at: site, depth: depth) } }
        let handed = call.handed
        let opens = Self.opens(callee)

        switch callee.implementation {
        case let .native(.query(query), _):
            return CompiledCall { activation, evaluator, first, filled in
                var types = filled
                var values = try await Self.given(arguments, first: first, in: &activation, by: evaluator)

                // A variable handed in place is read as what it holds now,
                // since nothing here writes it.
                if !handed.isEmpty {
                    for (position, handle) in try Evaluator.holds(handed, of: callee, first: first, in: activation) {
                        values[position] = try handle.value()
                    }
                }

                let opened = opens ? try Evaluator.opening(&values, filling: &types, of: callee) : false
                let returned = try await evaluator.evaluate(
                    query,
                    of: callee,
                    arguments: ArgumentList(values: values),
                    returning: callee.returns(filled: types),
                    at: activation.location(at: site)
                )

                activation.handBack(values)

                guard opened else { return returned }

                return evaluator.table.held(returned, returning: callee.returns, handed: filled, ran: types)
            }

        case let .native(.effect(effect), _):
            return CompiledCall { activation, evaluator, first, filled in
                var types = filled
                let holds = try Evaluator.holds(handed, of: callee, first: first, in: activation)
                var values = try await Self.given(arguments, first: first, in: &activation, by: evaluator)
                let opened = opens ? try Evaluator.opening(&values, filling: &types, of: callee) : false
                let returned = try await evaluator.run(
                    effect,
                    of: callee,
                    arguments: ArgumentList(values: values),
                    holds: holds,
                    returning: callee.returns(filled: types),
                    at: activation.location(at: site)
                )

                activation.handBack(values)

                guard opened else { return returned }

                return evaluator.table.held(returned, returning: callee.returns, handed: filled, ran: types)
            }

        case let .body(lowered, frame):
            let routine = table.routine(row: row)

            guard opens || arguments.count > frame.parameters.count else {
                let given = Self.given(arguments, into: frame.parameters)

                return CompiledCall { activation, evaluator, first, types in
                    try await Self.entered(
                        routine,
                        running: lowered,
                        in: frame,
                        given: given,
                        handed: handed,
                        at: site,
                        first: first,
                        types: types,
                        in: &activation,
                        by: evaluator
                    )
                }
            }

            return CompiledCall { activation, evaluator, first, filled in
                var types = filled
                let holds = try Evaluator.holds(handed, of: callee, first: first, in: activation)
                var values = try await Self.given(arguments, first: first, in: &activation, by: evaluator)
                let opened = try Evaluator.opening(&values, filling: &types, of: callee)
                let returned = try await evaluator.invoke(
                    routine,
                    running: routine.body(lowered, in: frame),
                    given: values,
                    holding: holds,
                    types: types,
                    from: activation.location(at: site),
                    entering: routine.hop
                )

                guard opened else { return returned }

                return evaluator.table.held(returned, returning: callee.returns, handed: filled, ran: types)
            }
        }
    }

    // Calling a value. The body runs in the cells the closure captured and not
    // in the caller's: that is what lexical scope means, and it is the reason a
    // closure is worth passing at all.
    //
    // A place the build found handed in place is the caller's hold where the
    // closure's slot takes one, made before any argument is read the way a
    // call to a declaration makes its holds, and is read as a value where the
    // slot takes a value. The arguments are handed in as they were read: the
    // build held each to the parameter the slot's procedure type writes, and
    // held whatever fills the slot to take each of those parameters.
    private func apply(_ callee: Operation, arguments: [Argument], at site: Site?, depth: Int) -> CompiledCode {
        let callee = code(callee, at: site, depth: depth)
        let compiled = arguments.map { argument -> (value: CompiledCode?, reference: Address?) in
            switch argument {
            case let .value(operation):
                return (code(operation, at: site, depth: depth), nil)

            case let .reference(address):
                return (nil, address)
            }
        }

        return .running { activation, evaluator in
            let value = try await callee.run(&activation, evaluator)

            guard case let .procedure(closure) = value else {
                throw RunRefused(
                    "this call names \(value.nominal), and only a procedure can be called"
                )
            }

            let (linked, types) = try evaluator.table.row(of: closure)

            try linked.refuseCount(arguments.count)

            let handed = arguments.enumerated().compactMap { position, argument -> PlacedCall.Handed? in
                guard
                    case let .reference(address) = argument,
                    linked.slots.indices.contains(position),
                    linked.slots[position].type.isInout
                else { return nil }

                return PlacedCall.Handed(position: position, address: address)
            }
            let holds = try Evaluator.holds(handed, of: linked, first: nil, in: activation)

            // A value carries no names, so the arguments travel by position, in
            // the order they were written, and land in the slots in that order.
            var given: [Value?] = []

            for (position, argument) in compiled.enumerated() {
                if let value = argument.value {
                    given.append(try await value.run(&activation, evaluator))
                } else if let address = argument.reference {
                    given.append(
                        handed.contains { held in held.position == position } ? nil : try activation.value(at: address)
                    )
                }
            }

            return try await evaluator.invoke(
                closure,
                as: linked,
                reading: types,
                given: given,
                holding: holds,
                from: activation.location(at: site)
            )
        }
    }

    // A loop at `depth` among the loops around it in this frame: its body
    // runs each round one deeper, and the round it is on stands at its depth.
    private func loop(while condition: Operation, body: [Instruction], round: Int?, at site: Site?, depth: Int) -> CompiledCode {
        let condition = code(condition, at: site, depth: depth)
        let body = block(body, under: Self.list(of: .loop, .body, at: site), in: site, round: depth, depth: depth + 1)
        let name = round.map { round in names[round] }
        let holdsIndex = round.map { round in indexed.contains(round) } ?? false
        let layout = Self.roundLayout

        return .running { activation, evaluator in
            var index = 0

            while true {
                // Every round observes cancellation, an empty one too, or the
                // host's lever against a loop that does not end stops working.
                try Task.checkCancellation()

                // The condition reads the state before the round it would start.
                if let round {
                    activation.cells[round] = .value(
                        holdsIndex ? .int(index) : .struct(Struct(layout: layout, values: [.int(index)]))
                    )
                }

                guard try Evaluator.bool(try await condition.run(&activation, evaluator)) else { return .null }

                if activation.rounds.count > depth {
                    activation.rounds[depth] = index
                } else {
                    activation.rounds.append(index)
                }

                do {
                    try await body.run(&activation, evaluator)
                } catch let leaving as Leaving where leaving.claimed(by: name) {
                    guard case .round = leaving else { return .null }
                }

                index += 1
            }
        }
    }

    private func `try`(_ body: [Instruction], catch: [Instruction], failure: Int?, at site: Site?, depth: Int) -> CompiledCode {
        let body = block(body, under: Self.list(of: .try, .body, at: site), in: site, round: nil, depth: depth)
        let `catch` = block(`catch`, under: Self.list(of: .try, .catch, at: site), in: site, round: nil, depth: depth)
        let named = failure.map { failure in (slot: failure, name: names[failure]) }

        return .running { activation, evaluator in
            do {
                try await body.run(&activation, evaluator)
            } catch {
                guard !Task.isCancelled else { throw error }

                // An author mistake passes through: a catch is for what the world
                // did, not for what the procedure says.
                guard let recoverable = error as? any RecoverableFailure else { throw error }

                // While the catch runs, the failure is a value under the declared
                // name, where the try bound one. What a failure carries is the
                // failing procedure's, a value from outside, so the payload comes
                // in through the door at the envelope's type.
                if let named {
                    let loweredTypes = evaluator.loweredTypes

                    activation.cells[named.slot] = .value(
                        try loweredTypes.prelude(TypeSpelling.failure).settling(
                            outside: recoverable.payload,
                            at: "'\(named.name)'",
                            in: loweredTypes
                        )
                    )
                }

                await evaluator.observer?.failureCaught(name: named?.name.spelling, error: error)

                try await `catch`.run(&activation, evaluator)
            }

            return .null
        }
    }

    // A switch has no value: the case `of` holds chooses an arm, which
    // reads the fields it binds under their names. The build proved every
    // case has a way through, so a value no arm names and no `default`
    // takes runs nothing.
    private func `switch`(_ held: SwitchOperation, at site: Site?, depth: Int) -> CompiledCode {
        let subject = code(held.subject, at: site, depth: depth)
        let enumeration = held.enumeration
        let arms = Dictionary(
            held.arms.map { arm in
                (
                    arm.name.spelled(under: enumeration),
                    (
                        binds: arm.binds,
                        then: block(arm.then, under: Self.list(of: .switch, .arm(arm.name), at: site), in: site, round: nil, depth: depth)
                    )
                )
            },
            uniquingKeysWith: { one, _ in one }
        )
        let otherwise = held.default.map { otherwise in
            block(otherwise, under: Self.list(of: .switch, .default, at: site), in: site, round: nil, depth: depth)
        }

        return .running { activation, evaluator in
            guard case let .struct(instance) = try await subject.run(&activation, evaluator) else {
                throw RunRefused(
                    "a switch takes apart a value that is no value of '\(enumeration)'",
                    trace: activation.trace(at: site)
                )
            }

            guard let arm = arms[instance.name] else {
                if let otherwise {
                    try await otherwise.run(&activation, evaluator)
                }

                return .null
            }

            for (field, slot) in arm.binds {
                guard let value = instance[field] else {
                    throw RunRefused(
                        "a value of '\(instance.name)' carries no field '\(field)'",
                        trace: activation.trace(at: site)
                    )
                }

                activation.cells[slot] = .value(value)
            }

            try await arm.then.run(&activation, evaluator)

            return .null
        }
    }

    // The one way a written procedure is called from code: each argument
    // read straight into the slot its parameter takes in the callee's frame,
    // whatever the call handed in place held as a box, the module variables
    // the body reads held, and the body run in that frame. A call through a
    // contract read the first to pick the row, so what it read stands there
    // rather than a second reading of the same operand.
    @inline(__always)
    private nonisolated(nonsending) static func entered(
        _ routine: Routine,
        running lowered: LoweredBody,
        in frame: Frame,
        given: [(position: Int, slot: Int, code: CompiledCode)],
        handed: [PlacedCall.Handed],
        at site: Site?,
        first: Value?,
        types: [Name: LoweredType],
        in activation: inout Activation,
        by evaluator: Evaluator
    ) async throws -> Value {
        let callee = routine.linked
        let holds = handed.isEmpty ? [] : try Evaluator.holds(handed, of: callee, first: first, in: activation)
        let body = routine.body(lowered, in: frame)
        var cells = body.cells

        for argument in given {
            if argument.position == 0, let first {
                cells[argument.slot] = .value(first.opened)
            } else {
                cells[argument.slot] = .value(try await argument.code.run(&activation, evaluator))
            }
        }

        for (position, handle) in holds {
            cells[frame.parameters[position]] = .hold(handle)
        }

        try body.holdVariables(in: &cells, of: callee, by: evaluator)

        var entered = Activation(
            cells: cells,
            names: body.names,
            types: types,
            origin: callee.origin,
            in: evaluator.loweredTypes,
            caller: activation.location(at: site),
            hop: routine.hop
        )

        return try await body.run(in: &entered, by: evaluator)
    }

    // Every argument a call wrote, in position order, so an argument standing
    // first refuses or fails before one after it is read. A dispatch read the
    // first to pick the row by the type it holds, so the value it holds
    // stands there rather than a second reading of the same operand. A
    // position handed in place holds no value here, since its box is read
    // through the hold.
    @inline(__always)
    private nonisolated(nonsending) static func given(
        _ arguments: [CompiledCode?],
        first: Value?,
        in activation: inout Activation,
        by evaluator: Evaluator
    ) async throws -> [Value?] {
        var given = activation.arguments(count: arguments.count)

        for (position, argument) in arguments.enumerated() {
            if position == 0, argument != nil, let first {
                given[position] = first.opened
            } else if let argument {
                given[position] = try await argument.run(&activation, evaluator)
            } else {
                given[position] = nil
            }
        }

        return given
    }

    // Every argument a call wrote as synchronous code, where each one is.
    private static func synchronous(_ arguments: [CompiledCode?]) -> [SynchronousCode?]? {
        var codes: [SynchronousCode?] = []

        for argument in arguments {
            switch argument {
            case nil:
                codes.append(nil)

            case let .synchronous(code):
                codes.append(code)

            case .running, .computing:
                return nil
            }
        }

        return codes
    }

    // The arguments a call hands a written body, each with the slot its
    // parameter takes in the callee's frame. A position handed in place has
    // no code, and its slot takes the hold.
    private static func given(
        _ arguments: [CompiledCode?],
        into parameters: [Int]
    ) -> [(position: Int, slot: Int, code: CompiledCode)] {
        arguments.enumerated().compactMap { position, argument in
            argument.map { argument in (position: position, slot: parameters[position], code: argument) }
        }
    }

    // Whether a call of a row may open a value read as a contract: the row
    // has a slot whose type is a bounded type parameter, the only slot that
    // opens one, and what fills it is a contract or is not known here. A
    // parameter filled by any other type is read as that type, which holds
    // no value as a contract.
    private static func opens(_ callee: Linked, filled types: [Name: LoweredType]? = nil) -> Bool {
        callee.slots.contains { slot in
            guard case let .parameter(label, bounds) = slot.type, !bounds.isEmpty else { return false }
            guard let filled = types?[label] else { return true }
            guard case .composition = filled else { return false }

            return true
        }
    }

    // The round slots of a body's loops that the body names nowhere but in
    // reading the round's index: every time a slot is named, it is read that
    // way, apart from the loop binding it.
    private static func indexed(_ body: LoweredBody) -> Set<Int> {
        var rounds: [Int] = []
        var reads: [Int: Int] = [:]

        body.walk { node in
            guard case let .operation(operation) = node else { return true }

            switch operation {
            case let .loop(_, _, round?):
                rounds.append(round)

            case let .local(address):
                if readsIndex(address) {
                    reads[address.slot, default: 0] += 1
                }

            // A call through a contract reads its first as a place, which
            // every code reading it reads the way a slot path is read here.
            case let .dispatch(dispatch):
                if case let .reference(address) = dispatch.first, readsIndex(address) {
                    reads[address.slot, default: 0] += 1
                }

            default:
                break
            }

            return true
        }

        guard !rounds.isEmpty else { return [] }

        var named: [Int: Int] = [:]

        for slot in body.standing.slots {
            named[slot, default: 0] += 1
        }

        return Set(rounds.filter { round in named[round] == reads[round, default: 0] + 1 })
    }

    // The variables a body declares that nothing reaches but through its own
    // slots: every slot a closure takes with it or an argument may hand in
    // place is left out. A call of a value says only at the run which of its
    // arguments it takes in place, so every place it is handed is.
    private static func unboxed(_ body: LoweredBody) -> Set<Int> {
        var declared: Set<Int> = []
        var reached: Set<Int> = []

        body.walk { node in
            switch node {
            case let .instruction(instruction):
                if case let .declare(slot)? = instruction.binding {
                    declared.insert(slot)
                }

            case let .operation(.closure(_, captures)):
                captures.forEach { outer, _ in reached.insert(outer) }

            case let .operation(.call(call)):
                call.placed.handed.forEach { handed in reached.insert(handed.address.slot) }

            case let .operation(.apply(_, arguments)):
                arguments.forEach { argument in reach(argument, in: &reached) }

            // The link placed a call through a contract against each row
            // that satisfies it, and each says what it takes in place. One the
            // link left unplaced is placed at the run.
            case let .operation(.dispatch(dispatch)):
                if dispatch.calls.isEmpty {
                    ([dispatch.first] + dispatch.arguments).forEach { argument in reach(argument, in: &reached) }
                } else {
                    dispatch.calls.values.forEach { call in
                        call.handed.forEach { handed in reached.insert(handed.address.slot) }
                    }
                }

            case .operation:
                break
            }

            return true
        }

        return declared.subtracting(reached)
    }

    private static func movable(_ body: LoweredBody, among unboxed: Set<Int>) -> Set<Int> {
        var guarded: Set<Int> = []

        body.walk { node in
            guard case let .operation(.try(tried, _, _)) = node else { return true }

            for instruction in tried {
                instruction.walk { node in
                    if case let .instruction(inner) = node, case let .assign(address)? = inner.binding {
                        guarded.insert(address.slot)
                    }

                    return true
                }
            }

            return true
        }

        return unboxed.subtracting(guarded)
    }

    private static func holdsStorage(_ type: LoweredType) -> Bool {
        switch type {
        case .array, .dictionary, .named:
            return true

        default:
            return false
        }
    }

    // Whether code reads a slot once, whole, and holds no instruction.
    private static func readsOnce(_ slot: Int, in code: Operation) -> Bool {
        var reads = 0
        var whole = false
        let walked = code.walk { node in
            switch node {
            case .instruction:
                return false

            case let .operation(.local(address)) where address.slot == slot:
                reads += 1
                whole = address.steps.isEmpty && !address.promoted

                return true

            case .operation:
                return true
            }
        }

        return walked && reads == 1 && whole
    }

    private static func reach(_ argument: Argument, in reached: inout Set<Int>) {
        guard case let .reference(address) = argument else { return }

        reached.insert(address.slot)
    }

    // Whether a path reads the index of a round and nothing more.
    private static func readsIndex(_ address: Address) -> Bool {
        guard
            !address.promoted,
            address.steps.count == 1,
            case let .field(position, _, optional: false) = address.steps[0]
        else { return false }

        return position == indexPosition
    }

    // Where a list of instructions a construct holds stands: inside the
    // statement whose instruction holds the construct, under the construct
    // and then the list.
    private static func list(of construct: Construct, _ child: Expression.Child, at site: Site?) -> Place? {
        site?.place.map { statement in statement.appending(.construct(construct)).child(child) }
    }

    // Before the link, what satisfies it is a declaration a claim names in a
    // document this one stands on, and one anywhere else is not one a fold
    // may run.
    private static func unsatisfied(_ dispatch: DispatchOperation, spelling: Name, name: Name) -> RunRefused {
        let because = dispatch.calls.isEmpty
            ? ", and no document this one stands on declares that it conforms to '\(dispatch.contract)'"
            : ", which does not conform to '\(dispatch.contract)'"

        return RunRefused("'\(spelling)' is sent to '\(name)'" + because)
    }

    // Code that refuses where the run reaches it.
    private static func refusing(_ error: any Error) -> CompiledCode {
        .running { _, _ in throw error }
    }

    private static func refusing(_ error: any Error) -> CompiledCall {
        CompiledCall { _, _, _, _ in throw error }
    }

    // Code reaching a row past the table, which traps where the run reaches
    // it the way reading the row there does.
    private static func trapping(_ row: Int, in linked: [Linked]) -> CompiledCode {
        .running { _, _ in
            _ = linked[row]

            return .null
        }
    }

    private static func trapping(_ row: Int, in linked: [Linked]) -> CompiledCall {
        CompiledCall { _, _, _, _ in
            _ = linked[row]

            return .null
        }
    }
}
