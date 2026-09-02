//
//  Resolver.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Reads an expression as data against one environment. Everything a reference
// needs beyond naming a head lives here — walking the rest of the path, and
// sending a no-argument word to what the walk reached.
//
// `derivations` is what a path segment may reach: the link worked out which
// declarations answer without running and take a receiver, and gave them back
// under the bare names a path writes. A resolver built without one reads paths
// and nothing else, which is what a constant or a closed template wants.
public struct Resolver: Sendable {
    // MARK: - Property
    public let scope: Scope
    public let derivations: [String: Procedure]

    // The words a bare path spelling may send, apart from the selectors: one
    // key answering both questions let a declaration shadow another's path
    // word.
    public let words: [String: Procedure]
    public let types: TypeTable

    // MARK: - Initializer
    public init(
        scope: Scope,
        derivations: [String: Procedure] = [:],
        words: [String: Procedure] = [:],
        types: TypeTable = TypeTable()
    ) {
        self.scope = scope
        self.derivations = derivations
        self.words = words
        self.types = types
    }

    // MARK: - Public
    public func resolve(_ expression: Expression) throws -> Value {
        switch expression {
        case let .literal(value):
            return value

        case let .reference(path):
            return try found(at: path)

        case let .array(array):
            return .array(try array.map(resolve))

        // In name order, the same order the executor reads fields in — the
        // one order a program could observe (which field's refusal surfaces)
        // is the text's fact rather than a hash table's.
        case let .record(record):
            var fields: [String: Value] = [:]

            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                fields[name] = try resolve(field)
            }

            return .object(fields)

        // Making a closure runs nothing — it is the capture, and the capture is
        // this scope. Which is why it belongs to the pure half and a condition
        // may hand one to a word.
        case let .closure(procedure):
            return .procedure(Closure(procedure: procedure, captured: scope))

        case let .dispatch(dispatch):
            return try send(dispatch)

        // Judging a value against a shape runs nothing, so a cast is data the
        // pure half can read — and the link says so, which is what makes this
        // arm necessary rather than optional: `isPure` calls a cast pure, and
        // a pure expression the pure evaluator cannot read would fail here
        // with the one sentence the link had just denied.
        //
        // The same judge the executor uses, for the same reason both doors of
        // a boundary share one: "is this value that shape" is answered in one
        // place or it is answered two ways.
        case let .cast(value, type, optional):
            return try type.reading(try resolve(value), optional: optional, in: types)

        // Running a body or reaching outside is async and may fail in a way an
        // attempt can catch, so it belongs to the executor. Reaching here means
        // a construct was written where only data can be read — inside a
        // condition, or among an effect's settled arguments.
        default:
            throw ExecutionError(
                "this expression runs, so it cannot be read as data here"
            )
        }
    }

    public func string(_ expression: Expression) throws -> String {
        stringify(try resolve(expression))
    }

    public func stringify(_ value: Value) -> String {
        Rendering(value).text()
    }

    // What a reference names, walked to the end. The scope answers the head;
    // every segment after it is drilling into a value, and a segment that names
    // no field is a message sent to what the walk has reached so far.
    public func lookup(_ path: [PathSegment]) -> Lookup {
        // A mark on the head expects the scope to be missing a name, which is
        // not absence but a reading gone wrong — the link says so where the
        // text shows it, and the run says the same rather than reading past.
        if let refusal = path.markedHead { return .unfit(reason: refusal) }

        guard case let .key(head, _)? = path.first else { return .absent }
        guard let value = scope.value(of: head) else { return .absent }

        return drill(into: value, Array(path.dropFirst()), at: [.key(head)])
    }

    // Running a procedure here rather than in the executor, which is what makes
    // a word able to take one. Nothing in a body that answers without running is
    // asynchronous, so the whole of it is this walk: bind each statement, then
    // read the result.
    //
    // What may be called is what the link proved answers — a slot declaring
    // `pure procedure` is how a word says so. Reaching here with anything else
    // is refused rather than run, because there is no half of this that could
    // await.
    public func call(_ closure: Closure, with arguments: [String: Value] = [:]) throws -> Value {
        let signature = closure.procedure.signature

        guard let block = closure.procedure.block else {
            throw ExecutionError("a body is what runs here, and this procedure is native")
        }

        let inner = try signature.settle(offered: arguments, in: types)
            .reduce(closure.captured) { scope, binding in
                scope.binding(binding.key, to: binding.value)
            }

        return try signature.settling(
            returned: try evaluate(block, in: inner),
            in: types
        )
    }

    public func evaluate(_ expression: Expression) throws -> Bool {
        let value = try resolve(expression)

        guard case let .bool(answer) = value else {
            throw ExecutionError(
                "a condition must answer bool, got \(value.type)"
            )
        }

        return answer
    }

    // MARK: - Private
    // A dot means what its spelling says — the link judged every one and wrote
    // the judgment into the path. `key` reads a field and nothing else; `word`
    // sends and nothing else; the value that arrives decides neither. What may
    // genuinely be absent — a missing entry, a null on the way — is read as
    // null only where the author spelled `?.`, and refused everywhere else.
    private func drill(
        into value: Value,
        _ path: [PathSegment],
        at walked: [PathSegment]
    ) -> Lookup {
        var current = value
        var walked = walked

        for segment in path {
            walked.append(segment)

            // Null stops every reading the same way, and the rule lives with
            // the segment — the link's walk over types asks the same judge,
            // so the two layers cannot drift apart.
            if current == .null {
                switch segment.meetingNull(at: walked) {
                case .reads:
                    return .found(.null)

                case let .refused(reason):
                    return .unfit(reason: reason)
                }
            }

            // One reading for both index spellings — a literal, and a name
            // settled here, when the walk reaches it rather than up front, so
            // a path short-circuited before the index never reads its name.
            func indexed(_ index: Int) -> Lookup? {
                // What is indexed is whatever has elements — the projection
                // owns the `array<byte>` equation, lazily, so one element
                // read does not unpack a compact spelling.
                guard let elements = current.elements else {
                    return .unfit(
                        reason: "\(walked.rendered) indexes into"
                            + " \(current.type), expected array"
                    )
                }

                // Past the end is a defect, not absence: the array is there
                // and says how long it is, so a reading that misses it read
                // the length wrong.
                guard index >= 0, index < elements.count else {
                    return .unfit(
                        reason: "\(walked.rendered) indexes past the end of"
                            + " \(elements.count) element(s)"
                    )
                }

                current = elements[elements.index(elements.startIndex, offsetBy: index)]

                return nil
            }

            switch segment {
            case let .index(index, _):
                if let refusal = indexed(index) { return refusal }

            // The name is a path of its own, read against the same scope. A
            // name that answers nothing is a defect said out loud — the heads
            // the text shows were checked at load, so absence here is not the
            // author's optionality but a reading gone wrong.
            case let .indexRef(inner, _):
                let name = inner.rendered

                switch lookup(inner) {
                case let .found(.int(index)):
                    if let refusal = indexed(index) { return refusal }

                case let .found(.double(double)):
                    switch Int.reading(double) {
                    case let .word(index):
                        if let refusal = indexed(index) { return refusal }

                    case .notANumber, .fractional:
                        return .unfit(
                            reason: "index reference \(name) is not a whole number"
                        )

                    case .pastTheWord:
                        return .unfit(
                            reason: "index reference \(name) indexes past the"
                                + " end of any array"
                        )
                    }

                case let .found(value):
                    return .unfit(
                        reason: "index reference \(name) is \(value.type), expected int"
                    )

                case .absent:
                    return .unfit(reason: "index reference \(name) names nothing")

                case let .unfit(reason):
                    return .unfit(reason: reason)
                }

            case let .key(key, _):
                guard case let .object(object) = current else {
                    return .unfit(
                        reason: "\(walked.rendered) drills a field into"
                            + " \(current.type)"
                    )
                }

                guard let next = object[key] else {
                    guard segment.optional else {
                        return .unfit(
                            reason: "\(walked.rendered): '\(key)' is not there"
                                + " — only `\(segment.mark)` reads absence"
                        )
                    }

                    return .found(.null)
                }

                current = next

            case let .word(key, _):
                do {
                    guard let derived = try derive(key, from: current) else {
                        return .unfit(
                            reason: "\(walked.rendered) sends '\(key)',"
                                + " which does not take \(current.type)"
                        )
                    }

                    current = derived
                } catch {
                    return .unfit(reason: "\(walked.rendered) — \(error)")
                }
            }
        }

        return .found(current)
    }

    // A path segment that names no field is a message: `items.count` sends
    // `count` to what the path has reached so far. Only words that ask for
    // nothing are reachable this way, because dot notation supplies no
    // arguments — so the arguments a word does declare arrive from its own
    // defaults, and the receiver is checked against what it declared. A path
    // and an explicit send are the same call, so they are checked the same way.
    //
    // A word that declines the shape it was sent to reads as absence, the same
    // as a field never set. A word that took the shape and then refused did not
    // decline it, so that refusal is answered rather than swallowed — otherwise
    // a walk would report the one thing it knows to be false, that nothing was
    // there.
    private func derive(_ key: String, from value: Value) throws -> Value? {
        guard
            let procedure = words[key],
            procedure.signature.isDerivable(in: types)
        else {
            return nil
        }

        // A receiver is not settled as an argument: the word decides what being
        // sent to nothing means, and a required parameter cannot say that.
        var declared = procedure.signature.parameters
        declared[procedure.signature.receiver ?? ""] = nil

        guard
            let receiver = try? procedure.signature.settling(receiver: value, in: types),
            let arguments = try? Signature(parameters: declared).settle([:], in: types)
        else {
            return nil
        }

        return try evaluate(procedure, for: receiver, with: arguments)
    }

    // What a declaration returns, computed here rather than by the executor.
    // Both shapes it can have are answerable without suspending — one because it
    // is native and says so, the other because the link proved it.
    private func evaluate(
        _ procedure: Procedure,
        for receiver: Value?,
        with arguments: [String: Value]
    ) throws -> Value {
        // A receiver is a parameter, so it reaches a native the same way whether
        // it was written on the other side of the dot or by its own name. The
        // two spellings are one call.
        let sent = receiver ?? procedure.signature.receiver.flatMap { name in arguments[name] }

        switch procedure.implementation {
        // Absent and null are the same fact, and a word asked about nothing
        // decides for itself what that means — `contains` says false rather
        // than failing.
        case let .query(query):
            return try query.evaluate(
                Question(
                    receiver: sent == .null ? nil : sent,
                    arguments: arguments,
                    resolver: self
                )
            ) ?? .null

        // A body the link proved pure runs here, synchronously. Nothing in it
        // can suspend — that is what the proof says — so the surface that reads
        // data can read this too, and a procedure someone wrote is reachable
        // from a path exactly as a native one is. Whether a body may run *yet*
        // is the table's fact: the link's own settling swaps written bodies
        // for the refusal they earn, so what reaches here runs.
        case let .body(block):
            var bindings = arguments

            if let name = procedure.signature.receiver, let sent {
                bindings[name] = sent
            }

            return try evaluate(block, in: Scope(bindings: bindings))

        case .effect:
            throw ExecutionError(
                "this answers only by running, so it cannot be read as data here"
            )
        }
    }


    // The pure half of dispatch. An effect or a procedure answers only by running,
    // so a condition that names one is refused here rather than quietly starting
    // something in the middle of a comparison.
    private func send(_ dispatch: Dispatch) throws -> Value {
        // The spelling is the selector as the author wrote it, which is a
        // declared qualified name, and a bare spelling not among the selectors
        // may still be a path word.
        guard let procedure = derivations[dispatch.selector] ?? words[dispatch.selector] else {
            throw ExecutionError(
                "'\(dispatch.selector)' answers only by running, so it cannot be"
                    + " read as data here"
            )
        }

        let receiver: Value?

        do {
            receiver = try dispatch.receiver
                .map(resolve)
                .map { value in try procedure.signature.settling(receiver: value, in: types) }
        } catch let unfit as ReferenceUnfit {
            throw unfit
        } catch {
            // A refusal about the receiver is answerable only if the author can
            // see which name held it — the locus is the receiver's path when it
            // has one, and nothing to add when it does not.
            guard let path = dispatch.receiver?.referencePath else { throw error }

            throw ReferenceUnfit(path: path, reason: "\(error)")
        }

        // A receiver is not settled as an argument: the word decides what being
        // sent to nothing means, and a required parameter cannot say that.
        var declared = procedure.signature.parameters

        if let name = procedure.signature.receiver, dispatch.receiver != nil {
            declared[name] = nil
        }

        let arguments = try Signature(parameters: declared)
            .settle(
                try dispatch.arguments
                    .sorted { left, right in left.key < right.key }
                    .reduce(into: [:]) { settled, argument in
                        settled[argument.key] = try resolve(argument.value)
                    },
                in: types
            )

        do {
            return try evaluate(procedure, for: receiver, with: arguments)
        } catch let unfit as ReferenceUnfit {
            throw unfit
        } catch {
            // A word blaming a shape is answerable only if the author can see
            // which name held it — the locus is the receiver's path when it has
            // one, and nothing to add when it does not.
            guard let path = dispatch.receiver?.referencePath else { throw error }

            throw ReferenceUnfit(path: path, reason: "\(error)")
        }
    }

    // A pure body, run without an executor. Statements bind in order and the
    // block answers what it declares — the same rule the executor follows, over
    // the subset that cannot suspend.
    //
    // A declaration starts from its parameters alone; a closure starts from what
    // it captured, which is the only difference between the two and is spelled
    // by what is handed in as the outer scope.
    private func evaluate(_ block: Block, in outer: Scope) throws -> Value {
        var scope = outer

        for (position, statement) in block.body.enumerated() {
            guard statement.binding == .constant else {
                throw ExecutionError(
                    "'\(statement.id ?? "[\(position)]")' writes a name, and what answers"
                        + " without running only binds"
                )
            }

            let value = try Resolver(
                scope: scope,
                derivations: derivations,
                words: words,
                types: types
            ).resolve(statement.expression)

            if let id = statement.id {
                scope = scope.binding(id, to: value)
            }
        }

        guard let result = block.result else { return .null }

        return try Resolver(
            scope: scope,
            derivations: derivations,
            words: words,
            types: types
        ).resolve(result)
    }

    // A name the scope does not hold reads as null rather than failing. The
    // head of every reference is checked at load, so absence here is only
    // ever the head's — every deeper absence answered inside the drill, as
    // null where the author spelled `?.` and as a refusal where they did not.
    private func found(at path: [PathSegment]) throws -> Value {
        switch lookup(path) {
        case let .found(value):
            return value

        case .absent:
            return .null

        case let .unfit(reason):
            throw ReferenceUnfit(path: path, reason: reason)
        }
    }
}
