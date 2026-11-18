//
//  Evaluator.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// One evaluator over the compiled code of one table: a run of an image, and
// a fold, which reaches it through `read`. The code is the table's; what this
// holds beside it is the run's own: who watches, what the run may reach
// outside itself, and a box per module variable.
final class Evaluator: Sendable {
    // MARK: - Property
    let observer: (any ExecutionObserver)?
    let environment: (any Environment)?

    // The table the run reads, compiled.
    let table: CodeTable

    // One box per module variable, made when the run starts, by the document
    // that declared it, in the order its frame reads them.
    let boxes: [[Handle]]

    // The types the link declared, by row. Every door and every cast reads
    // it.
    var loweredTypes: LoweredTypeTable { table.loweredTypes }

    // MARK: - Initializer
    // A run of an image: its table, compiled with it, and a box for each
    // variable its documents declared.
    convenience init(
        _ image: Image,
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?
    ) {
        self.init(
            observer: observer,
            environment: environment,
            table: image.code,
            boxes: image.variables.map { started in
                started.map { name, value in Handle(name, value) }
            }
        )
    }

    // A table that has not been linked yet, which a fold reads: what it
    // reaches is compiled where it is reached.
    convenience init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil,
        linked: [Linked],
        resolving: Resolving,
        naming: [Closure.Document],
        loweredTypes: LoweredTypeTable,
        boxes: [[Handle]] = [],
        witnesses: [Name: [Name: Int]] = [:],
        contractProcedures: [Name: LoweredContractProcedure] = [:]
    ) {
        self.init(
            observer: observer,
            environment: environment,
            table: CodeTable(
                linked: linked,
                resolving: resolving,
                naming: naming,
                loweredTypes: loweredTypes,
                witnesses: witnesses,
                contractProcedures: contractProcedures
            ),
            boxes: boxes
        )
    }

    private init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        table: CodeTable,
        boxes: [[Handle]]
    ) {
        self.observer = observer
        self.environment = environment
        self.table = table
        self.boxes = boxes
    }

    // MARK: - Public
    // A run starting from an entry, its arguments by name, which cross the
    // door. What the entry returns the build held to the `returns` it
    // declares, so it reaches the host as it is. The entry's frame is the
    // first, so a trace into it takes no hop.
    nonisolated(nonsending) func run(_ entry: Linked, arguments: [Name: Value]) async throws -> Value {
        try await invoke(
            table.routine(of: entry),
            arguments: try entry.settle(arguments, in: loweredTypes),
            from: .trace(Trace()),
            entering: nil
        ).dropped
    }

    // Calling a closure a procedure holds. What may be called is what the
    // build proved callable. The arguments are handed by position, every
    // position given, and are values from outside, each crossing the door
    // at the closure's own declaration, its type parameters read as the
    // closure holds them. Only a native procedure calls one, inside the run,
    // so what it returns goes back to that procedure as it came.
    nonisolated(nonsending) func call(
        _ closure: Closure,
        handing arguments: [Value],
        at location: Location
    ) async throws -> Value {
        let (linked, types) = try table.row(of: closure)

        return try await invoke(
            closure,
            as: linked,
            reading: types,
            given: try linked.settle(outside: arguments, filled: types, in: loweredTypes).values,
            holding: [],
            from: location
        )
    }

    // One code read against one frame, for a caller outside a run: what a
    // constant folds to. It is compiled and run the way a body is, so what a
    // constant may hold and what a body may hold are one question.
    nonisolated(nonsending) func read(_ code: Operation, in activation: Activation) async throws -> Value {
        var activation = activation
        let compiled = CodeGenerator(table: table, origin: activation.origin, names: activation.names).code(code)

        return try await compiled.run(&activation, self)
    }

    // Sending a procedure a procedure declared it sends. The row the send reaches is
    // numbered by the sender's document, the same as one written in a body, and
    // the arguments, values made by a native procedure, which the host
    // implements, come in through the door at the callee's slots. What it
    // returns goes back to the sender, inside the run, as it came.
    nonisolated(nonsending) func send(
        _ sending: Sent,
        from origin: Int,
        handing values: [Value],
        at location: Location
    ) async throws -> Value {
        let row = try table.row(sending.row, from: origin)
        let callee = table.linked[row]

        return try await invoke(
            table.routine(row: row),
            arguments: try callee.settle(outside: values, in: loweredTypes),
            from: location,
            entering: callee.hop
        )
    }

    // The one way a closure is called: its frame, the captured cells in
    // their slots, the arguments in theirs as the caller has them, one for
    // each, whatever the call handed in place held as a box, and the body run
    // in the frame that was just made. The row and the types are the ones
    // `row(of:)` returned.
    //
    // Making the frame and running the body in it are one act here, so no
    // caller holds a frame it has not run the body in.
    nonisolated(nonsending) func invoke(
        _ closure: Closure,
        as linked: Linked,
        reading types: [Name: LoweredType],
        given arguments: [Value?],
        holding holds: [(position: Int, handle: Handle)],
        from caller: Location
    ) async throws -> Value {
        guard case let .body(lowered, frame) = linked.implementation else {
            throw RunRefused("a closure is a body, and this one is native")
        }

        let routine = table.routine(of: linked)
        let body = routine.body(lowered, in: frame)
        var cells = body.cells

        try body.holdVariables(in: &cells, of: linked, by: self)

        for (slot, cell) in closure.captured {
            cells[slot] = cell
        }

        for (position, handle) in holds {
            cells[body.parameters[position]] = .hold(handle)
        }

        for (position, value) in arguments.enumerated() {
            guard let value else { continue }

            cells[body.parameters[position]] = .value(value)
        }

        var activation = Activation(
            cells: cells,
            names: body.names,
            types: types,
            origin: linked.origin,
            in: loweredTypes,
            caller: caller,
            hop: routine.hop
        )

        return try await body.run(in: &activation, by: self)
    }

    // The one way a written procedure is called: its frame, the arguments
    // in their slots, whatever the call handed in place held as a box, and
    // the body run in that frame. A parameter handed in place takes no
    // value: it takes a hold on the caller's variable, and what the hold
    // reaches is read only where the body reads it.
    nonisolated(nonsending) func invoke(
        _ routine: Routine,
        running body: CompiledBody,
        given arguments: [Value?],
        holding holds: [(position: Int, handle: Handle)],
        types: [Name: LoweredType],
        from caller: Location,
        entering hop: Trace.Hop?
    ) async throws -> Value {
        var cells = body.cells

        try body.holdVariables(in: &cells, of: routine.linked, by: self)

        for (position, handle) in holds {
            cells[body.parameters[position]] = .hold(handle)
        }

        for (position, value) in arguments.enumerated() {
            guard let value else { continue }

            cells[body.parameters[position]] = .value(value)
        }

        var activation = Activation(
            cells: cells,
            names: body.names,
            types: types,
            origin: routine.linked.origin,
            in: loweredTypes,
            caller: caller,
            hop: hop
        )

        return try await body.run(in: &activation, by: self)
    }

    // Each protocol a native procedure adopts, what it hands back
    // settled at `returns` as a value from outside.
    @inline(__always)
    nonisolated(nonsending) func evaluate(
        _ query: any Query,
        of callee: Linked,
        arguments: consuming ArgumentList,
        returning returns: LoweredType,
        at location: consuming Location
    ) async throws -> Value {
        try returns.settling(
            outside: try await query.answer(
                Asked(
                    arguments: arguments,
                    of: callee,
                    evaluator: self,
                    at: location
                )
            ),
            at: "returns",
            in: loweredTypes
        )
    }

    // A computation answers from its arguments alone, so asking it waits on
    // nothing.
    @inline(__always)
    func compute(
        _ computation: any Computation,
        given: consuming Given,
        returning returns: LoweredType
    ) throws -> Value {
        try returns.settling(outside: try computation.answer(given), at: "returns", in: loweredTypes)
    }

    // The same, the computation handed the arguments to keep.
    func compute(
        _ computation: any Computation,
        taking given: consuming Given,
        returning returns: LoweredType
    ) throws -> Value {
        try returns.settling(outside: try Self.taking(computation, given), at: "returns", in: loweredTypes)
    }

    nonisolated(nonsending) func run(
        _ effect: any Effect,
        of callee: Linked,
        arguments: consuming ArgumentList,
        holds: [(position: Int, handle: Handle)],
        returning returns: LoweredType,
        at location: consuming Location
    ) async throws -> Value {
        try returns.settling(
            outside: try await effect.perform(
                Invoked(
                    of: callee,
                    arguments: arguments,
                    holds: holds,
                    trace: location.trace,
                    evaluator: self
                )
            ),
            at: "returns",
            in: loweredTypes
        )
    }

    // The holds a call hands in place, by parameter position: the caller's
    // box, seen through the path the argument wrote. Every write the callee
    // makes lands in that box as it is made, so a call that fails after
    // writing has written.
    // A row a call through a contract picked by the type a box holds takes
    // the box first as that type's: it reads the value held, and a whole value
    // it writes is held beside the type again.
    static func holds(
        _ handed: [PlacedCall.Handed],
        of callee: Linked,
        first: Value?,
        in activation: Activation
    ) throws -> [(position: Int, handle: Handle)] {
        try handed.map { handed in
            guard case let .hold(handle) = activation.cells[handed.address.slot] else {
                throw RunRefused(
                    "'\(callee.rendered)' takes '\(callee.slots[handed.position].name)' in place,"
                        + " and '\(activation.names[handed.address.slot])' is not a variable here"
                )
            }

            let extended = handle.extended(by: try activation.projections(of: handed.address))

            guard handed.position == 0, case let .existential(existential)? = first else {
                return (handed.position, extended)
            }

            return (handed.position, extended.opened(as: try existential.resolved()))
        }
    }

    // A value read as a contract, standing alone at a type parameter a bound
    // holds, fills it with the type it holds, and the callee takes the value:
    // inside a body, the parameter is one type, which the activation holds.
    // Whether any did.
    static func opening(
        _ values: inout [Value?],
        filling types: inout [Name: LoweredType],
        of callee: Linked
    ) throws -> Bool {
        var opened = false

        for (position, slot) in callee.slots.enumerated() where values.indices.contains(position) {
            guard
                case let .parameter(label, bounds) = slot.type,
                !bounds.isEmpty,
                case let .existential(existential)? = values[position]
            else { continue }

            types[label] = try existential.resolved()
            values[position] = existential.value
            opened = true
        }

        return opened
    }

    static func bool(_ value: Value) throws -> Bool {
        guard case let .bool(condition) = value else {
            throw RunRefused("a condition reads \(value.nominal), expected Bool")
        }

        return condition
    }

    // MARK: - Private
    private static func taking<C: Computation>(_ computation: C, _ given: consuming Given) throws -> Value {
        try computation.compute(taking: Arguments(given))
    }

    // A row called with its arguments and nothing handed in place: what a
    // send reaches and what a run starts from. A query returns through its
    // own door, an effect runs, and a body runs on a frame of its own.
    private nonisolated(nonsending) func invoke(
        _ routine: Routine,
        arguments: ArgumentList,
        from caller: Location,
        entering hop: Trace.Hop?
    ) async throws -> Value {
        let callee = routine.linked
        let entered = hop.map { hop in Location.entered(FrameLink(caller: caller, hop: hop)) } ?? caller

        switch callee.implementation {
        case let .native(.query(query), _):
            return try await evaluate(query, of: callee, arguments: arguments, returning: callee.returns, at: entered)

        case let .native(.effect(effect), _):
            return try await run(effect, of: callee, arguments: arguments, holds: [], returning: callee.returns, at: entered)

        case let .body(lowered, frame):
            return try await invoke(
                routine,
                running: routine.body(lowered, in: frame),
                given: arguments.values,
                holding: [],
                types: arguments.types,
                from: caller,
                entering: hop
            )
        }
    }
}
