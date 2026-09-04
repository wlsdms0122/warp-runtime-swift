//
//  Executor.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Runs an image. Two halves over one code: `read` answers what answers
// without running, synchronously, which is what a condition, an argument, a
// pure body and a word handed a procedure need; `evaluate` runs constructs,
// effects and calls of values, and hands every data case to `read`.
public struct Executor: Sendable {
    // MARK: - Property
    public let observer: (any ExecutionObserver)?
    public let environment: (any Environment)?

    // The linked table, seeded from the image this run was given. Empty
    // until then, which is why nothing but `run(_ image:)` can start a run.
    let linked: [Linked]

    // The shapes the link declared, by row. Every boundary that settles a
    // value reads it.
    let shapes: ShapeTable

    // One box per module variable, made when the run starts, by the document
    // that declared it, in the order its frame reads them.
    let boxes: [Int: [Handle]]

    // MARK: - Initializer
    // What a caller has to say to make one: who watches, and what the run may
    // reach outside itself. The table comes from an image, so this is an
    // executor with nothing to run yet.
    public init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil
    ) {
        self.init(observer: observer, environment: environment, linked: [])
    }

    // Seeded, and not public: the table is the link's answer, so a caller
    // that could write it would be running a program nothing linked.
    init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        linked: [Linked],
        shapes: ShapeTable = .empty,
        boxes: [Int: [Handle]] = [:]
    ) {
        self.observer = observer
        self.environment = environment
        self.linked = linked
        self.shapes = shapes
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
            shapes: image.shapes,
            boxes: image.variables.mapValues { started in
                started.map { name, value in Handle(name, value) }
            }
        )
        let entry = image.entry

        guard case let .body(body, frame) = entry.implementation else {
            throw ExecutionError("a run starts from a body, and this declaration is native")
        }

        let settled = try entry.settle(arguments.map { name, value in (name: name, value: value) }, offered: false)
        var activation = try executor.activation(of: entry, in: frame)

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return try await executor.answer(body, of: entry, in: &activation, at: Trace())
    }

    // MARK: - Internal
    // Calling a closure a word holds. Arguments are offered rather than
    // settled strictly: the word decides what it has to give, and which of
    // those the closure's author wanted is the author's business.
    func call(
        _ closure: Closure,
        offering arguments: [(name: Name, value: Value)],
        at trace: Trace
    ) async throws -> Value {
        var (body, activation) = try enter(closure, given: arguments, offered: true)

        return try await answer(body, of: closure.linked, in: &activation, at: trace)
    }

    // The synchronous reading of one code against one frame: the half of the
    // language that answers without running.
    func read(_ code: Code, in activation: Activation) throws -> Value {
        switch code {
        case let .literal(value):
            return value

        case let .local(slot, steps):
            return try found(slot, steps, in: activation)

        case let .array(elements):
            return .array(try elements.map { element in try read(element, in: activation) })

        // The link ordered the fields by name, so the record is made as it is.
        case let .record(fields):
            return .record(
                Record(name: nil, ordered: try fields.map { name, field in (name: name, value: try read(field, in: activation)) })
            )

        // Making a closure runs nothing: it is the capture, and the capture is
        // these cells. Which is why it belongs to the pure half and a
        // condition may hand one to a word.
        case let .closure(row, captures):
            return .procedure(
                Closure(
                    linked: row,
                    captured: captures.map { outer, inner in (slot: inner, cell: activation.cells[outer]) }
                )
            )

        // Judging a value against a shape runs nothing, so a cast is data the
        // pure half can read.
        case let .cast(value, shape, optional):
            return try shape.reading(try read(value, in: activation), optional: optional, in: shapes)

        case let .send(send):
            return try self.send(send, in: activation)

        // Running a body or reaching outside is async and may fail in a way an
        // attempt can catch, so it belongs to `evaluate`. Reaching here means
        // a construct was written where only data can be read: inside a
        // condition, or among an effect's settled arguments.
        case .invoke, .block, .conditional, .loop, .iteration, .attempt, .leave:
            throw ExecutionError("this expression runs, so it cannot be read as data here")
        }
    }

    // MARK: - Private
    // A body run as a procedure: what it answers is caught here, and what it
    // answers is settled against what it declared.
    //
    // Both halves are the frame, and neither works without the other, so there
    // is one of these rather than one per way of reaching a body. There are
    // three ways: a run starting here, a word whose implementation is written,
    // and a closure being invoked.
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
            case let .bind(slot)?:
                activation.cells[slot] = .value(result)

            // A new box, so a variable declared inside a block shadows rather
            // than writes an outer one of the same name.
            case let .declare(slot)?:
                activation.cells[slot] = .hold(Handle(activation.frame.names[slot], result))

            // A write lands in a box the enclosing bodies also hold.
            case let .assign(slot, steps)?:
                guard case let .hold(handle) = activation.cells[slot] else {
                    throw ExecutionError(
                        "'\(spelled(slot, steps, in: activation).rendered)' writes a name that is not a variable here"
                    )
                }

                try handle.write(result, at: try positioned(slot, steps, in: activation))

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
        _ code: Code,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        switch code {
        case .literal, .local, .closure:
            return try read(code, in: activation)

        case let .array(elements):
            var values: [Value] = []

            for element in elements {
                values.append(try await evaluate(element, in: &activation, at: trace))
            }

            return .array(values)

        case let .record(fields):
            var values: [(name: Name, value: Value)] = []
            values.reserveCapacity(fields.count)

            for (name, field) in fields {
                values.append((name: name, value: try await evaluate(field, in: &activation, at: trace)))
            }

            return .record(Record(name: nil, ordered: values))

        // The run's whole share of a cast: the link already decided what every
        // dot after this means, and the one thing it could not know is what
        // actually arrived. A plain cast lets the refusal out as a failure like
        // any other; an optional one reads the mismatch as null, which is the
        // author saying they expected it.
        case let .cast(value, shape, optional):
            return try shape.reading(
                await evaluate(value, in: &activation, at: trace),
                optional: optional,
                in: shapes
            )

        case let .send(send):
            return try await self.send(send, in: &activation, at: trace)

        case let .invoke(callee, arguments):
            return try await invoke(callee, arguments: arguments, in: &activation, at: trace)

        case let .block(body):
            return try await run(body, in: &activation, at: trace)

        // A branch answers nothing: the condition chooses a way through the
        // body, and what an arm keeps it writes to an outer variable.
        case let .conditional(condition, then, otherwise):
            let take = try bool(try read(condition, in: activation))

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

        case let .iteration(material, body, element):
            return try await iterate(
                over: material,
                body: body,
                element: element,
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
    private func send(_ send: Send, in activation: inout Activation, at trace: Trace) async throws -> Value {
        let callee = linked[send.procedure]

        switch callee.implementation {
        // A query answers without running, so the pure half is the whole
        // implementation. It is here only so that `x.count` and the same
        // word written as a statement mean the same thing.
        case .query:
            return try self.send(send, in: activation)

        case let .effect(effect):
            let holds = try holds(send.handed, of: callee, in: activation)
            let settled = try settled(
                callee,
                given: try send.arguments.map { argument in try argument.map { try read($0, in: activation) } },
                skipping: skipped(send, of: callee, holding: true)
            )
            // A receiver handed in place is read for the effect as what its
            // hold holds now, the way the effect reads any receiver.
            let held = try holds.first { position, _ in position == callee.receiverPosition }.map { _, handle in try handle.value() }

            return try await effect.run(
                Invocation(
                    selector: callee.label,
                    signature: callee.signature,
                    receiver: sent(to: callee, receiver: try received(send, of: callee, in: activation) ?? held, arguments: settled),
                    settled: settled,
                    holds: holds,
                    trace: trace,
                    executor: self
                )
            )

        case let .body(body, frame):
            var inner = try self.activation(of: callee, in: frame)

            // A parameter handed in place takes no value: it takes a hold on
            // the caller's variable, and what the hold reaches is read only
            // where the body reads it.
            for (position, handle) in try holds(send.handed, of: callee, in: activation) {
                inner.cells[frame.parameters[position]] = .hold(handle)
            }

            // A receiver is written on the other side of the dot rather than by
            // name. It is not settled as an argument, since being sent to
            // nothing is something a word answers rather than refuses, but the
            // body reads it under the name its signature gave it.
            if let position = callee.receiverPosition, let receiver = try received(send, of: callee, in: activation) {
                inner.cells[frame.parameters[position]] = .value(receiver)
            }

            let settled = try settled(
                callee,
                given: try send.arguments.map { argument in try argument.map { try read($0, in: activation) } },
                skipping: skipped(send, of: callee, holding: true)
            )

            for (position, value) in settled.values.enumerated() {
                guard let value else { continue }

                inner.cells[frame.parameters[position]] = .value(value)
            }

            return try await answer(body, of: callee, in: &inner, at: trace.appending(.procedure(callee.label.spelling)))
        }
    }

    // Calling a value. The body runs in the cells the closure captured and not
    // in the caller's: that is what lexical scope means, and it is the reason a
    // closure is worth passing at all.
    private func invoke(
        _ callee: Code,
        arguments: [(Name, Code)],
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let value = try read(callee, in: activation)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.type), and only a procedure can be called"
            )
        }

        // The signature is the value's, so the arguments travel by name and
        // find their slots here, along the list.
        let resolved = try arguments.map { name, argument in (name: name, value: try read(argument, in: activation)) }

        var (body, inner) = try enter(closure, given: resolved, offered: false)

        return try await answer(body, of: closure.linked, in: &inner, at: trace)
    }

    // The one way a closure's frame is made: the arguments settled by the
    // closure's own row, the captured cells in their slots, the parameters
    // in theirs. The row is asked whether this run may read it before
    // anything reads its rows.
    private func enter(
        _ closure: Closure,
        given arguments: [(name: Name, value: Value)],
        offered: Bool
    ) throws -> (Body, Activation) {
        guard case let .body(body, frame) = closure.linked.implementation else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        // Its rows are numbered by the table of the link that made it.
        guard closure.linked.readable(in: shapes) else {
            throw ExecutionError("this call \(Linked.unreadable)")
        }

        let settled = try closure.linked.settle(arguments, offered: offered)
        var activation = try self.activation(of: closure.linked, in: frame)

        for (slot, cell) in closure.captured {
            activation.cells[slot] = cell
        }

        for (position, value) in settled.enumerated() {
            activation.cells[frame.parameters[position]] = .value(value ?? .null)
        }

        return (body, activation)
    }

    private func loop(
        while condition: Code,
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
            activation.cells[round] = .value(.record(Record(name: nil, ordered: [(name: "index", value: .int(index))])))

            guard try bool(try read(condition, in: activation)) else {
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

    private func iterate(
        over material: Code,
        body: [Instruction],
        element: Int,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> Value {
        let name = activation.frame.names[element]
        let elements = try await array(of: material, naming: name, in: &activation, at: trace)

        for (index, item) in elements.enumerated() {
            activation.cells[element] = .value(
                .record(Record(name: nil, ordered: [(name: "index", value: .int(index)), (name: "item", value: item)]))
            )

            do {
                try await perform(body, in: &activation, at: trace.appending(.round(index)))
            } catch let leaving as Leaving where leaving.claimed(by: name) {
                // A walk answers nothing, so ending one early ends it and no
                // more: what its rounds wrote outward is already written.
                guard leaving.reach == .round else { break }

                continue
            }
        }

        return .null
    }

    // The material both fan-out shapes walk. Whether the pieces run one after
    // another or all at once, what they walk has to be an array, and it fails to
    // be one in the same way.
    private func array(
        of material: Code,
        naming element: Name,
        in activation: inout Activation,
        at trace: Trace
    ) async throws -> AnyRandomAccessCollection<Value> {
        let resolved = try await evaluate(material, in: &activation, at: trace)

        // What is iterated is whatever has elements, the one projection that
        // owns the bytes equation, so `each` walks bytes the way an index
        // reads them.
        guard let elements = resolved.elements else {
            guard case let .local(slot, steps) = material else {
                throw ExecutionError(
                    "the material of iteration '\(element)' resolved to"
                        + " \(resolved.type), expected array"
                )
            }

            throw ReferenceUnfit(
                path: spelled(slot, steps, in: activation),
                reason: "iteration material is \(resolved.type), expected array"
            )
        }

        return elements
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
            // name. Its shape needs no check here: `RecoverableFailure`
            // assembles the payload itself, so `type` and `message` are there
            // by construction rather than by inspection.
            activation.cells[failure] = .value(recoverable.payload)

            return try await run(rescue, in: &activation, at: trace)
        }
    }

    // The frame a row runs in, with the module variables it reads in place.
    private func activation(of callee: Linked, in frame: Frame) throws -> Activation {
        var activation = Activation(frame)

        guard !frame.variables.isEmpty else { return activation }

        guard let held = boxes[callee.origin] else {
            throw ExecutionError("'\(callee.label)' reads its document's variables, and this run holds none")
        }

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
        _ handed: [Send.Handed],
        of callee: Linked,
        in activation: Activation
    ) throws -> [(position: Int, handle: Handle)] {
        try handed.map { handed in
            guard case let .hold(handle) = activation.cells[handed.slot] else {
                throw ExecutionError(
                    "'\(callee.label)' takes '\(callee.slots[handed.position].name)' in place,"
                        + " and '\(activation.frame.names[handed.slot])' is not a variable here"
                )
            }

            return (handed.position, handle.extended(by: try positioned(handed.slot, handed.path, in: activation)))
        }
    }

    // The receiver a call wrote in front, settled against what the parameter
    // naming it declares. Nil where the call wrote none.
    private func received(_ send: Send, of callee: Linked, in activation: Activation) throws -> Value? {
        guard let receiver = send.receiver else { return nil }

        do {
            return try callee.settling(receiver: try read(receiver, in: activation))
        } catch let unfit as ReferenceUnfit {
            throw unfit
        } catch {
            // A refusal about the receiver is answerable only if the author can
            // see which name held it: the locus is the receiver's path when it
            // has one, and nothing to add when it does not.
            guard case let .local(slot, steps) = receiver else { throw error }

            throw ReferenceUnfit(path: spelled(slot, steps, in: activation), reason: "\(error)")
        }
    }

    // The positions a call fills another way: the receiver where the call
    // wrote one in front, and the ones handed in place where the callee
    // takes holds. A pure body takes no hold, so what it was handed is
    // settled as a value.
    private func skipped(_ send: Send, of callee: Linked, holding: Bool) -> Skipped {
        Skipped(
            handed: holding ? send.handed : [],
            receiver: send.receiver == nil ? nil : callee.receiverPosition
        )
    }

    private struct Skipped {
        let handed: [Send.Handed]
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
        Settled(by: callee, values: try callee.settle(given, offered: false, skipping: skipping.contains))
    }

    // The pure half of a send. An effect or a body that runs answers only by
    // running, so a condition that names one is refused here rather than
    // quietly starting something in the middle of a comparison.
    private func send(_ send: Send, in activation: Activation) throws -> Value {
        let callee = linked[send.procedure]

        guard callee.purity == .pure else {
            throw ExecutionError(
                "'\(callee.label)' answers only by running, so it cannot be"
                    + " read as data here"
            )
        }

        let receiver = try received(send, of: callee, in: activation)
        var given = try send.arguments.map { argument in try argument.map { try read($0, in: activation) } }

        // A pure body writes nothing, so a variable handed to it in place is
        // read as what it holds, and settled the way any argument is.
        for handed in send.handed {
            given[handed.position] = try found(handed.slot, handed.path, in: activation)
        }

        let arguments = try settled(callee, given: given, skipping: skipped(send, of: callee, holding: false))

        do {
            return try answer(callee, for: receiver, with: arguments)
        } catch let unfit as ReferenceUnfit {
            throw unfit
        } catch {
            // A word blaming a shape is answerable only if the author can see
            // which name held it.
            guard case let .local(slot, steps)? = send.receiver else { throw error }

            throw ReferenceUnfit(path: spelled(slot, steps, in: activation), reason: "\(error)")
        }
    }

    // What a row answers, computed without running. Both shapes it can have
    // are answerable without suspending: one because it is native and says
    // so, the other because the link proved it.
    private func answer(_ callee: Linked, for receiver: Value?, with arguments: Settled) throws -> Value {
        let sent = sent(to: callee, receiver: receiver, arguments: arguments)

        switch callee.implementation {
        // Absent and null are the same fact, and a word asked about nothing
        // decides for itself what that means: `contains` says false rather
        // than failing.
        case let .query(query):
            return try query.evaluate(
                Question(
                    receiver: sent == .null ? nil : sent,
                    settled: arguments,
                    executor: self
                )
            ) ?? .null

        // A body the link proved pure runs here, synchronously. Nothing in it
        // can suspend, which is what the proof says.
        case let .body(body, frame):
            var activation = try self.activation(of: callee, in: frame)

            for (position, value) in arguments.values.enumerated() {
                guard let value else { continue }

                activation.cells[frame.parameters[position]] = .value(value)
            }

            if let position = callee.receiverPosition, let sent {
                activation.cells[frame.parameters[position]] = .value(sent)
            }

            return try callee.settling(returned: try read(body, in: &activation))

        case .effect:
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

    // A pure body, read without running. Instructions bind in order and the
    // body answers what it declares, the same rule `run` follows, over the
    // subset that cannot suspend.
    private func read(_ body: Body, in activation: inout Activation) throws -> Value {
        for instruction in body.instructions {
            switch instruction.binding {
            case .bind, nil:
                break

            case .declare, .assign:
                throw ExecutionError(
                    "'\(instruction.label)' writes a name, and what answers"
                        + " without running only binds"
                )
            }

            let value = try read(instruction.code, in: activation)

            if case let .bind(slot)? = instruction.binding {
                activation.cells[slot] = .value(value)
            }
        }

        guard let result = body.result else { return .null }

        return try read(result, in: activation)
    }

    // Running a closure here rather than in `evaluate`, which is what makes a
    // word able to take one. What may be called is what the link proved
    // answers, and a slot declaring `pure procedure` is how a word says so.
    func call(_ closure: Closure, with arguments: [(name: Name, value: Value)]) throws -> Value {
        var (body, activation) = try enter(closure, given: arguments, offered: true)

        return try closure.settling(returned: try read(body, in: &activation))
    }

    private func bool(_ value: Value) throws -> Bool {
        guard case let .bool(answer) = value else {
            throw ExecutionError("a condition must answer bool, got \(value.type)")
        }

        return answer
    }

    // What a slot path holds. The head is never absent, since every slot is
    // there from the frame's making; a hold whose surroundings changed under
    // it refuses, and every deeper absence is answered inside the walk.
    private func found(_ slot: Int, _ steps: [Step], in activation: Activation) throws -> Value {
        switch lookup(slot, steps, in: activation) {
        case let .found(value):
            return value

        case let .unfit(reason):
            throw ReferenceUnfit(path: spelled(slot, steps, in: activation), reason: reason)
        }
    }

    // Where a walk over a path came down: on a value, or on a reading gone
    // wrong. Every slot is there from the frame's making, so there is no
    // third answer.
    private enum Walk {
        case found(Value)
        case unfit(String)
    }

    // A dot means what its spelling says: the link judged every one and wrote
    // the judgment into the step. A key reads a field and nothing else; a
    // word sends and nothing else; the value that arrives decides neither.
    // What may genuinely be absent, a missing entry or a null on the way, is
    // read as null only where the author spelled `?.`, and refused everywhere
    // else.
    private func lookup(_ slot: Int, _ steps: [Step], in activation: Activation) -> Walk {
        var current: Value

        do {
            current = try activation.cells[slot].value()
        } catch {
            return .unfit("\(error)")
        }

        for (index, step) in steps.enumerated() {
            let segment = spelled(step, in: activation)

            // The path as far as this step, spelled for a refusal. Only a
            // refusal reads it, so a read that lands spells nothing.
            func walked() -> [PathSegment] {
                spelled(slot, Array(steps[...index]), in: activation)
            }

            // Null stops every reading the same way, and the rule lives with
            // the segment: the link's walk over types asks the same judge, so
            // the two layers cannot drift apart.
            if current == .null {
                switch segment.meetingNull(at: walked()) {
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
            case let .at(inner, innerSteps, _):
                let name = spelled(inner, innerSteps, in: activation).rendered

                switch lookup(inner, innerSteps, in: activation) {
                case let .found(.int(index)):
                    read = indexed(current, at: index, walked: walked)

                case let .found(.double(double)):
                    switch Int.reading(double) {
                    case let .word(index):
                        read = indexed(current, at: index, walked: walked)

                    case .notANumber, .fractional:
                        return .unfit("index reference \(name) is not a whole number")

                    case .pastTheWord:
                        return .unfit(
                            "index reference \(name) indexes past the end of any array"
                        )
                    }

                case let .found(value):
                    return .unfit("index reference \(name) is \(value.type), expected int")

                case let .unfit(reason):
                    return .unfit(reason)
                }

            case let .key(key, _):
                guard case let .record(record) = current else {
                    return .unfit("\(walked().rendered) drills a field into \(current.type)")
                }

                guard let next = record[key] else {
                    guard segment.optional else {
                        return .unfit(
                            "\(walked().rendered): '\(key)' is not there"
                                + " — only `\(segment.mark)` reads absence"
                        )
                    }

                    return .found(.null)
                }

                read = .found(next)

            case let .word(row, key, _):
                do {
                    guard let derived = try derive(linked[row], from: current) else {
                        return .unfit(
                            "\(walked().rendered) sends '\(key)', which does not take \(current.type)"
                        )
                    }

                    read = .found(derived)
                } catch {
                    return .unfit("\(walked().rendered) — \(error)")
                }
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

    // A path segment that names no field is a message: `items.count` sends
    // `count` to what the path has reached so far. Only words that ask for
    // nothing are reachable this way, because dot notation supplies no
    // arguments, so the arguments a word does declare arrive from its own
    // defaults, and the receiver is checked against what it declared.
    //
    // A word that declines the shape it was sent to reads as absence, the same
    // as a field never set. A word that took the shape and then refused did not
    // decline it, so that refusal is answered rather than swallowed.
    private func derive(_ callee: Linked, from value: Value) throws -> Value? {
        guard callee.isDerivable else { return nil }

        guard
            let receiver = try? callee.settling(receiver: value),
            let arguments = try? settled(
                callee,
                given: Array(repeating: nil, count: callee.slots.count),
                skipping: Skipped(handed: [], receiver: callee.receiverPosition)
            )
        else {
            return nil
        }

        return try answer(callee, for: receiver, with: arguments)
    }

    // Every index reference read to a position: a write lands on one
    // position, and a hold is extended by positions.
    private func positioned(_ head: Int, _ steps: [Step], in activation: Activation) throws -> [PathSegment] {
        try steps.map { step in
            switch step {
            case let .key(name, optional):
                return .key(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .at(slot, inner, optional):
                guard case let .int(index) = try found(slot, inner, in: activation) else {
                    throw ExecutionError(
                        "'\(spelled(head, steps, in: activation).rendered)' indexes with"
                            + " '\(spelled(slot, inner, in: activation).rendered)', which is not an int"
                    )
                }

                return .index(index, optional: optional)

            case let .word(_, name, optional):
                return .word(name, optional: optional)
            }
        }
    }

    // The path as the author wrote it, for a sentence that reads it back.
    private func spelled(_ slot: Int, _ steps: [Step], in activation: Activation) -> [PathSegment] {
        [.key(activation.frame.names[slot])] + spelled(steps, in: activation)
    }

    private func spelled(_ steps: [Step], in activation: Activation) -> [PathSegment] {
        steps.map { step in spelled(step, in: activation) }
    }

    private func spelled(_ step: Step, in activation: Activation) -> PathSegment {
        switch step {
        case let .key(name, optional):
            return .key(name, optional: optional)

        case let .index(index, optional):
            return .index(index, optional: optional)

        case let .at(slot, inner, optional):
            return .indexRef(spelled(slot, inner, in: activation), optional: optional)

        case let .word(_, name, optional):
            return .word(name, optional: optional)
        }
    }
}
