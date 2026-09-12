//
//  Builder+Consuming.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// What a body does with the values it must hand on exactly once.
//
// A type written `linear` says the values of it are handed on: given to a procedure,
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
        case .linear:
            return true

        case let .named(name):
            guard let declared = table.resolve(name) else { return false }

            return handedOnce(declared, in: table)

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return handedOnce(inner, in: table)

        default:
            return false
        }
    }

    // Every value a body must hand on, handed on once. The declaration's own
    // slots are where such a value enters a body: `linear` is a document's
    // spelling and a value the link folded is a value, never a promise.
    func consumed(
        _ block: Block,
        at place: Place,
        holding signature: Signature,
        in context: TypingContext
    ) throws {
        let taken = signature.parameters.filter { _, parameter in
            if case .consuming = parameter.declared { return true }

            return false
        }
        let borrowed = signature.parameters.filter { _, parameter in
            if case .borrowing = parameter.declared { return true }

            return false
        }

        guard !taken.isEmpty || !borrowed.isEmpty || context.types.types.values.contains(where: { type in
            handedOnce(type, in: context.types)
        }) else {
            return
        }

        let walk = Consuming(context: context, place: place)
        let left = try walk.through(
            block,
            held: Consuming.Held(live: Set(taken.keys), borrowed: Set(borrowed.keys)),
            guarded: nil
        )

        guard let stranded = left.live.sorted().first else { return }

        throw BuildError(
            "still holds '\(stranded)' where it ends. A value written `linear` is"
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

            // What the body was handed to read and not to keep. A borrowed
            // name may be read and passed on to another slot that borrows, and
            // that is all: the obligation stayed with whoever handed it over,
            // and a body cannot give away what it never took.
            var borrowed: Set<Name> = []

            // How a name is being held, where it is one of these at all. One
            // reading, so every judgment about an operand is made from the
            // same fact rather than each asking the sets again.
            func holding(_ name: Name) -> Holding? {
                if live.contains(name) { return .live }
                if borrowed.contains(name) { return .borrowed }
                if moved.contains(name) { return .gone }

                return nil
            }

            // Two ways through, joined. Being handed on and being borrowed are
            // facts either way may have made, so both accumulate; what is
            // still held has to be the same on both, which the arms say where
            // they are judged. The rule lives here so that a field added later
            // is joined by whoever owns it rather than by every caller.
            func merged(with other: Held) -> Held {
                Held(
                    live: live,
                    moved: moved.union(other.moved),
                    borrowed: borrowed.union(other.borrowed)
                )
            }
        }

        enum Holding {
            case live
            case borrowed
            case gone
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
                    if case (let borrowed, .borrowed)? = operand(statement.expression, held: held) {
                        try refuseKeeping(borrowed, as: statement.binding)

                        held.borrowed.insert(name)

                        continue
                    }

                    guard handedOnce(statement.expression, held: held) else { continue }

                    held.live.insert(name)
                    held.moved.remove(name)

                // A write puts something else in the box, so what was there is
                // gone without having been handed on.
                case let .assignment(path)?:
                    if case (let borrowed, .borrowed)? = operand(statement.expression, held: held) {
                        throw refusal(kept: borrowed)
                    }

                    guard let head = path.head, held.live.contains(head), path.count == 1 else { continue }

                    throw refusal("writes over '\(head)', which it is still holding")

                case nil:
                    break
                }
            }

            guard let result = block.result else { return held }

            if case (let name, .borrowed)? = operand(result, held: held) {
                throw refusal(answered: name)
            }

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

                    throw refusal(handedTwice: head)
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

                // The same fact from the other side: this walk never enters a
                // closure, so what a borrowed name does in there is not
                // something the text shows, and the one thing a borrow is
                // proven by is being read where it is written.
                for name in held.borrowed.sorted() where reads(block, name: name) {
                    throw refusal(
                        "captures '\(name)' in a closure, and it borrowed"
                            + " '\(name)' rather than taking it. A closure runs"
                            + " where the lending call cannot see"
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

                return taken.merged(with: left)

            case let .loop(condition, body, _):
                let asked = try moving(condition, held: held, guarded: guarded)

                return try through(body, held: asked, guarded: "inside a loop")

            // A failure lands between statements, so which of the body's moves
            // happened is not something the text shows.
            case let .attempt(body, rescue, _):
                _ = try through(body, held: held, guarded: "inside an attempt")

                return try through(rescue, held: held, guarded: "inside an attempt")

            case let .leave(leave):
                if let value = leave.value, case (let name, .borrowed)? = operand(value, held: held) {
                    throw refusal(answered: name)
                }

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
                ?? context.contractProcedures[call.selector]?.signature

            var carried = held

            if let receiver = call.receiver {
                let parameter = signature?.receiver.flatMap { name in signature?.parameters[name] }

                carried = try handed(receiver, to: parameter, held: carried, guarded: guarded, of: call)
            }

            for (name, argument) in call.arguments.sorted(by: { $0.key < $1.key }) {
                carried = try handed(
                    argument,
                    to: signature?.parameters[name],
                    held: carried,
                    guarded: guarded,
                    of: call
                )
            }

            return carried
        }

        // The name an operand wrote and how the body is holding it, where the
        // operand is a bare name at all. Reading a part of a value answers a
        // value of its own, and nothing rides out with it.
        private func operand(_ expression: Expression, held: Held) -> (name: Name, holding: Holding)? {
            guard
                case let .reference(path) = expression,
                let head = path.head,
                path.count == 1,
                let holding = held.holding(head)
            else {
                return nil
            }

            return (head, holding)
        }

        // A second name for a borrowed value is a second name for the same
        // borrow, and a box is not: a box outlives the call.
        private func refuseKeeping(_ borrowed: Name, as binding: Statement.Binding?) throws {
            guard case .variable = binding else { return }

            throw refusal(kept: borrowed)
        }

        // One operand of a call, judged and then read. What the slot says it
        // does is asked after how the body is holding the name, because a name
        // already given away is given away whatever the slot says.
        private func handed(
            _ argument: Expression,
            to parameter: Parameter?,
            held: Held,
            guarded: String?,
            of call: Call
        ) throws -> Held {
            guard let written = operand(argument, held: held) else {
                return try moving(argument, held: held, guarded: guarded)
            }

            switch (written.holding, parameter?.declared) {
            // The name is gone, and nothing a slot says brings it back.
            case (.gone, _):
                throw refusal(handedTwice: written.name)

            // A borrow passes to another borrow and stops there.
            case (.borrowed, .borrowing):
                return held

            case (.borrowed, _):
                throw refusal(
                    "hands '\(written.name)' to '\(call.selector)', and it borrowed"
                        + " '\(written.name)' rather than taking it. What a body"
                        + " borrowed it may read and pass to another slot that borrows"
                )

            // Lending what this body owes leaves the obligation where it is.
            case (.live, .borrowing):
                return held

            case (.live, .consuming):
                return try moving(argument, held: held, guarded: guarded)

            case (.live, _):
                throw refusal(
                    "hands '\(written.name)' to '\(call.selector)', which says nothing"
                        + " about what it does with a value written `linear`. A slot"
                        + " takes the obligation by writing `consuming`, or reads the"
                        + " value and leaves it by writing `borrowing`"
                )
            }
        }

        // What a binding's expression answers, and whether that is handed on
        // once. Read from the few types a value like this is born in: a procedure
        // that answers one, a cast that names one, and a name rebound to
        // another, which is the move that just happened.
        private func handedOnce(_ expression: Expression, held: Held) -> Bool {
            switch expression {
            case let .call(call):
                let signature = context.signature(of: call.selector)
                    ?? context.contractProcedures[call.selector]?.signature

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
            case .linear:
                return true

            case let .named(name):
                guard let declared = context.types.resolve(name) else { return false }

                return handedOnce(declared)

            case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
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

        // One rule, one sentence, wherever the rule is broken.
        private func refusal(handedTwice name: Name) -> BuildError {
            refusal(
                "hands '\(name)' on a second time. A value written `linear` is gone"
                    + " from the name that held it once it is given away"
            )
        }

        private func refusal(answered name: Name) -> BuildError {
            refusal(
                "answers '\(name)', and it borrowed '\(name)' rather than taking it."
                    + " What a body answers its caller then owes, and this body never"
                    + " owed it"
            )
        }

        private func refusal(kept name: Name) -> BuildError {
            refusal(
                "keeps '\(name)' in a box, and it borrowed '\(name)' rather than"
                    + " taking it. A box outlives the call that lent the value"
            )
        }

        private func refusal(_ said: String) -> BuildError {
            BuildError(said, at: place)
        }
    }
}
