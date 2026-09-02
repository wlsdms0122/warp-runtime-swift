//
//  Executor.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Executor: Sendable {
    // MARK: - Property
    public let observer: (any ExecutionObserver)?
    public let environment: (any Environment)?

    // The linked call table, seeded from the image this run was given. Empty
    // until then, which is why nothing but `run(_ image:)` can start a run.
    let procedures: [String: Procedure]

    // What a selector may send without running, by its declared spelling,
    // worked out by the link.
    let selectors: [String: Procedure]

    // What a path segment may reach, by the bare name a path writes.
    let words: [String: Procedure]

    // The shapes the link declared. A named type is answered here rather than
    // expanded at link, so every boundary that settles arguments needs it.
    let types: TypeTable

    // One box per module variable, made when the run starts, by the document
    // that declared it; and which document each procedure reads its boxes
    // from. A closure carries the boxes in the scope it captured.
    let boxes: [Int: [String: Variable]]
    let origins: [String: Int]

    // MARK: - Initializer
    // What a caller has to say to make one: who watches, and what the run may
    // reach outside itself. The tables come from an image, so this is an
    // executor with nothing to run yet.
    public init(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil
    ) {
        self.init(observer: observer, environment: environment, procedures: [:])
    }

    // Seeded, and not public: the tables are the link's answer, so a caller
    // that could write them would be running a program nothing linked.
    init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        procedures: [String: Procedure] = [:],
        selectors: [String: Procedure] = [:],
        words: [String: Procedure] = [:],
        types: TypeTable = TypeTable(),
        boxes: [Int: [String: Variable]] = [:],
        origins: [String: Int] = [:]
    ) {
        self.observer = observer
        self.environment = environment
        self.procedures = procedures
        self.selectors = selectors
        self.words = words
        self.types = types
        self.boxes = boxes
        self.origins = origins
    }

    // MARK: - Public
    // Running takes an image, not a procedure, so "ran something that was never
    // linked" is not a state this type can be put in.
    public func run(
        _ image: Image,
        arguments: [String: Value] = [:]
    ) async throws -> Value {
        try await Executor(
            observer: observer,
            environment: environment,
            procedures: image.procedures,
            selectors: image.selectors,
            words: image.words,
            types: image.types,
            boxes: image.variables.mapValues { started in started.mapValues(Variable.init) },
            origins: image.origins
        )
        .run(image.entry, arguments: arguments, boxes: image.entryOrigin)
    }

    // MARK: - Private
    func run(
        _ procedure: Procedure,
        arguments: [String: Value] = [:],
        boxes origin: Int? = nil,
        at trace: Trace = Trace()
    ) async throws -> Value {
        guard let block = procedure.block else {
            throw ExecutionError("a run starts from a body, and this declaration is native")
        }

        return try await answer(
            block,
            of: procedure.signature,
            in: Scope(
                bindings: try procedure.signature.settle(arguments, in: types),
                variables: origin.flatMap { origin in boxes[origin] } ?? [:]
            ),
            at: trace
        )
    }

    // A body run as a procedure: what it answers is caught here, and what it
    // answers is settled against what it declared.
    //
    // Both halves are the frame, and neither works without the other — so there
    // is one of these rather than one per way of reaching a body. There are
    // three ways: a run starting here, a word whose implementation is written,
    // and a closure being invoked. When only the first caught a leaving, a
    // `return` inside a called body travelled out through its own frame and
    // became the *caller's* answer, settled against the caller's signature.
    private func answer(
        _ block: Block,
        of signature: Signature,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let returned: Value

        do {
            returned = try await run(block, in: scope, at: trace)
        } catch let leaving as Leaving where leaving.reach == .procedure {
            // A closure is a procedure, so this is also what stops a `return`
            // written inside one from answering for the procedure around it.
            returned = leaving.value
        }

        return try signature.settling(returned: returned, in: types)
    }

    // Statements bind in order. What comes back is the scope they built and what
    // the last one was worth — the second is for a caller that wants it, not
    // what the block answers with, which is `run(_ block:)`.
    func run(
        _ body: [Statement],
        in startScope: Scope,
        at trace: Trace
    ) async throws -> BlockResult {
        // The cancellation check sits at sequence entry, not only per statement —
        // an empty body inside a loop round must still observe cancellation, or
        // the caller's one lever against a runaway loop silently stops working.
        try Task.checkCancellation()

        var scope = startScope
        var lastResult = Value.null

        for (position, statement) in body.enumerated() {
            try Task.checkCancellation()

            let result = try await run(statement, at: position, in: scope, at: trace)

            switch statement.binding {
            case let .constant(id)?:
                scope = scope.binding(id, to: result)

            case let .variable(id)?:
                scope = scope.declaring(id, as: result)

            // An assignment introduces nothing, so the scope is unchanged here
            // — the write went into a box the enclosing bodies also hold.
            case let .assignment(path)?:
                try scope.assign(try positioned(path, in: scope), to: result)

            // A nameless statement ran for its effect, and the answer is
            // dropped — which is what leaving the name off said.
            case nil:
                break
            }

            lastResult = result
        }

        return BlockResult(scope: scope, lastResult: lastResult)
    }

    // A body answers what it says it answers, and a body that says nothing
    // answers nothing.
    //
    // Reading the last statement instead would put a body's answer in its
    // ordering, where nothing points at it: appending a statement would change
    // what the body was worth, and the author who appended it wrote nothing that
    // says so. A loop and a walk already answered this way, so this is also the
    // language holding one rule where it held two.
    func run(_ block: Block, in scope: Scope, at trace: Trace) async throws -> Value {
        let outcome = try await run(block.body, in: scope, at: trace)

        guard let result = block.result else { return .null }

        return try await evaluate(result, in: outcome.scope, at: trace)
    }

    // The expression evaluator. `Resolver` answers the pure subset synchronously
    // — which is what an effect settling its operands needs — and everything
    // that runs a body or reaches outside is answered here, because both are
    // async and both can fail in ways a rescue may catch.
    func evaluate(
        _ expression: Expression,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        switch expression {
        case .literal, .reference, .closure:
            return try resolver(in: scope).resolve(expression)

        // Nothing comes back, so this answers by not answering. What it carries
        // is worked out here, where the names it reads are still in scope.
        case let .leave(leave):
            var carried = Value.null

            if let value = leave.value {
                carried = try await evaluate(value, in: scope, at: trace)
            }

            throw Leaving(reach: leave.reach, target: leave.target, value: carried)

        case let .invoke(callee, arguments):
            return try await invoke(callee, arguments: arguments, in: scope, at: trace)

        // The run's whole share of a cast: the link already decided what every
        // dot after this means, and the one thing it could not know is what
        // actually arrived. That question is the boundary's, and the boundary's
        // judge answers it — the same `settling` a parameter takes its argument
        // through, so "is this value that shape" is answered in one place for
        // both doors. A plain cast lets the refusal out as a failure like any
        // other; an optional one reads the mismatch as null, which is the
        // author saying they expected it.
        case let .cast(value, type, optional):
            return try type.reading(
                await evaluate(value, in: scope, at: trace),
                optional: optional,
                in: types
            )

        case let .array(array):
            var values: [Value] = []

            for element in array {
                values.append(try await evaluate(element, in: scope, at: trace))
            }

            return .array(values)

        // In name order, the same order arguments evaluate in — the one order
        // a program could observe (which field's write or refusal lands last)
        // is the text's fact rather than a hash table's.
        case let .record(record):
            var values: [String: Value] = [:]

            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                values[name] = try await evaluate(field, in: scope, at: trace)
            }

            return .object(values)

        case let .block(block):
            return try await run(block, in: scope, at: trace)

        // A branch answers nothing — the condition chooses a way through the
        // body, and what an arm keeps it writes to an outer variable.
        case let .conditional(condition, then, otherwise):
            let take = try resolver(in: scope).evaluate(condition)

            if let taken = take ? then : otherwise {
                _ = try await run(taken, in: scope, at: trace)
            }

            return .null

        case let .loop(condition, body, round):
            return try await loop(
                while: condition,
                body: body,
                round: round,
                in: scope,
                at: trace
            )

        case let .iteration(material, body, element):
            return try await iterate(
                over: material,
                body: body,
                element: element,
                in: scope,
                at: trace
            )

        case let .attempt(block, rescue, failure):
            return try await attempt(
                block,
                rescue: rescue,
                failure: failure,
                in: scope,
                at: trace
            )

        case let .dispatch(dispatch):
            return try await send(dispatch, in: scope, at: trace)

        }
    }

    // One lookup, because there is one table. A selector was resolved at link to
    // the name of a declaration, and what happens next is decided by how that
    // declaration is implemented — not by which container it was found in.
    func send(_ dispatch: Dispatch, in scope: Scope, at trace: Trace) async throws -> Value {
        let procedure = try resolve(dispatch.selector)

        switch procedure.implementation {
        // A query answers without running, so the pure resolver is the whole
        // implementation — it is here only so that `x.count` and the same
        // word written as a statement mean the same thing.
        case .query:
            return try Resolver(
                scope: scope,
                selectors: selectors.merging([dispatch.selector: procedure]) { _, new in new },
                words: words,
                types: types
            )
            .resolve(.dispatch(dispatch))

        case let .effect(effect):
            return try await effect.run(
                Invocation(
                    selector: dispatch.selector,
                    signature: procedure.signature,
                    receiver: dispatch.receiver,
                    arguments: dispatch.arguments,
                    trace: trace,
                    scope: scope,
                    executor: self
                )
            )

        case let .body(block):
            let resolver = resolver(in: scope)
            // In name order, so the one order a program could observe — which
            // argument's refusal surfaces when two would refuse — is the
            // text's fact rather than a hash table's.
            var given: [String: Value] = [:]

            for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
                given[name] = try resolver.resolve(argument)
            }

            // A receiver is written on the other side of the dot rather than by
            // name. It is not settled as an argument — being sent to nothing is
            // something a word answers rather than refuses — but the body reads
            // it under the name its signature gave it.
            var declared = procedure.signature.parameters
            var received: (String, Value)?

            if let name = procedure.signature.receiver, let receiver = dispatch.receiver {
                declared[name] = nil
                received = (
                    name,
                    try procedure.signature.settling(
                        receiver: try resolver.resolve(receiver),
                        in: types
                    )
                )
            }

            // A parameter handed in place takes no value: it takes the
            // caller's box, or a box the caller's path is written back from.
            let handed = try handed(by: dispatch, to: procedure.signature, in: scope)

            for name in handed.keys {
                declared[name] = nil
                given[name] = nil

                if received?.0 == name { received = nil }
            }

            var settled = try Signature(parameters: declared).settle(given, in: types)

            if let received { settled[received.0] = received.1 }

            var inner = Scope(
                bindings: settled,
                variables: origins[dispatch.selector].flatMap { origin in boxes[origin] } ?? [:]
            )

            for (name, box) in handed.sorted(by: { $0.key < $1.key }) {
                inner = inner.sharing(box.box, as: name)
            }

            // A box handed for a path into a variable is written back when
            // the call ends, whether it answered or failed: a box written
            // halfway is still written. What the writing back refuses is
            // refused out loud.
            let answered: Result<Value, any Error>

            do {
                answered = .success(
                    try await answer(
                        block,
                        of: procedure.signature,
                        in: inner,
                        at: trace.appending(.procedure(dispatch.selector))
                    )
                )
            } catch {
                answered = .failure(error)
            }

            for (_, box) in handed.sorted(by: { $0.key < $1.key }) where box.path.count > 1 {
                try scope.assign(box.path, to: box.box.value)
            }

            return try answered.get()
        }
    }

    // Calling a value. The body runs in the scope the closure captured and not
    // in the caller's — that is what lexical scope means, and it is the reason a
    // closure is worth passing at all.
    func invoke(
        _ callee: Expression,
        arguments: [String: Expression],
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let resolver = resolver(in: scope)
        let value = try resolver.resolve(callee)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.type), and only a procedure can be called"
            )
        }

        // Name order here too, for the same reason as a call's arguments.
        var resolved: [String: Value] = [:]

        for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
            resolved[name] = try resolver.resolve(argument)
        }

        return try await answer(
            closure,
            settled: try closure.procedure.signature.settle(resolved, in: types),
            at: trace
        )
    }

    // Calling a closure a word holds. Arguments are offered rather than
    // settled strictly — the word decides what it has to give, and which of
    // those the closure's author wanted is the author's business.
    func call(
        _ closure: Closure,
        offering arguments: [String: Value],
        at trace: Trace
    ) async throws -> Value {
        try await answer(
            closure,
            settled: try closure.procedure.signature.settle(offered: arguments, in: types),
            at: trace
        )
    }

    // The one way a closure is entered, however its arguments were settled —
    // so whatever this boundary grows (observation, cancellation, how a return
    // lands) holds for a closure called as a value and one a word calls.
    private func answer(
        _ closure: Closure,
        settled: [String: Value],
        at trace: Trace
    ) async throws -> Value {
        guard let block = closure.procedure.block else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        var inner = closure.captured

        for (name, value) in settled {
            inner = inner.binding(name, to: value)
        }

        return try await answer(
            block,
            of: closure.procedure.signature,
            in: inner,
            at: trace
        )
    }

    func call(
        procedure name: String,
        arguments: [String: Value],
        in scope: Scope
    ) async throws -> Value {
        // procedure-to-procedure calls carry no termination guard — a name reappearing
        // in the call chain is not an oracle for a cycle (recursion over shrinking
        // input is legitimate), and a depth budget is policy, not mechanism.
        // Runaway calls are the caller's concern: observation and cancellation,
        // which propagate here through task cancellation.
        let procedure = try resolve(name)

        return try await run(
            procedure,
            arguments: arguments,
            boxes: origins[name],
            at: Trace(frames: [.procedure(name)])
        )
    }

    // Linking put every name the document spells in this table, so there is
    // nowhere else for a name to be. A door for names the link never saw would
    // be a second way to call, and one that nothing checked — the promise this
    // language makes is that reaching a run means the reaching was settled.
    // The boxes a call hands in place, by parameter. A path that is a whole
    // variable hands the variable's own box, so every write lands in it as it
    // is made. A path into a variable hands a fresh box holding what the path
    // reads, and the call writes it back along the path when it ends — by
    // answering or by failing, since a box written halfway is still written.
    // What arrives is settled against the declaration first, the way a value
    // argument is.
    private func handed(
        by dispatch: Dispatch,
        to signature: Signature,
        in scope: Scope
    ) throws -> [String: (box: Variable, path: [PathSegment])] {
        var handed: [String: (box: Variable, path: [PathSegment])] = [:]

        for (name, parameter) in signature.parameters where parameter.declared.isInout {
            guard case let .reference(written)? = dispatch.handed(name, to: signature), let head = written.head else {
                throw ExecutionError(
                    "'\(dispatch.selector)' takes '\(name)' in place, and was not handed a variable"
                )
            }

            guard let box = scope.box(of: head) else {
                throw ExecutionError(
                    "'\(dispatch.selector)' takes '\(name)' in place, and '\(head)' is not a variable here"
                )
            }

            // A whole variable hands its own box, and what it holds was settled
            // when it was written. A path into one hands a box holding what
            // the path reads, settled against the declaration the way a value
            // argument is; the position is fixed here, once, so the writing
            // back lands where the reading came from.
            let path = try positioned(written, in: scope)

            guard path.count > 1 else {
                handed[name] = (box, path)
                continue
            }

            let settled = try parameter.declared.inoutUnwrapped.settling(
                try resolver(in: scope).resolve(.reference(path)),
                at: "input '\(name)'",
                in: types
            )

            handed[name] = (Variable(settled), path)
        }

        return handed
    }

    // The path with every index read to a position: an index written as a
    // name is a reading in the scope the write stands in, and a write lands on
    // one position.
    private func positioned(_ path: [PathSegment], in scope: Scope) throws -> [PathSegment] {
        try path.map { segment in
            guard case let .indexRef(inner, optional) = segment else { return segment }

            guard case let .int(index) = try resolver(in: scope).resolve(.reference(inner)) else {
                throw ExecutionError(
                    "'\(path.rendered)' indexes with '\(inner.rendered)', which is not an int"
                )
            }

            return .index(index, optional: optional)
        }
    }

    func resolve(_ name: String) throws -> Procedure {
        guard let linked = procedures[name] else {
            throw ExecutionError("procedure '\(name)' was not linked into this image")
        }

        return linked
    }

    // MARK: - Private
    private func resolver(in scope: Scope) -> Resolver {
        Resolver(scope: scope, selectors: selectors, words: words, types: types)
    }

    private func run(
        _ statement: Statement,
        at position: Int,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        // The same notation the validator uses for a nameless statement, and
        // one an author's own name can never collide with — `_` is a name.
        let inside = trace.appending(.statement(statement.name ?? "[\(position)]"))

        await observer?.statementStarted(at: inside, expression: statement.expression)

        do {
            let result = try await evaluate(statement.expression, in: scope, at: inside)

            await observer?.statementCompleted(at: inside, result: result)

            return result
        } catch {
            let refused = refusal(error, at: inside)

            await observer?.statementFailed(at: inside, error: refused)

            throw refused
        }
    }

    // A refusal leaving a statement takes that statement's place with it, unless
    // it already carries one — the innermost is where the mistake is, and every
    // statement it passes through on the way out is only where the run was.
    private func refusal(_ error: any Error, at trace: Trace) -> any Error {
        guard let refused = error as? any WarpError, refused.trace == nil else { return error }

        return refused.tracing(trace)
    }

    private func loop(
        while condition: Expression,
        body: Block,
        round: String,
        in startScope: Scope,
        at trace: Trace
    ) async throws -> Value {
        var index = 0
        // What the last round that finished left behind. The result reads it,
        // because a result naming something the body bound is a thing the
        // checker allows and so a thing that has to work. A round that did not
        // finish contributed nothing, the same way a skipped round contributes
        // nothing to a walk.
        var settled = startScope

        while true {
            // A round is a block, so what it binds dies with it. Carrying the
            // round's whole scope into the next one would make every binding in
            // the body accidentally mutable to buy the one that had to be. A
            // variable declared outside the loop carries what the author meant
            // to carry, and nothing else comes with it.
            let state = Value.object(["index": .int(index)])
            let scope = startScope.binding(round, to: state)
            // Where the result is read: what the last finished round bound, plus
            // the round state as it stands now.
            let reading = settled.binding(round, to: state)

            let take = try resolver(in: scope).evaluate(condition)

            if !take {
                guard let result = body.result else { return .null }

                return try await evaluate(result, in: reading, at: trace)
            }

            do {
                settled = try await run(
                    body.body,
                    in: scope,
                    at: trace.appending(.round(index))
                )
                .scope
            } catch let leaving as Leaving where leaving.claimed(by: round) {
                guard leaving.reach == .round else {
                    // Ending the loop answers what ending it normally answers.
                    // A round that stopped early still bound what it bound, so
                    // the result reads the scope that round left behind — the
                    // same scope the checker showed it, and the same one a walk
                    // reads its result in.
                    guard let result = body.result else { return .null }

                    return try await evaluate(result, in: reading, at: trace)
                }
            }

            index += 1
        }
    }

    private func iterate(
        over material: Expression,
        body: [Statement],
        element: String,
        in startScope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let elements = try await array(
            of: material,
            naming: element,
            in: startScope,
            at: trace
        )

        for (index, item) in elements.enumerated() {
            // Every round starts from the enclosing scope, the same rule the
            // loop states: carrying a round's scope into the next would make
            // every binding in the body accidentally live on. What a round
            // leaves behind is what it wrote to an outer variable — the box
            // carries that without any scope traveling.
            let scope = startScope.binding(
                element,
                to: .object(["item": item, "index": .int(index)])
            )

            do {
                _ = try await run(
                    body,
                    in: scope,
                    at: trace.appending(.round(index))
                )
            } catch let leaving as Leaving where leaving.claimed(by: element) {
                // A walk answers nothing, so ending one early ends it and no
                // more — what its rounds wrote outward is already written.
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
        of material: Expression,
        naming element: String,
        in scope: Scope,
        at trace: Trace
    ) async throws -> AnyRandomAccessCollection<Value> {
        let resolved = try await evaluate(material, in: scope, at: trace)

        // What is iterated is whatever has elements — the one projection that
        // owns the bytes equation, so `each` walks bytes the way an index
        // reads them. The projection is left as it is rather than copied out:
        // a round reads one element, and a compact spelling should not have to
        // become a million boxed ints before the first round runs.
        guard let elements = resolved.elements else {
            // A plain reference names its own locus; any other expression shape
            // has no path to point at, so the message carries the blame instead
            // of an empty `{ ref: }` rendering.
            guard let path = material.referencePath else {
                throw ExecutionError(
                    "the material of iteration '\(element)' resolved to"
                        + " \(resolved.type), expected array"
                )
            }

            throw ReferenceUnfit(
                path: path,
                reason: "iteration material is \(resolved.type), expected array"
            )
        }

        return elements
    }

    private func attempt(
        _ block: Block,
        rescue: Block,
        failure name: String,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        do {
            return try await run(block, in: scope, at: trace)
        } catch {
            guard !Task.isCancelled else { throw error }

            // An author mistake passes through: a rescue is for what the world
            // did, not for what the procedure says.
            guard let recoverable = error as? any RecoverableFailure else { throw error }

            await observer?.failureRescued(name: name, error: error)

            // While the rescue runs, the failure is a value under the declared
            // name — readable, and gone the moment the rescue answers. Its
            // shape needs no check here: `RecoverableFailure` assembles the
            // payload itself, so `type` and `message` are there by
            // construction rather than by inspection.
            return try await run(
                rescue,
                in: scope.binding(name, to: recoverable.payload),
                at: trace
            )
        }
    }
}
