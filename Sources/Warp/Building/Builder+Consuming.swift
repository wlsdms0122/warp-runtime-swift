//
//  Builder+Consuming.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a body does with the values it must hand on exactly once.
//
// A type written `once` says the values of it are handed on: given to a word,
// or answered. A body holding one has to do that on every way through, and may
// not do it twice, and the link says so before anything runs. That is the whole
// of what "this resource is closed exactly once" means here.
//
// The walk refuses wherever it cannot see: a value handed to a value call, a
// value a closure captured, a value moved inside a loop round or an attempt.
// Each of those is a place where "how many times" is not a fact the text shows,
// and a proof that admits one of them is not a proof.
extension Builder {
    // MARK: - Internal
    // Whether values of this type are handed on once, through the names it may
    // hide behind. A chain of names is finite: the link refused one that comes
    // back on itself before this is asked.
    func handedOnce(_ type: TypeExpression, in table: TypeTable) -> Bool {
        switch type {
        case .once:
            return true

        case let .named(name):
            guard let declared = table.resolve(name) else { return false }

            return handedOnce(declared, in: table)

        case let .variable(inner), let .inout(inner):
            return handedOnce(inner, in: table)

        default:
            return false
        }
    }

    // Every value a body must hand on, handed on once. The declaration's own
    // slots are where such a value enters a body: `once` is a document's
    // spelling and a value the link folded is a value, never a promise.
    func consumed(
        _ block: Block,
        at place: Place,
        holding signature: Signature,
        in context: TypingContext
    ) throws {
        let held = signature.parameters.filter { _, parameter in
            handedOnce(parameter.declared, in: context.types)
        }

        guard !held.isEmpty || context.types.types.values.contains(where: { type in
            handedOnce(type, in: context.types)
        }) else {
            return
        }

        let walk = Consuming(context: context, place: place)
        let left = try walk.through(block, held: Consuming.Held(live: Set(held.keys)), guarded: nil)

        guard let stranded = left.live.sorted().first else { return }

        throw BuildError(
            "still holds '\(stranded)' where it ends. A value written `once` is"
                + " handed on, and a body that reaches its end holding one has"
                + " dropped it",
            at: place
        )
    }

    // MARK: - Private
    private struct Consuming {
        // What a body is holding, and what it has already handed on. The two
        // are apart because they answer different refusals: one is a value
        // dropped, the other a value handed on twice, and a name that has
        // gone from the first without reaching the second is a name that was
        // never one of these.
        struct Held {
            var live: Set<Name>
            var moved: Set<Name> = []
        }

        let context: TypingContext
        let place: Place

        // What is still held after this block. `guarded` is why a move is
        // refused here, and nil where one is allowed.
        func through(_ block: Block, held: Held, guarded: String?) throws -> Held {
            var held = held

            for statement in block.body {
                held = try moving(statement.expression, held: held, guarded: guarded)

                switch statement.binding {
                case let .constant(name, _)?, let .variable(name, _)?:
                    guard handedOnce(statement.expression, held: held) else { continue }

                    held.live.insert(name)
                    held.moved.remove(name)

                // A write puts something else in the box, so what was there is
                // gone without having been handed on.
                case let .assignment(path)?:
                    guard let head = path.head, held.live.contains(head), path.count == 1 else { continue }

                    throw refusal("writes over '\(head)', which it is still holding")

                case nil:
                    break
                }
            }

            guard let result = block.result else { return held }

            return try moving(result, held: held, guarded: guarded)
        }

        // MARK: - Private
        // What is still held after this expression is read.
        private func moving(_ expression: Expression, held: Held, guarded: String?) throws -> Held {
            switch expression {
            case .literal:
                return held

            // A bare name is the value itself, so reading it is handing it on.
            // A path below the name reads a part of it and hands nothing on.
            case let .reference(path):
                guard let head = path.head, path.count == 1 else { return held }

                guard held.live.contains(head) else {
                    guard held.moved.contains(head) else { return held }

                    throw refusal(
                        "hands '\(head)' on a second time. A value written `once`"
                            + " is gone from the name that held it once it is given away"
                    )
                }

                if let guarded {
                    throw refusal("hands '\(head)' on \(guarded), which happens no fixed number of times")
                }

                var moved = held
                moved.live.remove(head)
                moved.moved.insert(head)

                return moved

            case let .cast(value, _, _):
                return try moving(value, held: held, guarded: guarded)

            case let .array(elements):
                return try elements.reduce(held) { carried, element in
                    try moving(element, held: carried, guarded: guarded)
                }

            case let .record(record):
                return try record.sorted(by: { $0.key < $1.key }).reduce(held) { carried, field in
                    try moving(field.value, held: carried, guarded: guarded)
                }

            // A closure runs no fixed number of times, and what it captured it
            // would hand on once per run.
            case let .closure(procedure):
                guard let block = procedure.block else { return held }

                for name in held.live.sorted() where reads(block, name: name) {
                    throw refusal(
                        "captures '\(name)' in a closure, which runs no fixed"
                            + " number of times"
                    )
                }

                return held

            // Which value is called is settled at run time, so nothing here
            // says what it does with what it was handed.
            case let .apply(callee, arguments):
                var carried = try moving(callee, held: held, guarded: "in a call of a value")

                for (_, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                    carried = try moving(argument, held: carried, guarded: "in a call of a value")
                }

                return carried

            case let .call(call):
                return try moving(call, held: held, guarded: guarded)

            case let .block(block):
                return try through(block, held: held, guarded: guarded)

            // Every way through has to be holding the same thing at the end of
            // it, or what a body holds after the conditional would depend on
            // which arm ran, which is not something the text shows.
            case let .conditional(condition, then, otherwise):
                let asked = try moving(condition, held: held, guarded: guarded)
                let taken = try through(Block(body: then), held: asked, guarded: guarded)
                let left = try through(Block(body: otherwise ?? []), held: asked, guarded: guarded)

                guard taken.live == left.live else {
                    let parted = taken.live.symmetricDifference(left.live).sorted()

                    throw refusal(
                        "hands '\(parted[0])' on in one arm and not in the other."
                            + " What a body holds after a conditional is the same"
                            + " whichever arm ran"
                    )
                }

                return Held(live: taken.live, moved: taken.moved.union(left.moved))

            case let .loop(condition, body, _):
                let asked = try moving(condition, held: held, guarded: guarded)

                return try through(body, held: asked, guarded: "inside a loop")

            // A failure lands between statements, so which of the body's moves
            // happened is not something the text shows.
            case let .attempt(body, rescue, _):
                _ = try through(body, held: held, guarded: "inside an attempt")

                return try through(rescue, held: held, guarded: "inside an attempt")

            case let .leave(leave):
                let carried = try leave.value.map { value in
                    try moving(value, held: held, guarded: guarded)
                } ?? held

                guard let stranded = carried.live.sorted().first else { return carried }

                throw refusal("leaves while still holding '\(stranded)'")
            }
        }

        // A call hands its receiver and its arguments to slots the callee
        // declared, so a value handed on lands somewhere that says it takes
        // one. A slot that does not say so would let the obligation go.
        private func moving(_ call: Call, held: Held, guarded: String?) throws -> Held {
            let signature = context.signature(of: call.selector)
                ?? context.contractWords[call.selector]?.signature

            var carried = held

            if let receiver = call.receiver {
                try handed(
                    receiver,
                    to: signature?.receiver.flatMap { name in signature?.parameters[name] },
                    held: carried,
                    of: call
                )

                carried = try moving(receiver, held: carried, guarded: guarded)
            }

            for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
                try handed(argument, to: signature?.parameters[name], held: carried, of: call)

                carried = try moving(argument, held: carried, guarded: guarded)
            }

            return carried
        }

        // Whether the slot this is handed to takes a value handed on once.
        private func handed(
            _ argument: Expression,
            to parameter: Parameter?,
            held: Held,
            of call: Call
        ) throws {
            guard
                case let .reference(path) = argument,
                let head = path.head,
                held.live.contains(head),
                path.count == 1
            else {
                return
            }

            guard let parameter, handedOnce(parameter.declared) else {
                throw refusal(
                    "hands '\(head)' to '\(call.selector)', which does not take a"
                        + " value written `once`. What takes one says so, and"
                        + " what says so is what may keep it"
                )
            }
        }

        // What a binding's expression answers, and whether that is handed on
        // once. Read from the few shapes a value like this is born in: a word
        // that answers one, a cast that names one, and a name rebound to
        // another, which is the move that just happened.
        private func handedOnce(_ expression: Expression, held: Held) -> Bool {
            switch expression {
            case let .call(call):
                let signature = context.signature(of: call.selector)
                    ?? context.contractWords[call.selector]?.signature

                return signature?.returns.map(handedOnce) ?? false

            case let .cast(_, type, optional):
                return !optional && handedOnce(type)

            case let .reference(path):
                guard let head = path.head, path.count == 1 else { return false }

                return held.moved.contains(head)

            default:
                return false
            }
        }

        private func handedOnce(_ type: TypeExpression) -> Bool {
            switch type {
            case .once:
                return true

            case let .named(name):
                guard let declared = context.types.resolve(name) else { return false }

                return handedOnce(declared)

            case let .variable(inner), let .inout(inner):
                return handedOnce(inner)

            default:
                return false
            }
        }

        // Whether a block reads a name anywhere in it, at any depth.
        private func reads(_ block: Block, name: Name) -> Bool {
            block.subexpressions.contains { held in
                guard case let .reference(path) = held else { return false }

                return path.head == name
            }
        }

        private func refusal(_ said: String) -> BuildError {
            BuildError(said, at: place)
        }
    }
}
