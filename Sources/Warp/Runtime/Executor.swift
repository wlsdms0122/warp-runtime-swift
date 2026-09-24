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

    // What a closure the run makes is spelled with, by the origin its row
    // says.
    let naming: [Closure.Document]

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
        self.init(observer: observer, environment: environment, linked: [], resolving: .rows, naming: [])
    }

    // Seeded, and not public: the table is the link's answer, so a caller
    // that could write it would be running a program nothing linked.
    init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        linked: [Linked],
        resolving: Resolving,
        naming: [Closure.Document],
        loweredTypes: LoweredTypeTable = .empty,
        boxes: [[Handle]] = []
    ) {
        self.observer = observer
        self.environment = environment
        self.linked = linked
        self.resolving = resolving
        self.naming = naming
        self.loweredTypes = loweredTypes
        self.boxes = boxes
    }

    // MARK: - Public
    // Running takes an image, not a procedure, so "ran something that was never
    // linked" is not a state this type can be put in. Which declaration it
    // starts from is named here: an image is every declaration the link
    // judged, and a run starts from any public one. There is no default,
    // since guessing which procedure was meant would be an opinion nobody
    // gave.
    public func run(
        _ image: Image,
        entry: Name,
        arguments: [Name: Value] = [:]
    ) async throws -> Value {
        // A name is its declared spelling and nothing else, so the entry is
        // looked up as the caller wrote it.
        guard let start = image.rows[entry] else {
            // A spelling only a private declaration wears is declared, and by
            // nothing the caller may name.
            guard !image.concealed.contains(entry) else {
                throw ExecutionError(
                    "entry '\(entry)' is private to the document that declares it, and a run"
                        + " starts only from a public declaration"
                )
            }

            throw ExecutionError(
                "entry '\(entry)' is not declared by any module in this link."
                    + " A name is its declared spelling. Declared:"
                    + " \(image.rows.keys.sorted().map(\.spelling).joined(separator: ", "))"
            )
        }

        let entry = image.linked[start]

        // A run starts from outside the link, and only a public declaration
        // is named from there.
        guard entry.access.reachesCaller else {
            throw ExecutionError(
                "entry '\(entry.label)' is \(entry.access.rawValue), and a run starts"
                    + " only from a public declaration"
            )
        }

        let executor = Executor(
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
        guard case let .body(body, frame) = entry.implementation else {
            throw ExecutionError("a run starts from a body, and this declaration is native")
        }

        let settled = try entry.settle(arguments)
        var activation = try executor.activation(of: entry, in: frame)

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return try await executor.answer(body, of: entry, in: &activation, at: Trace())
    }

    // MARK: - Internal
    // Calling a closure a procedure holds. The arguments are handed by
    // position, every position given, and settle against the closure's own
    // declaration the way a written application's do.
    func call(
        _ closure: Closure,
        handing arguments: [Value],
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
            let row = linked[try self.row(number, from: activation.origin)]

            guard let nth = row.nth else {
                throw ExecutionError("a closure stands on a row no declaration wrote")
            }

            guard naming.indices.contains(row.origin) else {
                throw ExecutionError("a closure stands in a document this run was not told of")
            }

            return .procedure(
                Closure(
                    writer: Closure.Writer(document: naming[row.origin], name: row.label),
                    nth: nth,
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
            let (call, first) = try await picked(dispatch, in: &activation, at: trace)

            return try await self.call(call, first: first, in: &activation, at: trace)

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
        let callee = linked[try row(call.procedure, from: activation.origin)]

        switch callee.implementation {
        // A query answers without running, so the const half is the whole
        // implementation.
        case .native(.query):
            // A variable handed in place is read as what it holds now and
            // settled the way any argument is, since nothing here writes it.
            var values = try await given(call.arguments, first: first, in: &activation, at: trace)

            for handed in call.handed {
                values[handed.position] = try found(handed.address, in: activation)
            }

            return try await answer(callee, with: try settled(callee, given: values), at: trace)

        case let .native(.effect(effect)):
            let holds = try holds(call.handed, of: callee, in: activation)
            let settled = try settled(
                callee,
                given: try await given(call.arguments, first: first, in: &activation, at: trace),
                holding: call.handed
            )

            return try await run(effect, of: callee, settled: settled, holds: holds, trace: trace)

        case let .body(body, frame):
            let holds = try holds(call.handed, of: callee, in: activation)
            let settled = try settled(
                callee,
                given: try await given(call.arguments, first: first, in: &activation, at: trace),
                holding: call.handed
            )

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
    private func apply(
        _ callee: Operation,
        arguments: [Operation],
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let value = try await evaluate(callee, in: &activation, at: trace)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.type), and only a procedure can be called"
            )
        }

        // A value carries no names, so the arguments travel by position, in
        // the order they were written, and land in the slots in that order.
        var given: [Value] = []

        for argument in arguments {
            given.append(try await evaluate(argument, in: &activation, at: trace))
        }

        return try await answer(closure, given: given, at: trace)
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
        given arguments: [Value],
        at trace: Trace
    ) async throws -> Value {
        let linked = try closure.answered()

        guard case let .body(body, frame) = linked.implementation else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        // Its rows are numbered by the table of the link that made it.
        guard linked.readable(in: loweredTypes) else {
            throw ExecutionError("this call \(Linked.unreadable)")
        }

        let settled = try linked.settle(applied: arguments)
        var activation = try self.activation(of: linked, in: frame)

        for (slot, cell) in closure.captured {
            activation.cells[slot] = cell
        }

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return try await answer(
            body,
            of: linked,
            in: &activation,
            at: trace.appending(linked.hop)
        )
    }

    // The one way a written procedure is called: its frame, the settled
    // arguments in their slots, whatever the call handed in place held as a
    // box, and the body answered in that frame.
    private func answer(
        _ callee: Linked,
        running body: Body,
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

        return try await answer(body, of: callee, in: &activation, at: trace)
    }

    private func loop(
        while condition: Operation,
        body: Body,
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
                activation.cells[round] = .value(.record(Record(layout: LoweredRecord.round.layout, values: [.int(index)])))
            }

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

            await observer?.failureRescued(
                name: failure.map { failure in activation.frame.names[failure].spelling },
                error: error
            )

            // While the rescue runs, the failure is a value under the declared
            // name, where the attempt bound one. Its type needs no check here:
            // `RecoverableFailure` assembles the payload itself, so `type` and
            // `message` are there by construction rather than by inspection.
            if let failure {
                activation.cells[failure] = .value(recoverable.payload)
            }

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

            return (handed.position, handle.extended(by: try positioned(handed.address, in: activation)))
        }
    }

    // Which row answers a call through a contract, and the value it answers
    // about. The name the first argument wears is the whole of the choosing:
    // the link gathered every type that answers this procedure and lowered a
    // call for each, so nothing is resolved here.
    private func picked(
        _ dispatch: DispatchOperation,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> (CallOperation, Value) {
        let first = try await evaluate(dispatch.first, in: &activation, at: trace)

        guard let name = first.nominal, let call = dispatch.calls[name] else {
            throw ExecutionError(
                "'\(dispatch.contract).\(dispatch.procedure)' is sent to"
                    + " \(first.nominal.map { held in "'\(held)'" } ?? "\(first.type)"),"
                    + " which answers no procedure of '\(dispatch.contract)'"
            )
        }

        return (call, first)
    }

    // The arguments settled against the declaration, in parameter order: the
    // signature's own boundary, over the order the row keeps. A position
    // handed in place is filled with a hold rather than a value, so the
    // boundary leaves it to the hold. The values are born beside the row they
    // were settled by, so nothing else pairs them.
    private func settled(
        _ callee: Linked,
        given: [Value?],
        holding handed: [CallOperation.Handed] = []
    ) throws -> Settled {
        Settled(values: try callee.settle(given) { position in
            handed.contains { handed in handed.position == position }
        })
    }

    // Every argument a call wrote, in position order. A loop rather than a
    // map, since reading one may run what produced it. A dispatch read the
    // first to pick the row, so what it read stands there rather than a
    // second reading of the same operand.
    private func given(
        _ arguments: [Operation?],
        first: Value? = nil,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> [Value?] {
        var given: [Value?] = []
        given.reserveCapacity(arguments.count)

        for (position, argument) in arguments.enumerated() {
            if position == 0, let first {
                given.append(first)
                continue
            }

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
        with arguments: Settled,
        at trace: Trace
    ) async throws -> Value {
        switch callee.implementation {
        case let .native(.query(query)):
            return try await evaluate(query, of: callee, settled: arguments) ?? .null

        case let .body(body, frame):
            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: arguments,
                holding: [],
                at: trace
            )

        case .native(.effect):
            throw ExecutionError(
                "this answers only by running, so it cannot be read as data here"
            )
        }
    }

    // Running a closure here rather than in `evaluate`, which is what makes a
    // procedure able to take one. What may be called is what the link proved
    // answers, and a slot declaring `const procedure` is how a procedure says so.
    func call(
        _ closure: Closure,
        with arguments: [Value],
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
        settled: Settled
    ) async throws -> Value? {
        try await query.evaluate(
            Question(
                settled: settled,
                of: callee,
                executor: self
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
        try await effect.run(
            Invocation(
                of: callee,
                settled: settled,
                holds: holds,
                trace: trace,
                executor: self
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
        let settled = try settled(callee, sending: sending, handing: values)

        switch callee.implementation {
        case .native(.query):
            return try await answer(callee, with: settled, at: trace)

        case let .native(.effect(effect)):
            return try await run(
                effect,
                of: callee,
                settled: settled,
                holds: [],
                trace: trace.appending(callee.hop)
            )

        case let .body(body, frame):
            return try await answer(
                callee,
                running: body,
                in: frame,
                settled: settled,
                holding: [],
                at: trace.appending(callee.hop)
            )
        }
    }

    // The same send, where the sender answers without running. The link
    // refused a query sending anything that runs, so what reaches here answers
    // as data.
    func send(
        _ sending: Sent,
        from origin: Int,
        handing values: [Value]
    ) async throws -> Value {
        let callee = linked[try row(sending.row, from: origin)]

        guard callee.constness == .const else {
            throw ExecutionError(
                "'\(callee.rendered)' answers only by running, so it cannot be"
                    + " read as data here"
            )
        }

        return try await answer(
            callee,
            with: try settled(callee, sending: sending, handing: values),
            at: Trace()
        )
    }

    // A send's arguments over the callee's boundary, standing at its
    // positions.
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

        return Settled(values: try callee.settle(applied: values))
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

            // The place the link proved, which is where a write lands too.
            case let .field(position, _, _):
                guard case let .record(record) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard record.values.indices.contains(position) else {
                    return .unfit("\(walked().rendered) drills past the fields this record holds")
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
    private func positioned(_ address: Address, in activation: Activation) throws -> [Projection] {
        try address.steps.map { step in
            switch step {
            case let .field(position, name, _):
                return .field(position, name)

            case let .key(name, _):
                return .key(name)

            case let .index(index, _):
                return .index(index)

            case let .at(inner, _):
                guard case let .int(index) = try found(inner, in: activation) else {
                    throw ExecutionError(
                        "'\(spelled(address, in: activation).rendered)' indexes with"
                            + " '\(spelled(inner, in: activation).rendered)', which is not an int"
                    )
                }

                return .index(index)
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
