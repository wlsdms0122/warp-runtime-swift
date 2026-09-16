//
//  Executor.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Runs an image. Two halves over one code: `read` answers what answers
// without running, synchronously, which is what a condition, an argument, a
// const body and a procedure handed a procedure need; `evaluate` runs constructs,
// effects and calls of values, and hands every data case to `read`.
public struct Executor: Sendable {
    // MARK: - Property
    public let observer: (any ExecutionObserver)?
    public let environment: (any Environment)?

    // The linked table, seeded from the image this run was given. Empty
    // until then, which is why nothing but `run(_ image:)` can start a run.
    let linked: [Linked]

    // What the numbers in those bodies stand for.
    let resolving: Resolving

    // The types the link declared, by row. Every boundary that settles a
    // value reads it.
    let loweredTypes: LoweredTypeTable

    // One box per module variable, made when the run starts, by the document
    // that declared it, in the order its frame reads them.
    let boxes: [[Handle]]

    // What a loop hands its body each round, and what a walk hands its own.
    private static let walkLayout = Layout(name: nil, ordered: ["index", "item"])

    // MARK: - Initializer
    // What a caller has to say to make one: who watches, and what the run may
    // reach outside itself. The table comes from an image, so this is an
    // executor with nothing to run yet.
    public init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil
    ) {
        self.init(observer: observer, environment: environment, linked: [], resolving: .rows)
    }

    // Seeded, and not public: the table is the link's answer, so a caller
    // that could write it would be running a program nothing linked.
    init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        linked: [Linked],
        resolving: Resolving,
        loweredTypes: LoweredTypeTable = .empty,
        boxes: [[Handle]] = []
    ) {
        self.observer = observer
        self.environment = environment
        self.linked = linked
        self.resolving = resolving
        self.loweredTypes = loweredTypes
        self.boxes = boxes
    }

    // MARK: - Public
    // Running takes an image, not a procedure, so "ran something that was never
    // linked" is not a state this type can be put in.
    public func run(
        _ image: Image,
        arguments: [Name: Value] = [:]
    ) async throws -> Value {
        let executor = Executor(
            observer: observer,
            environment: environment,
            linked: image.linked,
            resolving: .rows,
            loweredTypes: image.loweredTypes,
            boxes: image.variables.map { started in
                started.map { name, value in Handle(name, value) }
            }
        )
        let entry = image.entry

        guard case let .body(body, frame) = entry.implementation else {
            throw ExecutionError("a run starts from a body, and this declaration is native")
        }

        let settled = try entry.settle(arguments.map { name, value in (name: name, value: value) })
        var activation = try executor.activation(of: entry, in: frame)

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return try await executor.answer(body, of: entry, in: &activation, at: Trace())
    }

    // MARK: - Internal
    // Calling a closure a procedure holds. The arguments settle against the
    // closure's declaration the way a written call's do, so a closure written
    // for this procedure declares every name it is handed.
    func call(
        _ closure: Closure,
        handing arguments: [(name: Name, value: Value)],
        at trace: Trace
    ) async throws -> Value {
        try await answer(closure, given: arguments, at: trace)
    }

    // One code read against one frame, for a caller outside a run: what a
    // constant settles to. It reaches the same evaluator a body reaches, so
    // what a constant may hold and what a body may hold are one answer.
    func read(_ code: Operation, in activation: Activation) async throws -> Value {
        var activation = activation

        return try await evaluate(code, in: &activation, at: Trace())
    }

    // MARK: - Private
    // What a name takes: the value settled to what the name said it holds, or
    // the value as it stands where the name said nothing. A declaration is a
    // boundary like a parameter's, so it is crossed by the one judge.
    private func held(
        _ value: Value,
        as settling: LoweredType?,
        in slot: Int,
        of activation: Activation
    ) throws -> Value {
        guard let settling else { return value }

        return try settling.settling(value, at: "'\(activation.frame.names[slot])'", in: loweredTypes)
    }

    // A body run as a procedure: what it answers is caught here, and what it
    // answers is settled against what it declared.
    //
    // Both halves are the frame, and neither works without the other, so there
    // is one of these rather than one per way of reaching a body. A body is
    // reached three ways, and each makes its frame in one place that ends
    // here: a run starting, a written procedure being called, and a closure
    // being invoked.
    private func answer(
        _ body: Body,
        of callee: Linked,
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
            // validator can see; an artifact carries the lowered body and not
            // the document, so what is read back out of a cache never stood in
            // front of that judge.
            //
            // Answered here rather than where a caller happens to stand,
            // because what a frame does at its edge is this function's. Going
            // on would let a loop further out take a leave that was never
            // about it, which reads as an answer rather than as a refusal.
            throw ExecutionError("a leave reached the frame it started in, and nothing there answers one")
        }

        return try callee.settling(returned: returned)
    }

    // A body answers what it says it answers, and a body that says nothing
    // answers nothing.
    private func run(_ body: Body, in activation: inout Activation, at trace: Trace) async throws -> Value {
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
        // the caller's one lever against a runaway loop silently stops working.
        try Task.checkCancellation()

        for instruction in instructions {
            try Task.checkCancellation()

            let result = try await run(instruction, in: &activation, at: trace)

            switch instruction.binding {
            case let .bind(slot, settling)?:
                activation.cells[slot] = .value(try held(result, as: settling, in: slot, of: activation))

            // A new box, so a variable declared inside a block shadows rather
            // than writes an outer one of the same name.
            case let .declare(slot, settling)?:
                activation.cells[slot] = .hold(
                    Handle(
                        activation.frame.names[slot],
                        try held(result, as: settling, in: slot, of: activation)
                    )
                )

            // A write lands in a box the enclosing bodies also hold.
            case let .assign(address, settling)?:
                guard case let .hold(handle) = activation.cells[address.slot] else {
                    throw ExecutionError(
                        "'\(spelled(address, in: activation).rendered)' writes a name that is not a variable here"
                    )
                }

                try handle.write(
                    try held(result, as: settling, in: address.slot, of: activation),
                    at: try positioned(address, in: activation)
                )

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

    // The evaluator for what runs. The containers recurse here so an effect
    // written inside one is run; every other data case is `read`'s.
    private func evaluate(
        _ code: Operation,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        switch code {
        case let .literal(value):
            return value

        case let .local(address):
            return try found(address, in: activation)

        // Making a closure runs nothing: it is the capture, and the capture is
        // these cells.
        case let .closure(number, captures):
            return .procedure(
                Closure(
                    origin: activation.origin,
                    number: number,
                    linked: linked[try row(number, from: activation.origin)],
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

        // The run's whole share of a cast: the link already decided what every
        // dot after this means, and the one thing it could not know is what
        // actually arrived. A plain cast lets the refusal out as a failure like
        // any other; an optional one reads the mismatch as null, which is the
        // author saying they expected it.
        case let .cast(value, type, optional):
            return try type.reading(
                await evaluate(value, in: &activation, at: trace),
                optional: optional,
                in: loweredTypes
            )

        case let .call(call):
            return try await self.call(call, in: &activation, at: trace)

        case let .dispatch(dispatch):
            let (call, receiver) = try await picked(dispatch, in: &activation, at: trace)

            return try await self.call(call, receiving: receiver, in: &activation, at: trace)

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
        receiving handed: Value? = nil,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let callee = linked[try row(call.procedure, from: activation.origin)]

        switch callee.implementation {
        // A query answers without running, so the const half is the whole
        // implementation. It is here only so that `x.count` and the same
        // procedure written as a statement mean the same thing.
        case .native(.query):
            // A variable handed in place is read as what it holds now and
            // settled the way any argument is, since nothing here writes it.
            var values = try await given(call.arguments, in: &activation, at: trace)

            for handed in call.handed {
                values[handed.position] = try found(handed.address, in: activation)
            }

            let settled = try settled(
                callee,
                given: values,
                skipping: skipped(call, of: callee, holding: false, receiving: handed)
            )
            let receiver = try await received(call, of: callee, handed: handed, in: &activation, at: trace)

            do {
                return try await answer(callee, for: receiver, with: settled, at: trace)
            } catch let unfit as ReferenceUnfit {
                throw unfit
            } catch {
                // A procedure blaming a type is answerable only if the author
                // can see which name held it.
                guard case let .local(address)? = call.receiver else { throw error }

                throw ReferenceUnfit(path: spelled(address, in: activation), reason: "\(error)")
            }

        case let .native(.effect(effect)):
            let holds = try holds(call.handed, of: callee, in: activation)
            let settled = try settled(
                callee,
                given: try await given(call.arguments, in: &activation, at: trace),
                skipping: skipped(call, of: callee, holding: true, receiving: handed)
            )
            // A receiver handed in place is read for the effect as what its
            // hold holds now, the way the effect reads any receiver.
            let held = try holds.first { position, _ in position == callee.receiverPosition }.map { _, handle in try handle.value() }

            return try await run(
                effect,
                of: callee,
                receiver: sent(to: callee, receiver: try await received(call, of: callee, handed: handed, in: &activation, at: trace) ?? held, arguments: settled),
                settled: settled,
                holds: holds,
                trace: trace
            )

        case let .body(body, frame):
            let holds = try holds(call.handed, of: callee, in: activation)
            let receiver = try await received(call, of: callee, handed: handed, in: &activation, at: trace)
            let settled = try settled(
                callee,
                given: try await given(call.arguments, in: &activation, at: trace),
                skipping: skipped(call, of: callee, holding: true, receiving: handed)
            )

            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: settled,
                receiver: receiver,
                holding: holds,
                at: trace.appending(.procedure(callee.label.spelling))
            )
        }
    }

    // Calling a value. The body runs in the cells the closure captured and not
    // in the caller's: that is what lexical scope means, and it is the reason a
    // closure is worth passing at all.
    private func apply(
        _ callee: Operation,
        arguments: [(Name, Operation)],
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let value = try await evaluate(callee, in: &activation, at: trace)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.type), and only a procedure can be called"
            )
        }

        // The signature is the value's, so the arguments travel by name and
        // find their slots here, along the list.
        var resolved: [(name: Name, value: Value)] = []

        for (name, argument) in arguments {
            resolved.append((name: name, value: try await evaluate(argument, in: &activation, at: trace)))
        }

        return try await answer(closure, given: resolved, at: trace)
    }

    // The one way a closure is called: the arguments settled by the closure's
    // own row, the captured cells in their slots, the parameters in theirs,
    // and the body answered in the frame that was just made. The row is asked
    // whether this run may read it before anything reads its rows.
    //
    // Making the frame and answering from it are one act here, so no caller
    // holds a frame it has not answered from.
    private func answer(
        _ closure: Closure,
        given arguments: [(name: Name, value: Value)],
        at trace: Trace
    ) async throws -> Value {
        guard case let .body(body, frame) = closure.linked.implementation else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        // Its rows are numbered by the table of the link that made it.
        guard closure.linked.readable(in: loweredTypes) else {
            throw ExecutionError("this call \(Linked.unreadable)")
        }

        let settled = try closure.linked.settle(arguments)
        var activation = try self.activation(of: closure.linked, in: frame)

        for (slot, cell) in closure.captured {
            activation.cells[slot] = cell
        }

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return try await answer(body, of: closure.linked, in: &activation, at: trace)
    }

    // The one way a written procedure is called: its frame, the settled
    // arguments in their slots, the receiver in the slot its signature named,
    // whatever the call handed in place held as a box, and the body answered
    // in that frame.
    private func answer(
        _ callee: Linked,
        running body: Body,
        in frame: Frame,
        settled arguments: Settled,
        receiver: Value?,
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

        // A receiver is written on the other side of the dot rather than by
        // name. It is not settled as an argument, since being sent to nothing
        // is something a procedure answers rather than refuses, but the body
        // reads it under the name its signature gave it.
        if let position = callee.receiverPosition, let receiver {
            activation.cells[frame.parameters[position]] = .value(receiver)
        }

        return try await answer(body, of: callee, in: &activation, at: trace)
    }

    private func loop(
        while condition: Operation,
        body: Body,
        round: Int,
        keeps: Range<Int>?,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let name = activation.frame.names[round]
        var index = 0

        while true {
            // The condition reads the state before the round it would start,
            // and the result reads it as it stands when the loop ends.
            activation.cells[round] = .value(.record(Record(layout: LoweredRecord.round.layout, values: [.int(index)])))

            guard try bool(try await evaluate(condition, in: &activation, at: trace)) else {
                guard let result = body.result else { return .null }

                return try await evaluate(result, in: &activation, at: trace)
            }

            // What the last finished round bound is what the result reads. A
            // round cut short is put back to that, where the link said the
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
        _ body: Body,
        rescue: Body,
        failure: Int,
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

            await observer?.failureRescued(name: activation.frame.names[failure].spelling, error: error)

            // While the rescue runs, the failure is a value under the declared
            // name. Its type needs no check here: `RecoverableFailure`
            // assembles the payload itself, so `type` and `message` are there
            // by construction rather than by inspection.
            activation.cells[failure] = .value(recoverable.payload)

            return try await run(rescue, in: &activation, at: trace)
        }
    }

    // The frame a row runs in, with the module variables it reads in place.
    private func activation(of callee: Linked, in frame: Frame) throws -> Activation {
        var activation = Activation(frame, of: callee.origin)

        guard !frame.variables.isEmpty else { return activation }

        guard boxes.indices.contains(callee.origin) else {
            throw ExecutionError("'\(callee.label)' reads its document's variables, and this run holds none")
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
                    "'\(callee.label)' takes '\(callee.slots[handed.position].name)' in place,"
                        + " and '\(activation.frame.names[handed.address.slot])' is not a variable here"
                )
            }

            return (handed.position, handle.extended(by: try positioned(handed.address, in: activation)))
        }
    }

    // The receiver a call wrote in front, settled against what the parameter
    // naming it declares. Nil where the call wrote none.
    // Which row answers a call through a contract, and the receiver it answers
    // about. The name the value wears is the whole of the choosing: the link
    // gathered every type that answers this procedure and lowered a call for each,
    // so nothing is resolved here.
    private func picked(
        _ dispatch: DispatchOperation,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> (CallOperation, Value) {
        let receiver = try await evaluate(dispatch.receiver, in: &activation, at: trace)

        guard let name = receiver.nominal, let call = dispatch.calls[name] else {
            throw ExecutionError(
                "'\(dispatch.contract).\(dispatch.procedure)' is sent to"
                    + " \(receiver.nominal.map { held in "'\(held)'" } ?? "\(receiver.type)"),"
                    + " which answers no procedure of '\(dispatch.contract)'"
            )
        }

        return (call, receiver)
    }

    private func received(
        _ call: CallOperation,
        of callee: Linked,
        handed: Value?,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value? {
        // A dispatch read the receiver to pick this row, so what it read is
        // what the row is sent. Reading the operand again would run whatever
        // produced it a second time.
        if let handed { return try callee.settling(receiver: handed) }

        guard let receiver = call.receiver else { return nil }

        do {
            return try callee.settling(receiver: try await evaluate(receiver, in: &activation, at: trace))
        } catch let unfit as ReferenceUnfit {
            throw unfit
        } catch {
            // A refusal about the receiver is answerable only if the author can
            // see which name held it: the locus is the receiver's path when it
            // has one, and nothing to add when it does not.
            guard case let .local(address) = receiver else { throw error }

            throw ReferenceUnfit(path: spelled(address, in: activation), reason: "\(error)")
        }
    }

    // The positions a call fills another way: the receiver where the call
    // wrote one in front, and the ones handed in place where the callee
    // takes holds. A const body takes no hold, so what it was handed is
    // settled as a value.
    // A dispatch read the receiver to pick the row, so the row's call carries
    // none of its own and the value arrives beside it. Either way the slot is
    // filled, and either way it is not filled from the arguments.
    private func skipped(
        _ call: CallOperation,
        of callee: Linked,
        holding: Bool,
        receiving handed: Value? = nil
    ) -> Skipped {
        Skipped(
            handed: holding ? call.handed : [],
            receiver: call.receiver == nil && handed == nil ? nil : callee.receiverPosition
        )
    }

    private struct Skipped {
        let handed: [CallOperation.Handed]
        let receiver: Int?

        func contains(_ position: Int) -> Bool {
            position == receiver || handed.contains { handed in handed.position == position }
        }
    }

    // The arguments settled against the declaration, in parameter order: the
    // signature's own boundary, over the order the row keeps. The values are
    // born beside the row they were settled by, so nothing else pairs them.
    private func settled(
        _ callee: Linked,
        given: [Value?],
        skipping: Skipped
    ) throws -> Settled {
        Settled(values: try callee.settle(given, skipping: skipping.contains))
    }

    // Every argument an operand wrote, in the order the row reads them. A loop
    // rather than a map, since reading one may run what produced it.
    private func given(
        _ arguments: [Operation?],
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> [Value?] {
        var given: [Value?] = []
        given.reserveCapacity(arguments.count)

        for argument in arguments {
            guard let argument else {
                given.append(nil)
                continue
            }

            given.append(try await evaluate(argument, in: &activation, at: trace))
        }

        return given
    }

    // What a row answers where a caller reads it as data. A query answers
    // through its own door and a body the link proved answers without running
    // is run here, on a frame of its own.
    private func answer(
        _ callee: Linked,
        for receiver: Value?,
        with arguments: Settled,
        at trace: Trace
    ) async throws -> Value {
        let sent = sent(to: callee, receiver: receiver, arguments: arguments)

        switch callee.implementation {
        case let .native(.query(query)):
            return try await evaluate(query, of: callee, receiver: sent, settled: arguments) ?? .null

        case let .body(body, frame):
            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: arguments,
                receiver: sent,
                holding: [],
                at: trace
            )

        case .native(.effect):
            throw ExecutionError(
                "this answers only by running, so it cannot be read as data here"
            )
        }
    }

    // What a call was sent to. A receiver is a parameter, so it reaches a
    // native the same way whether it was written on the other side of the
    // dot or by its own name: the two spellings are one call.
    private func sent(to callee: Linked, receiver: Value?, arguments: Settled) -> Value? {
        receiver ?? callee.receiverPosition.flatMap { position in arguments.values[position] }
    }

    // Running a closure here rather than in `evaluate`, which is what makes a
    // procedure able to take one. What may be called is what the link proved
    // answers, and a slot declaring `const procedure` is how a procedure says so.
    func call(
        _ closure: Closure,
        with arguments: [(name: Name, value: Value)],
        at trace: Trace = Trace()
    ) async throws -> Value {
        try await answer(closure, given: arguments, at: trace)
    }

    private func bool(_ value: Value) throws -> Bool {
        guard case let .bool(answer) = value else {
            throw ExecutionError("a condition must answer bool, got \(value.type)")
        }

        return answer
    }

    // What a slot path holds. The head is never absent, since every slot is
    // there from the frame's making; a hold whose scope changed under
    // it refuses, and every deeper absence is answered inside the walk.
    private func found(_ address: Address, in activation: Activation) throws -> Value {
        switch lookup(address, in: activation) {
        case let .found(value):
            return value

        case let .unfit(reason):
            throw ReferenceUnfit(path: spelled(address, in: activation), reason: reason)
        }
    }

    // The two doors a native procedure answers through. The procedure's parameters are
    // its own type, so the call is made where that type has a name: handing
    // `any Query` to a generic function opens it.
    private func evaluate<W: Query>(
        _ query: W,
        of callee: Linked,
        receiver: Value?,
        settled: Settled
    ) async throws -> Value? {
        try await query.evaluate(
            Question(
                receiver: nothingIfNull(receiver),
                settled: settled,
                sends: callee.sends,
                from: callee.origin,
                executor: self
            )
        )
    }

    private func run<W: Effect>(
        _ effect: W,
        of callee: Linked,
        receiver: Value?,
        settled: Settled,
        holds: [(position: Int, handle: Handle)],
        trace: Trace
    ) async throws -> Value {
        try await effect.run(
            Invocation(
                selector: callee.label,
                signature: callee.signature,
                receiver: nothingIfNull(receiver),
                settled: settled,
                holds: holds,
                sends: callee.sends,
                from: callee.origin,
                trace: trace,
                executor: self
            )
        )
    }

    // What a native procedure reads as what it was sent to. Null is being sent to
    // nothing said as a value rather than by leaving it out, and a procedure
    // decides for itself what being sent to nothing means, so both doors answer
    // nothing and no procedure asks the question twice.
    private func nothingIfNull(_ receiver: Value?) -> Value? {
        receiver == .null ? nil : receiver
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

    // Sending a procedure a procedure declared it sends. The row the send reaches is
    // numbered by the sender's document, the same as one written in a body, and
    // the arguments arrive at the places the build worked out.
    //
    // A procedure may hand over fewer than the callee declares, and a place it
    // never handed is a place nothing was given for. Which is the one thing
    // absence means at any boundary.
    func send(
        _ sending: Sent,
        from origin: Int,
        to receiver: Value?,
        handing values: [Value],
        at trace: Trace
    ) async throws -> Value {
        let callee = linked[try row(sending.row, from: origin)]
        let sentTo = try received(receiver, of: callee)
        let settled = try settled(callee, to: sentTo, sending: sending, handing: values)

        switch callee.implementation {
        case .native(.query):
            return try await answer(callee, for: sentTo, with: settled, at: trace)

        case let .native(.effect(effect)):
            return try await run(
                effect,
                of: callee,
                receiver: sent(to: callee, receiver: sentTo, arguments: settled),
                settled: settled,
                holds: [],
                trace: trace.appending(.procedure(callee.label.spelling))
            )

        case let .body(body, frame):
            var inner = try activation(of: callee, in: frame)

            if let position = callee.receiverPosition, let sentTo {
                inner.cells[frame.parameters[position]] = .value(sentTo)
            }

            for (position, value) in settled.values.enumerated() {
                guard let value else { continue }

                inner.cells[frame.parameters[position]] = .value(value)
            }

            return try await answer(
                body,
                of: callee,
                in: &inner,
                at: trace.appending(.procedure(callee.label.spelling))
            )
        }
    }

    // The same send, where the sender answers without running. The link
    // refused a query sending anything that runs, so what reaches here answers
    // as data.
    func send(
        _ sending: Sent,
        from origin: Int,
        to receiver: Value?,
        handing values: [Value]
    ) async throws -> Value {
        let callee = linked[try row(sending.row, from: origin)]

        guard callee.constness == .const else {
            throw ExecutionError(
                "'\(callee.label)' answers only by running, so it cannot be"
                    + " read as data here"
            )
        }

        let sentTo = try received(receiver, of: callee)

        return try await answer(
            callee,
            for: sentTo,
            with: try settled(callee, to: sentTo, sending: sending, handing: values),
            at: Trace()
        )
    }

    // The receiver of a send, over the callee's boundary. A call written in a
    // document goes through `received(_:of:handed:in:)`; a send a procedure
    // declared comes through here, and the two hold a value that does not fit
    // to the same thing.
    //
    // Whether a send carries one at all is the sending body's, so a procedure
    // declaring nothing to be sent to is refused here rather than handed a
    // value it has no name for.
    private func received(_ receiver: Value?, of callee: Linked) throws -> Value? {
        guard let receiver else { return nil }

        // Null is being sent to nothing said as a value, so it reaches a
        // procedure that declares nothing to be sent to without contradicting
        // it. What a native procedure then reads is the door's to settle.
        guard callee.receiverPosition != nil || receiver == .null else {
            throw ExecutionError(
                "'\(callee.label)' is sent to something, and it"
                    + " \(BuildError.receivesByNoName)"
            )
        }

        return try callee.settling(receiver: receiver)
    }

    // A send's arguments over the callee's boundary. The build read where each
    // handed value goes, so the pairing is made here from the send itself and
    // the values the sender built.
    //
    // A place nothing was handed at answers nil, which is what tells the
    // boundary nothing was given there.
    private func settled(
        _ callee: Linked,
        to receiver: Value?,
        sending: Sent,
        handing values: [Value]
    ) throws -> Settled {
        // How many a Swift body builds is the body's, so this is the one thing
        // about a send the build cannot read.
        guard values.count == sending.offers.count else {
            throw ExecutionError(
                "'\(callee.label)' is handed \(values.count) here, and the procedure sending"
                    + " it declares it hands \(sending.offers.count)"
            )
        }

        var given: [Value?] = Array(repeating: nil, count: callee.slots.count)

        for (position, value) in zip(sending.offers, values) {
            // A row taking fewer parameters than the build read them off is a
            // row this send was not compiled against.
            guard given.indices.contains(position) else {
                throw ExecutionError(
                    "'\(callee.label)' takes \(callee.slots.count) parameters, and this send"
                        + " stands something at \(position)"
                )
            }

            // Sending to something fills the slot it is sent to, so a value
            // handed under that name is a second instruction for one place. A
            // document writes its receiver in front of the selector and a
            // procedure sends to one, so the two spell it differently and
            // refuse the same thing.
            guard receiver == nil || position != callee.receiverPosition else {
                throw ExecutionError(
                    "'\(callee.slots[position].name)' sent to '\(callee.label)' both as what"
                        + " it is sent to and by name"
                )
            }

            given[position] = value
        }

        return Settled(
            values: try callee.settle(
                given,
                skipping: { position in receiver != nil && position == callee.receiverPosition }
            )
        )
    }

    // Where a walk over a path came down: on a value, or on a reading gone
    // wrong. Every slot is there from the frame's making, so there is no
    // third answer.
    private enum Walk {
        case found(Value)
        case unfit(String)
    }

    // A dot reads a name and nothing else, and the link judged every one and
    // wrote the judgment into the step. What may genuinely be absent, a missing
    // entry or a null on the way, is read as null only where the author spelled
    // `?.`, and refused everywhere else.
    private func lookup(_ address: Address, in activation: Activation) -> Walk {
        let (slot, steps) = (address.slot, address.steps)
        var current: Value

        do {
            current = try activation.cells[slot].value()
        } catch {
            return .unfit("\(error)")
        }

        for (index, step) in steps.enumerated() {
            // The path as far as this step, spelled for a refusal. Only a
            // refusal reads it, so a read that lands spells nothing.
            func walked() -> [PathSegment] {
                spelled(Address(slot: slot, steps: Array(steps[...index])), in: activation)
            }

            // This step alone, spelled the same way and for the same reader.
            func segment() -> PathSegment {
                spelled(step, in: activation)
            }

            // Null stops every reading the same way, and the rule lives with
            // the segment: the link's walk over types asks the same judge, so
            // the two layers cannot drift apart.
            if current == .null {
                switch segment().meetingNull(at: walked()) {
                case .reads:
                    return .found(.null)

                case let .refused(reason):
                    return .unfit(reason)
                }
            }

            let read: Walk

            switch step {
            case let .index(index, _):
                read = indexed(current, at: index, walked: walked)

            // The name is a path of its own, read against the same frame.
            case let .at(inner, optional):
                func name() -> String {
                    spelled(inner, in: activation).rendered
                }

                switch lookup(inner, in: activation) {
                case let .found(.int(index)):
                    read = indexed(current, at: index, walked: walked)

                // A dictionary's names are data, so a key the run settled
                // reads an entry the way a written key does.
                case let .found(.string(key)):
                    read = keyed(
                        current,
                        at: key,
                        optional: optional,
                        walked: walked,
                        segment: segment
                    )

                case let .found(.double(double)):
                    switch Int.reading(double) {
                    case let .int(index):
                        read = indexed(current, at: index, walked: walked)

                    case .notANumber, .fractional:
                        return .unfit("index reference \(name()) is not a whole number")

                    case .overflow:
                        return .unfit(
                            "index reference \(name()) indexes past the end of any array"
                        )
                    }

                case let .found(value):
                    return .unfit(
                        "index reference \(name()) is \(value.type), expected int or string"
                    )

                case let .unfit(reason):
                    return .unfit(reason)
                }

            // The place the link proved, held to the name beside it. Two
            // grounds for one field would let a writing say one of them and
            // mean the other, and what came back then would not be refused
            // but wrong. The name is what a write lands on, so the read is
            // held to it here.
            case let .field(position, name, _):
                guard case let .record(record) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard record.layout.fields.indices.contains(position),
                      record.layout.fields[position] == name
                else {
                    return .unfit(
                        "\(walked().rendered) drills to a field this record"
                            + " names otherwise"
                    )
                }

                read = .found(record.values[position])

            case let .key(key, optional):
                guard current.holdsFields else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard let next = current[key] else {
                    guard optional else {
                        return .unfit(
                            "\(walked().rendered): '\(key)' is not there."
                                + " Only `\(segment().mark)` reads absence"
                        )
                    }

                    return .found(.null)
                }

                read = .found(next)
            }

            switch read {
            case let .found(value):
                current = value

            case .unfit:
                return read
            }
        }

        return .found(current)
    }

    // One reading for both index spellings. What is indexed is whatever has
    // elements: the projection owns the `array<byte>` equation, lazily, so
    // one element read does not unpack a compact spelling. Past the end is a
    // defect, not absence: the array is there and says how long it is.
    private func indexed(_ current: Value, at index: Int, walked: () -> [PathSegment]) -> Walk {
        guard let elements = current.elements else {
            return .unfit("\(walked().rendered) indexes into \(current.type), expected array")
        }

        guard index >= 0, index < elements.count else {
            return .unfit(
                "\(walked().rendered) indexes past the end of \(elements.count) element(s)"
            )
        }

        return .found(elements[elements.index(elements.startIndex, offsetBy: index)])
    }

    // One reading for a key the run settled. What is keyed is whatever holds
    // fields, and an absent entry follows the mark the way a written key does.
    private func keyed(
        _ current: Value,
        at key: String,
        optional: Bool,
        walked: () -> [PathSegment],
        segment: () -> PathSegment
    ) -> Walk {
        guard current.holdsFields else {
            return .unfit("\(walked().rendered) drills a field into \(current.type)")
        }

        guard let name = try? Name(key) else {
            return .unfit("\(walked().rendered) reads '\(key)', which is not a name")
        }

        guard let next = current[name] else {
            guard optional else {
                return .unfit(
                    "\(walked().rendered): '\(key)' is not there."
                        + " Only `\(segment().mark)` reads absence"
                )
            }

            return .found(.null)
        }

        return .found(next)
    }

    // Every index reference read to a position: a write lands on one
    // position, and a hold is extended by positions.
    private func positioned(_ address: Address, in activation: Activation) throws -> [PathSegment] {
        try address.steps.map { step in
            switch step {
            case let .field(_, name, optional), let .key(name, optional):
                return .key(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .at(inner, optional):
                guard case let .int(index) = try found(inner, in: activation) else {
                    throw ExecutionError(
                        "'\(spelled(address, in: activation).rendered)' indexes with"
                            + " '\(spelled(inner, in: activation).rendered)', which is not an int"
                    )
                }

                return .index(index, optional: optional)
            }
        }
    }

    // The path as the author wrote it, for a sentence that reads it back.
    private func spelled(_ address: Address, in activation: Activation) -> [PathSegment] {
        [.key(activation.frame.names[address.slot])] + spelled(address.steps, in: activation)
    }

    private func spelled(_ steps: [Step], in activation: Activation) -> [PathSegment] {
        steps.map { step in spelled(step, in: activation) }
    }

    private func spelled(_ step: Step, in activation: Activation) -> PathSegment {
        switch step {
        case let .field(_, name, optional), let .key(name, optional):
            return .key(name, optional: optional)

        case let .index(index, optional):
            return .index(index, optional: optional)

        case let .at(inner, optional):
            return .indexRef(spelled(inner, in: activation), optional: optional)
        }
    }
}
