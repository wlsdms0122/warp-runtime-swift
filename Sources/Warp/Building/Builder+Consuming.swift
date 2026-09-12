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
    static func handedOnce(
        _ type: TypeExpression,
        in table: TypeTable,
        assuming: Set<Name> = []
    ) -> Bool {
        switch type {
        case .linear:
            return true

        case let .named(name):
            if let declared = table.resolve(name) {
                return handedOnce(declared, in: table, assuming: assuming)
            }

            return handedOnce(membership: name, in: table, assuming: assuming)

        // A parameter bounded by a membership stands for some member of it, so
        // what every member is, it is. An unbounded one stands for whatever the
        // call put there, which the build never wrote down.
        case let .parameter(_, bound):
            guard let bound else { return false }

            return handedOnce(membership: bound, in: table, assuming: assuming)

        case let .variable(inner), let .inout(inner), let .consuming(inner), let .borrowing(inner):
            return handedOnce(inner, in: table, assuming: assuming)

        // A nullable of one is refused where it is written, because "hand it on
        // if it is there" is not something this language says. So nothing is
        // one behind a `?`.
        case .nullable:
            return false

        // None of these is one, and none of them carries one: a value handed on
        // once is followed by the name that holds it, and a name does not go
        // into a type. Said out loud rather than defaulted, the way the walk's
        // own reading is.
        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes,
            .ranged, .array, .dictionary, .record, .procedure, .reading:
            return false
        }
    }

    // A membership is one when every member is. A membership this question is
    // already inside is taken as it stood rather than asked again, which is
    // what every other question about a membership does here: a ring answers
    // what the question started with, and `allSatisfy` starts at true.
    private static func handedOnce(
        membership name: Name,
        in table: TypeTable,
        assuming: Set<Name>
    ) -> Bool {
        guard let reached = reaches(membership: name, in: table, assuming: assuming) else { return false }

        return reached
    }

    // The same question, answering nil where the walk only ever came back to a
    // membership it was already inside. A ring says nothing new, so a ring of
    // nothing else says nothing at all, and a membership no value can be is not
    // one of these any more than an empty one is.
    private static func reaches(
        membership name: Name,
        in table: TypeTable,
        assuming: Set<Name>
    ) -> Bool? {
        guard !assuming.contains(name) else { return nil }

        guard let members = table.constraint(name), !members.isEmpty else { return false }

        let answers = members.compactMap { member -> Bool? in
            guard case let .named(inner) = member, table.resolve(inner) == nil else {
                return handedOnce(member, in: table, assuming: assuming.union([name]))
            }

            return reaches(membership: inner, in: table, assuming: assuming.union([name]))
        }

        guard !answers.isEmpty else { return nil }

        return answers.allSatisfy { answer in answer }
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
            Builder.handedOnce(type, in: context.types)
        }) else {
            return
        }

        let walk = Consuming(context: context, place: place)
        let left = try walk.through(
            block,
            held: Consuming.Held(live: Set(taken.keys), borrowed: Set(borrowed.keys)),
            guarded: nil
        )

        // What a declaration answers is read off its body where nobody wrote
        // `returns`, and the mark does not survive that reading. So a body
        // answering one is held to writing what it answers, or the caller
        // binding it would take an obligation nothing told it about.
        if signature.returns == nil, walk.answers(block.result, after: left) {
            throw BuildError(
                "answers a value handed on exactly once and does not write"
                    + " `returns`. What a declaration answers is read off its body"
                    + " where nobody wrote it, and the mark is not something a"
                    + " reading keeps",
                at: place.part(.result)
            )
        }

        guard let stranded = left.live.sorted().first else { return }

        throw BuildError(
            "still holds '\(stranded)' where it ends. A value written `linear` is"
                + " handed on, and a body that reaches its end holding one has"
                + " dropped it",
            at: place
        )
    }

    // MARK: - Private
    private final class Consuming {
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
            enum Holding {
                case live
                case borrowed
                case gone
            }

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

        // What an expression hands out.
        enum HandedOut {
            case name(Name, Held.Holding)
            case value
            case nothing
        }

        let context: TypingContext
        let place: Place

        // Whether any way out of this body hands the caller an obligation. The
        // walk records it rather than answering it, because the refusal it
        // feeds is about the declaration and the walk is about the body.
        private(set) var answered = false

        init(context: TypingContext, place: Place) {
            self.context = context
            self.place = place
        }

        // What is still held after this block. `guarded` is why a move is
        // refused here, and nil where one is allowed.
        func through(_ block: Block, held: Held, guarded: String?) throws -> Held {
            var held = held

            for statement in block.body {
                // A borrowed name written bare is judged here, before the walk,
                // because the walk refuses one wherever a value leaves by and
                // a second name for the same borrow is not that.
                if case (let borrowed, .borrowed)? = operand(statement.expression, held: held) {
                    switch statement.binding {
                    case let .constant(name, _)?:
                        held.borrowed.insert(name)

                    case .variable?, .assignment?:
                        throw refusal(kept: borrowed)

                    case nil:
                        break
                    }

                    continue
                }

                held = try moving(statement.expression, held: held, guarded: guarded)

                switch statement.binding {
                case let .constant(name, _)?, let .variable(name, _)?:
                    guard carriesObligation(statement.expression, held: held) else { continue }

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

                // Everywhere a borrowed name may stand is read before the walk
                // reaches it: an operand of a slot that borrows, a second name
                // for the same borrow, and the two places a body answers from.
                // So reaching here is the name leaving by some other way.
                guard !held.borrowed.contains(head) else { throw refusal(gaveAway: head) }

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
                    try carrying(element, held: carried, guarded: guarded)
                }

            case let .record(record):
                return try record.sorted(by: { $0.key < $1.key }).reduce(held) { carried, field in
                    try carrying(field.value, held: carried, guarded: guarded)
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

                // A `return` hands a value to the caller the way a result does,
                // so what it hands out is asked here and read where the
                // declaration is judged.
                if
                    leave.reach == .procedure,
                    let value = leave.value,
                    carriesObligation(value, held: held)
                {
                    answered = true
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

        // One element of a list or one field of a record. What a value written
        // there does is not something a name follows: the walk tracks names,
        // and a name does not go into a type. So one still held may not be
        // written into either, the same rule a declared type is held to.
        private func carrying(_ expression: Expression, held: Held, guarded: String?) throws -> Held {
            switch handedOut(expression, held: held) {
            case let .name(name, holding):
                throw holding == .gone ? refusal(handedTwice: name) : refusal(carried: name)

            case .value:
                throw refusal(carriedValue: expression)

            // A block runs its statements wherever it stands, and what they do
            // with a name is the walk's business even where the block hands
            // nothing out.
            case .nothing:
                guard case let .block(block) = expression else {
                    return try moving(expression, held: held, guarded: guarded)
                }

                let inside = try through(Block(body: block.body), held: held, guarded: guarded)

                guard let result = block.result else { return inside }

                return try carrying(result, held: inside, guarded: guarded)
            }
        }

        // Whether the body hands the caller an obligation, by its result or by
        // any `return` in it. Asked from outside for the one refusal that is
        // about the declaration rather than the body.
        func answers(_ result: Expression?, after held: Held) -> Bool {
            answered || result.map { written in carriesObligation(written, held: held) } == true
        }

        private func operand(_ expression: Expression, held: Held) -> (name: Name, holding: Held.Holding)? {
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

        // Whether the value this expression answers carries an obligation.
        // A different question from whether a *type* is one of these.
        //
        // Written out shape by shape with no `default`, because a shape nobody
        // thought about must be a compile error here rather than an answer of
        // no: every hole this walk has had was a shape that fell through to
        // false and took an obligation with it.
        // What this expression hands out, where that is an obligation at all.
        //
        // Said once, because the three questions this walk asks of a value are
        // the same question about the same tree: may it stand in a list, whom
        // does a refusal name, and does binding it take the obligation. Three
        // walks over the shapes had to stay in step and nothing made them.
        //
        // No `default`: a shape nobody thought about must be a compile error
        // here rather than an answer of no. Every hole this walk has had was a
        // shape that fell through to false and took an obligation with it.
        private func handedOut(_ expression: Expression, held: Held) -> HandedOut {
            switch expression {
            // A literal is data, a closure is a procedure, and a list or a
            // record is neither: what a name may not go into cannot come out of
            // one either. A conditional answers nothing and a leave never comes
            // back. Which procedure a value is, is the run's answer, so nothing
            // here says what calling it answers.
            case .literal, .closure, .array, .record, .conditional, .leave, .apply:
                return .nothing

            // A bare name, as the body is holding it. A path below the name
            // reads a part of the value and nothing rides out with it.
            case let .reference(path):
                guard
                    let head = path.head,
                    path.count == 1,
                    let holding = held.holding(head)
                else {
                    return .nothing
                }

                return .name(head, holding)

            // What the declaration says it answers. One that wrote no `returns`
            // is read off its body, and the mark does not survive that reading,
            // so a declaration whose body answers one is held to writing it.
            case let .call(call):
                let signature = context.signature(of: call.selector)
                    ?? context.contractProcedures[call.selector]?.signature

                guard
                    let returns = signature?.returns,
                    Builder.handedOnce(returns, in: context.types)
                else {
                    return .nothing
                }

                return .value

            // A cast hands out what it read. Where that is nothing a name
            // holds, the type it names is what says the value is one.
            case let .cast(value, type, _):
                switch handedOut(value, held: held) {
                case .nothing:
                    return Builder.handedOnce(type, in: context.types) ? .value : .nothing

                case let answered:
                    return answered
                }

            // Each of these answers what some inner expression answers. An
            // attempt answers by either way through it, and a value handed out
            // by one of them is one the other cannot take back, so either is
            // enough to say so.
            case let .block(block):
                return block.result.map { result in handedOut(result, held: held) } ?? .nothing

            case let .loop(_, body, _):
                return body.result.map { result in handedOut(result, held: held) } ?? .nothing

            case let .attempt(block, rescue, _):
                let attempted = block.result.map { result in handedOut(result, held: held) } ?? .nothing

                guard case .nothing = attempted else { return attempted }

                return rescue.result.map { result in handedOut(result, held: held) } ?? .nothing
            }
        }

        // Whether binding this expression's answer to a name takes an
        // obligation with it. A name the body just handed on is one, and so is
        // a value nothing holds.
        private func carriesObligation(_ expression: Expression, held: Held) -> Bool {
            switch handedOut(expression, held: held) {
            case .value, .name(_, .gone):
                return true

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

        private func refusal(gaveAway name: Name) -> BuildError {
            refusal(
                "gives '\(name)' away, and it borrowed '\(name)' rather than taking"
                    + " it. What a body borrowed it may read, and pass to another"
                    + " slot that borrows"
            )
        }

        private func refusal(carried name: Name) -> BuildError {
            refusal(
                "carries '\(name)' inside a list or a record, and a value written"
                    + " `linear` is followed by the name that holds it. Nothing"
                    + " follows one into a type"
            )
        }

        private func refusal(carriedValue expression: Expression) -> BuildError {
            let written: String

            switch expression {
            case let .call(call):
                written = "what '\(call.selector)' answers"

            case let .cast(_, type, _):
                written = "what this reads as '\(type.rendered)'"

            default:
                written = "a value handed on once"
            }

            return refusal(
                "writes \(written) inside a list or a record, and a value handed on"
                    + " once is followed by the name that holds it. Nothing follows"
                    + " one into a type, so it is bound to a name and handed on from"
                    + " there"
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
