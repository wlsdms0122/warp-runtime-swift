//
//  Evaluator.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// One evaluator over the lowered code of one table: a run of an image, and a
// fold, which reaches it through `read`.
struct Evaluator: Sendable {
    // MARK: - Property
    let observer: (any ExecutionObserver)?
    let environment: (any Environment)?

    // The linked table the bodies run against.
    let linked: [Linked]

    // What the numbers in those bodies stand for.
    let resolving: Resolving

    // What a closure the run makes is spelled with, by the origin its row
    // says.
    let naming: [Closure.Document]

    // The types the link declared, by row. Every boundary that settles a
    // value reads it.
    let loweredTypes: LoweredTypeTable

    // One box per module variable, made when the run starts, by the document
    // that declared it, in the order its frame reads them.
    let boxes: [[Handle]]

    // The rows answering each contract's procedure, by the procedure's
    // spelling and the type that answers, for a call through a contract the
    // link has not laid out yet: what a build folding before the link knows
    // from the claims standing so far. Empty for a run of an image, whose
    // calls the link laid out.
    let witnesses: [Name: [Name: Int]]

    // MARK: - Initializer
    // A run of an image: its table, relocated, and a box for each variable
    // its documents declared.
    init(
        _ image: Image,
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?
    ) {
        self.init(
            observer: observer,
            environment: environment,
            linked: image.linked,
            resolving: .rows,
            naming: image.naming,
            loweredTypes: image.loweredTypes,
            boxes: image.variables.map { started in
                started.map { name, value in Handle(name, value) }
            }
        )
    }

    init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil,
        linked: [Linked],
        resolving: Resolving,
        naming: [Closure.Document],
        loweredTypes: LoweredTypeTable,
        boxes: [[Handle]] = [],
        witnesses: [Name: [Name: Int]] = [:]
    ) {
        self.observer = observer
        self.environment = environment
        self.linked = linked
        self.resolving = resolving
        self.naming = naming
        self.loweredTypes = loweredTypes
        self.boxes = boxes
        self.witnesses = witnesses
    }

    // MARK: - Public
    // A run starting from an entry, its arguments by name, which cross the
    // door. What the entry answers the build held to the `returns` it
    // declares, so it reaches the host as it is.
    func run(_ entry: Linked, arguments: [Name: Value]) async throws -> Value {
        try await answer(entry, settled: Settled(values: try entry.settle(arguments)), at: Trace())
    }

    // Calling a closure a procedure holds. What may be called is what the
    // build proved answers. The arguments are handed by position, every
    // position given, and are values from outside, each crossing the door
    // at the closure's own declaration.
    func call(
        _ closure: Closure,
        handing arguments: [Value],
        at trace: Trace
    ) async throws -> Value {
        let linked = try closure.answered()

        return try await answer(closure, as: linked, given: try linked.settle(outside: arguments), holding: [], at: trace)
    }

    // One code read against one frame, for a caller outside a run: what a
    // constant settles to. It is the evaluation a body runs, so
    // what a constant may hold and what a body may hold are one answer.
    func read(_ code: Operation, in activation: Activation) async throws -> Value {
        var activation = activation

        return try await evaluate(code, in: &activation, at: Trace())
    }

    // Sending a procedure a procedure declared it sends. The row the send reaches is
    // numbered by the sender's document, the same as one written in a body, and
    // the arguments stand at the callee's positions.
    func send(
        _ sending: Sent,
        from origin: Int,
        handing values: [Value],
        at trace: Trace
    ) async throws -> Value {
        let callee = linked[try row(sending.row, from: origin)]

        return try await answer(
            callee,
            settled: try settled(callee, sending: sending, handing: values),
            at: trace.appending(callee.hop)
        )
    }

    // MARK: - Private
    // A body run as a procedure: what it answers is caught here. The build
    // held every way out to what the body declares, so it is handed on as it
    // came. A body is reached three ways, and each makes its frame in one
    // place that ends here: a run starting, a written procedure being called,
    // and a closure being invoked.
    private func answer(
        _ body: LoweredBody,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let returned: Value

        do {
            returned = try await run(body, in: &activation, at: trace)
        } catch let leaving as Leaving where leaving.reach == .procedure {
            // A closure is a procedure, so this is also what stops a `return`
            // written inside one from answering for the procedure around it.
            returned = leaving.value
        } catch is Leaving {
            // A loop is inside one body, so one reaching here named a loop no
            // body around it opened. A document is held to naming one the
            // validator can see; an object carries the lowered body and not
            // the document, so what is read back out of a cache never stood in
            // front of that judge.
            //
            // Answered here rather than where a caller happens to stand,
            // because what a frame does at its edge is this function's. Going
            // on would let a loop further out take a leave that was never
            // about it, which reads as an answer rather than as a refusal.
            throw ExecutionError("a leave reached the frame it started in, and nothing there answers one")
        }

        return returned
    }

    // A body answers what it says it answers, and a body that says nothing
    // answers nothing.
    private func run(_ body: LoweredBody, in activation: inout Activation, at trace: Trace) async throws -> Value {
        try await perform(body.instructions, in: &activation, at: trace)

        guard let result = body.result else { return .null }

        return try await evaluate(result, in: &activation, at: trace)
    }

    // Instructions in order, each landing its answer in the slot it binds.
    private func perform(
        _ instructions: [Instruction],
        in activation: inout Activation,
        at trace: Trace
    ) async throws {
        // The cancellation check sits at sequence entry, not only per statement:
        // an empty body inside a loop round must still observe cancellation, or
        // the host's one lever against a runaway loop silently stops working.
        try Task.checkCancellation()

        for instruction in instructions {
            try Task.checkCancellation()

            let result = try await run(instruction, in: &activation, at: trace)

            switch instruction.binding {
            case let .bind(slot)?:
                activation.cells[slot] = .value(result)

            // A new box, so a variable declared inside a block shadows rather
            // than writes an outer one of the same name.
            case let .declare(slot)?:
                activation.cells[slot] = .hold(Handle(activation.frame.names[slot], result))

            // A write lands in a box the enclosing bodies also hold.
            case let .assign(address)?:
                guard case let .hold(handle) = activation.cells[address.slot] else {
                    throw ExecutionError(
                        "'\(activation.spelled(address).rendered)' writes a name that is not a variable here"
                    )
                }

                try handle.write(result, at: try activation.projections(of: address))

            // A nameless statement ran for its effect, and the answer is
            // dropped, which is what leaving the name off said.
            case nil:
                break
            }
        }
    }

    private func run(
        _ instruction: Instruction,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let inside = trace.appending(.statement(instruction.label))

        await observer?.statementStarted(at: inside)

        do {
            let result = try await evaluate(instruction.code, in: &activation, at: inside)

            await observer?.statementCompleted(at: inside, result: result)

            return result
        } catch let leaving as Leaving {
            throw leaving
        } catch {
            let refused = refusal(error, at: inside)

            await observer?.statementFailed(at: inside, error: refused)

            throw refused
        }
    }

    // A refusal leaving a statement takes that statement's place with it, unless
    // it already carries one: the innermost is where the mistake is, and every
    // statement it passes through on the way out is only where the run was.
    private func refusal(_ error: any Error, at trace: Trace) -> any Error {
        guard let refused = error as? any WarpError, refused.trace == nil else { return error }

        return refused.tracing(trace)
    }

    // The evaluator: every operation a body carries.
    private func evaluate(
        _ code: Operation,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        switch code {
        case let .literal(value):
            return value

        case let .local(address):
            return try activation.value(at: address)

        // Making a closure runs nothing: it is the capture, and the capture is
        // these cells.
        case let .closure(number, captures):
            let row = linked[try self.row(number, from: activation.origin)]

            guard let written = row.closure else {
                throw ExecutionError("a closure stands on a row no declaration wrote")
            }

            guard naming.indices.contains(row.origin) else {
                throw ExecutionError("a closure stands in a document this run was not told of")
            }

            return .procedure(
                Closure(
                    writer: Closure.Writer(document: naming[row.origin], declaration: written.by),
                    nth: written.nth,
                    linked: row,
                    captured: captures.map { outer, inner in (slot: inner, cell: activation.cells[outer]) }
                )
            )

        case let .array(elements):
            var values: [Value] = []

            for element in elements {
                values.append(try await evaluate(element, in: &activation, at: trace))
            }

            return .array(values)

        case let .record(held):
            var values: [Value] = []
            values.reserveCapacity(held.fields.count)

            for field in held.fields {
                values.append(try await evaluate(field, in: &activation, at: trace))
            }

            return .record(Record(layout: held.layout, values: values))

        // The run's whole share of a cast: the build already decided what every
        // dot after this means, and the one thing it could not know is what
        // actually arrived. A plain cast lets a mismatch out as `cast_refused`,
        // a failure like any other; an optional one reads it as null, which is
        // the author saying they expected it.
        case let .cast(value, type, optional):
            return try type.reading(
                await evaluate(value, in: &activation, at: trace),
                optional: optional,
                in: loweredTypes
            )

        case let .call(call):
            return try await self.call(call, in: &activation, at: trace)

        case let .dispatch(dispatch):
            let (call, row, first) = try await picked(dispatch, in: &activation, at: trace)

            return try await self.call(call, reaching: row, first: first, in: &activation, at: trace)

        case let .apply(callee, arguments):
            return try await apply(callee, arguments: arguments, in: &activation, at: trace)

        case let .block(body):
            return try await run(body, in: &activation, at: trace)

        // A conditional answers nothing: the condition chooses a way through the
        // body, and what an arm keeps it writes to an outer variable.
        case let .conditional(condition, then, otherwise):
            let take = try bool(try await evaluate(condition, in: &activation, at: trace))

            if let taken = take ? then : otherwise {
                try await perform(taken, in: &activation, at: trace)
            }

            return .null

        case let .loop(condition, body, round, keeps):
            return try await loop(
                while: condition,
                body: body,
                round: round,
                keeps: keeps,
                in: &activation,
                at: trace
            )

        case let .attempt(body, rescue, failure):
            return try await attempt(body, rescue: rescue, failure: failure, in: &activation, at: trace)

        // Nothing comes back, so this answers by not answering. What it carries
        // is worked out here, where the names it reads are still in scope.
        case let .leave(reach, target, value):
            var carried = Value.null

            if let value {
                carried = try await evaluate(value, in: &activation, at: trace)
            }

            throw Leaving(reach: reach, target: target, value: carried)
        }
    }

    // One lookup, because there is one table. What happens is decided by how
    // the row is implemented, not by which container it was found in.
    private func call(
        _ call: CallOperation,
        first: Value? = nil,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        try await self.call(
            call,
            reaching: try row(call.procedure, from: activation.origin),
            first: first,
            in: &activation,
            at: trace
        )
    }

    // The same call, its row already found.
    private func call(
        _ call: CallOperation,
        reaching row: Int,
        first: Value? = nil,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let callee = linked[row]

        switch callee.implementation {
        case .native(.query, _):
            // A variable handed in place is read as what it holds now, since
            // nothing here writes it.
            var values = try await given(call, to: callee, first: first, in: &activation, at: trace)

            for handed in call.handed {
                values[handed.position] = try activation.value(at: handed.address)
            }

            return try await answer(callee, with: Settled(values: values), at: trace)

        case let .native(.effect(effect), _):
            let holds = try holds(call.handed, of: callee, in: activation)
            let settled = Settled(values: try await given(call, to: callee, first: first, in: &activation, at: trace))

            return try await run(effect, of: callee, settled: settled, holds: holds, trace: trace)

        case let .body(body, frame):
            let holds = try holds(call.handed, of: callee, in: activation)
            let settled = Settled(values: try await given(call, to: callee, first: first, in: &activation, at: trace))

            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: settled,
                holding: holds,
                at: trace.appending(callee.hop)
            )
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
    private func apply(
        _ callee: Operation,
        arguments: [Argument],
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let value = try await evaluate(callee, in: &activation, at: trace)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.nominal), and only a procedure can be called"
            )
        }

        let linked = try closure.answered()
        let handed = arguments.enumerated().compactMap { position, argument -> CallOperation.Handed? in
            guard
                case let .reference(address) = argument,
                linked.slots.indices.contains(position),
                linked.slots[position].type.isInout
            else { return nil }

            return CallOperation.Handed(position: position, address: address)
        }
        let holds = try holds(handed, of: linked, in: activation)

        // A value carries no names, so the arguments travel by position, in
        // the order they were written, and land in the slots in that order.
        var given: [Value?] = []

        for (position, argument) in arguments.enumerated() {
            switch argument {
            case let .value(operation):
                given.append(try await evaluate(operation, in: &activation, at: trace))

            case let .reference(address):
                given.append(
                    handed.contains { held in held.position == position } ? nil : try activation.value(at: address)
                )
            }
        }

        return try await answer(closure, as: linked, given: given, holding: holds, at: trace)
    }

    // The one way a closure is called: the captured cells in their slots, the
    // arguments in theirs as the caller has them, whatever the call handed in
    // place held as a box, and the body answered in the frame that was just
    // made. The row is asked whether this run may read it before anything
    // reads its rows.
    //
    // Making the frame and answering from it are one act here, so no caller
    // holds a frame it has not answered from.
    private func answer(
        _ closure: Closure,
        as linked: Linked,
        given arguments: [Value?],
        holding holds: [(position: Int, handle: Handle)],
        at trace: Trace
    ) async throws -> Value {
        guard case let .body(body, frame) = linked.implementation else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        // Its rows are numbered by the table of the link that made it.
        guard linked.readable(in: loweredTypes) else {
            throw ExecutionError("this call \(Linked.unreadable)")
        }

        try linked.refuseCount(arguments.count)

        var activation = try self.activation(of: linked, in: frame)

        for (slot, cell) in closure.captured {
            activation.cells[slot] = cell
        }

        for (position, handle) in holds {
            activation.cells[frame.parameters[position]] = .hold(handle)
        }

        for (position, value) in arguments.enumerated() {
            guard let value else { continue }

            activation.cells[frame.parameters[position]] = .value(value)
        }

        return try await answer(body, in: &activation, at: trace.appending(linked.hop))
    }

    // A row answered with its arguments settled and nothing handed in place:
    // what a send reaches and what a run starts from. An effect runs here,
    // and every other row answers the way it does as data.
    private func answer(
        _ callee: Linked,
        settled: Settled,
        at trace: Trace
    ) async throws -> Value {
        guard case let .native(.effect(effect), _) = callee.implementation else {
            return try await answer(callee, with: settled, at: trace)
        }

        return try await run(effect, of: callee, settled: settled, holds: [], trace: trace)
    }

    // The one way a written procedure is called: its frame, the settled
    // arguments in their slots, whatever the call handed in place held as a
    // box, and the body answered in that frame.
    private func answer(
        _ callee: Linked,
        running body: LoweredBody,
        in frame: Frame,
        settled arguments: Settled,
        holding holds: [(position: Int, handle: Handle)],
        at trace: Trace
    ) async throws -> Value {
        var activation = try self.activation(of: callee, in: frame)

        // A parameter handed in place takes no value: it takes a hold on the
        // caller's variable, and what the hold reaches is read only where the
        // body reads it.
        for (position, handle) in holds {
            activation.cells[frame.parameters[position]] = .hold(handle)
        }

        for (position, value) in arguments.values.enumerated() {
            guard let value else { continue }

            activation.cells[frame.parameters[position]] = .value(value)
        }

        return try await answer(body, in: &activation, at: trace)
    }

    private func loop(
        while condition: Operation,
        body: LoweredBody,
        round: Int?,
        keeps: Range<Int>?,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let name = round.map { round in activation.frame.names[round] }
        var index = 0

        while true {
            // The condition reads the state before the round it would start,
            // and the result reads it as it stands when the loop ends.
            if let round {
                activation.cells[round] = .value(
                    .record(Record(layout: LoweredRecord.round.layout, values: [.int(index)]))
                )
            }

            guard try bool(try await evaluate(condition, in: &activation, at: trace)) else {
                guard let result = body.result else { return .null }

                return try await evaluate(result, in: &activation, at: trace)
            }

            // What the last finished round bound is what the result reads. A
            // round cut short is put back to that, where the build said the
            // result could tell.
            let kept = keeps.map { range in activation.cells[range] }

            do {
                try await perform(body.instructions, in: &activation, at: trace.appending(.round(index)))
            } catch let leaving as Leaving where leaving.claimed(by: name) {
                if let keeps, let kept {
                    activation.cells.replaceSubrange(keeps, with: kept)
                }

                guard leaving.reach == .round else {
                    guard let result = body.result else { return .null }

                    return try await evaluate(result, in: &activation, at: trace)
                }
            }

            index += 1
        }
    }

    private func attempt(
        _ body: LoweredBody,
        rescue: LoweredBody,
        failure: Int?,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        do {
            return try await run(body, in: &activation, at: trace)
        } catch {
            guard !Task.isCancelled else { throw error }

            // An author mistake passes through: a rescue is for what the world
            // did, not for what the procedure says.
            guard let recoverable = error as? any RecoverableFailure else { throw error }

            // While the rescue runs, the failure is a value under the declared
            // name, where the attempt bound one. What a failure carries is the
            // failing procedure's, a value from outside, so the payload comes
            // in through the door at the envelope's type.
            if let failure {
                activation.cells[failure] = .value(
                    try FailurePayload.declared.lowered(in: loweredTypes).settling(
                        outside: recoverable.payload,
                        at: "'\(activation.frame.names[failure])'",
                        in: loweredTypes
                    )
                )
            }

            await observer?.failureRescued(
                name: failure.map { failure in activation.frame.names[failure].spelling },
                error: error
            )

            return try await run(rescue, in: &activation, at: trace)
        }
    }

    // The frame a row runs in, with the module variables it reads in place.
    private func activation(of callee: Linked, in frame: Frame) throws -> Activation {
        var activation = Activation(frame, of: callee.origin)

        guard !frame.variables.isEmpty else { return activation }

        guard boxes.indices.contains(callee.origin) else {
            throw ExecutionError("'\(callee.rendered)' reads its document's variables, and this run holds none")
        }

        let held = boxes[callee.origin]

        for (variable, slot) in frame.variables {
            activation.cells[slot] = .hold(held[variable])
        }

        return activation
    }

    // The holds a call hands in place, by parameter position: the caller's
    // box, seen through the path the argument wrote. Every write the callee
    // makes lands in that box as it is made, so a call that fails after
    // writing has written.
    private func holds(
        _ handed: [CallOperation.Handed],
        of callee: Linked,
        in activation: Activation
    ) throws -> [(position: Int, handle: Handle)] {
        try handed.map { handed in
            guard case let .hold(handle) = activation.cells[handed.address.slot] else {
                throw ExecutionError(
                    "'\(callee.rendered)' takes '\(callee.slots[handed.position].name)' in place,"
                        + " and '\(activation.frame.names[handed.address.slot])' is not a variable here"
                )
            }

            return (handed.position, handle.extended(by: try activation.projections(of: handed.address)))
        }
    }

    // Which row answers a call through a contract, and the value it answers
    // about. The type the first argument is an instance of is the whole of
    // the choosing: the link gathered every type that answers this procedure
    // and lowered a call for each, so nothing is resolved here.
    private func picked(
        _ dispatch: DispatchOperation,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> (call: CallOperation, row: Int, first: Value) {
        let first = try await evaluate(dispatch.first, in: &activation, at: trace)
        let spelling = ContractProcedure.spelling(of: dispatch.contract, procedure: dispatch.procedure)

        if let call = dispatch.calls[first.nominal] {
            return (call, try row(call.procedure, from: activation.origin), first)
        }

        // A call the link has not laid out reaches the row a claim standing
        // so far names, placed against it the way the link would place it.
        // What it ran on is the claim, which the link still holds to the
        // declarations behind it, so the pair is written down for the link.
        if dispatch.calls.isEmpty, let row = witnesses[spelling]?[first.nominal] {
            loweredTypes.fulfillment?.require(folded: Claim(type: first.nominal, contract: dispatch.contract))

            let call = try CallOperation(
                handing: [nil] + dispatch.arguments.map { argument in Optional(argument) },
                to: linked[row],
                row: row,
                picked: true,
                in: loweredTypes,
                at: .procedure(linked[row].rendered, in: .assembled)
            )

            return (call, row, first)
        }

        // Before the link, what answers is a declaration a claim names in a
        // document this one stands on, and one anywhere else is not one a
        // fold may run.
        let because = dispatch.calls.isEmpty
            ? ", and no document this one stands on declares what answers '\(dispatch.contract)' for it"
            : ", which answers no procedure of '\(dispatch.contract)'"

        throw ExecutionError("'\(spelling)' is sent to '\(first.nominal)'" + because)
    }

    // Every argument a call wrote, in position order, so an argument standing
    // first refuses or fails before one after it is read. A loop rather than
    // a map, since reading one may run what produced it. A dispatch read the
    // first to pick the row, so what it read stands there rather than a
    // second reading of the same operand. A position handed in place holds
    // no value here, since its box is read through the hold.
    private func given(
        _ call: CallOperation,
        to callee: Linked,
        first: Value?,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> [Value?] {
        var given: [Value?] = []
        given.reserveCapacity(call.arguments.count)

        for (position, argument) in call.arguments.enumerated() {
            let read: Value

            if position == 0, let first {
                read = first
            } else if let argument {
                read = try await evaluate(argument, in: &activation, at: trace)
            } else {
                given.append(nil)
                continue
            }

            given.append(read)
        }

        return given
    }

    // What a row answers from its settled arguments, with nothing handed in
    // place. A query answers through its own door and a body runs on a frame
    // of its own. An effect answers only by running, so it is not read here.
    private func answer(
        _ callee: Linked,
        with arguments: Settled,
        at trace: Trace
    ) async throws -> Value {
        switch callee.implementation {
        case let .native(.query(query), _):
            return try await evaluate(query, of: callee, settled: arguments, at: trace)

        case let .body(body, frame):
            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: arguments,
                holding: [],
                at: trace
            )

        case .native(.effect, _):
            throw ExecutionError(
                "this answers only by running, so it cannot be read as data here"
            )
        }
    }

    private func bool(_ value: Value) throws -> Bool {
        guard case let .bool(answer) = value else {
            throw ExecutionError("a condition answers \(value.nominal), expected Bool")
        }

        return answer
    }

    // The two doors a native procedure answers through, what it hands back
    // settled by the procedure as a value from outside. The procedure's
    // parameters are its own type, so the call is made where that type has
    // a name: handing `any Query` to a generic function opens it.
    private func evaluate<W: Query>(
        _ query: W,
        of callee: Linked,
        settled: Settled,
        at trace: Trace
    ) async throws -> Value {
        try callee.settling(
            answered: try await query.evaluate(
                Question(
                    settled: settled,
                    of: callee,
                    evaluator: self,
                    at: trace
                )
            )
        )
    }

    private func run<W: Effect>(
        _ effect: W,
        of callee: Linked,
        settled: Settled,
        holds: [(position: Int, handle: Handle)],
        trace: Trace
    ) async throws -> Value {
        try callee.settling(
            answered: try await effect.run(
                Invocation(
                    of: callee,
                    settled: settled,
                    holds: holds,
                    trace: trace,
                    evaluator: self
                )
            )
        )
    }

    // Which row of this table a number written in a body stands for. A number
    // the link found no row for is a body it lowered without judging: nothing
    // a run does can answer it.
    private func row(_ number: Int, from origin: Int) throws -> Int {
        guard let row = resolving.row(number, from: origin) else {
            throw ExecutionError("a call standing at \(number) reaches no row of this link")
        }

        return row
    }

    // A send's arguments, values a procedure the host answers made, through
    // the door at the callee's boundary, standing at its positions.
    private func settled(
        _ callee: Linked,
        sending: Sent,
        handing values: [Value]
    ) throws -> Settled {
        // How many a Swift body builds is the body's, so this is the one thing
        // about a send the build cannot read.
        guard values.count == sending.handing else {
            throw ExecutionError(
                "'\(callee.rendered)' is handed \(values.count) here, and the procedure sending"
                    + " it declares it hands \(sending.handing)"
            )
        }

        return Settled(values: try callee.settle(outside: values))
    }
}
