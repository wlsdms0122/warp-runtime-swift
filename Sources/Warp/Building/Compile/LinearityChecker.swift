//
//  LinearityChecker.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// What a body does with the values it must hand on exactly once.
//
// A type written `linear` says the values of it are handed on: given to a procedure,
// or answered. A body holding one has to do that on every way through, and may
// not do it twice, and the build says so before anything runs. That is the whole
// of what "this resource is closed exactly once" means here.
//
// The walk refuses wherever it cannot see: a value handed to a value call, a
// value a closure captured, a value moved inside a loop round or an attempt.
// Each of those is a place where "how many times" is not a fact the text shows,
// and a proof that admits one of them is not a proof.
struct LinearityChecker {
    private final class Consuming {
        // What a body is holding, and what it has already handed on. The two
        // are apart because they answer different refusals: one is a value
        // dropped, the other a value handed on twice, and a name that has
        // gone from the first without reaching the second is a name that was
        // never one of these.
        struct Held {
            // How a name is being held, where it is one of these at all. One
            // reading, so every judgment about an operand is made from the
            // same fact rather than each asking the sets again.
            enum Holding {
                case live
                case borrowed
                case gone
            }

            // A name the body around a nested one holds, hidden while the
            // nested body introduces its spelling and held again as it was
            // once that body ends. Nothing reaches the outer name meanwhile:
            // every reading of the spelling inside is the new name.
            struct Hidden {
                let name: Name
                let holding: Holding?
                let linear: Bool
            }

            // MARK: - Property
            var live: Set<Name>
            var moved: Set<Name> = []

            // What the body was handed to read and not to keep. A borrowed
            // name may be read and passed on to another slot that borrows, and
            // that is all: the obligation stayed with whoever handed it over,
            // and a body cannot give away what it never took.
            var borrowed: Set<Name> = []

            // The names whose slot declares a type written `linear`: a write
            // into one takes the obligation whatever wrote the value, since
            // the slot naming the type carries it.
            var linear: Set<Name> = []

            // Whether this way through ended the body. Only leaving the
            // procedure does: a run comes back out of a loop from a `break`
            // still holding what the way through held.
            var endsTheBody = false

            // Whether the value just read carries an obligation: read off a
            // name that held one, or answered by a call or a cast declaring
            // one. Whatever takes the value takes the obligation with it. Read
            // where the value is, so a block's answer is judged among the
            // names the block introduced.
            var owed = false

            // MARK: - Initializer
            // MARK: - Public
            func holding(_ name: Name) -> Holding? {
                if live.contains(name) { return .live }
                if borrowed.contains(name) { return .borrowed }
                if moved.contains(name) { return .gone }

                return nil
            }

            // The spelling taken by a name a body introduces: the name around
            // it is hidden, and the new one starts holding nothing.
            mutating func hiding(_ name: Name) -> Hidden {
                let hidden = Hidden(name: name, holding: holding(name), linear: linear.contains(name))

                live.remove(name)
                moved.remove(name)
                borrowed.remove(name)
                linear.remove(name)

                return hidden
            }

            // The name a nested body hid, held again as it was.
            mutating func restoring(_ hidden: Hidden) {
                live.remove(hidden.name)
                moved.remove(hidden.name)
                borrowed.remove(hidden.name)
                linear.remove(hidden.name)

                switch hidden.holding {
                case .live?:
                    live.insert(hidden.name)

                case .borrowed?:
                    borrowed.insert(hidden.name)

                case .gone?:
                    moved.insert(hidden.name)

                case nil:
                    break
                }

                if hidden.linear {
                    linear.insert(hidden.name)
                }
            }

            // Two ways through, joined. Being handed on and being borrowed are
            // facts either way may have made, so both accumulate; what is
            // still held has to be the same on both, which the arms say where
            // they are judged.
            func merged(with other: Held) -> Held {
                Held(
                    live: live,
                    moved: moved.union(other.moved),
                    borrowed: borrowed.union(other.borrowed),
                    linear: linear.union(other.linear),
                    endsTheBody: endsTheBody && other.endsTheBody
                )
            }

            // MARK: - Private
        }

        // MARK: - Property
        let context: TypingContext
        let place: Place

        // Whether some way out of this body hands the caller an obligation.
        // Not one of `Held`'s fields: an `attempt` goes on with its rescue's
        // `Held`, and what its body handed out stays handed out.
        private(set) var handsOut = false

        // MARK: - Initializer
        init(context: TypingContext, place: Place) {
            self.context = context
            self.place = place
        }

        // MARK: - Public
        // What is still held after this block. `guarded` is why a move is
        // refused here, and nil where one is allowed. A name the block
        // introduces goes no further than the block, so one still holding
        // its value where the block ends has dropped it, and a name it hid
        // is held again as it was. `asPart` says the block stands as an
        // element or a field, where its result is written as one.
        func through(_ block: Block, held: Held, guarded: String?, asPart: Bool = false) throws -> Held {
            var held = held
            var hidden: [Held.Hidden] = []

            for statement in block.body.statements {
                // A borrowed name written bare is judged here, before the walk,
                // because the walk refuses one wherever a value leaves by and
                // a second name for the same borrow is not that.
                if case let (borrowed, .borrowed)? = operand(statement.expression, held: held) {
                    switch statement.binding {
                    case let .constant(name, _)?:
                        hidden.append(held.hiding(name))
                        held.borrowed.insert(name)

                    case .variable?, .assignment?:
                        throw refusal(kept: borrowed)

                    case nil:
                        break
                    }

                    continue
                }

                switch statement.binding {
                case let .constant(name, declared)?, let .variable(name, declared)?:
                    held = try moving(statement.expression, held: held, guarded: guarded)
                    hidden.append(held.hiding(name))

                    if declared?.handedOnce(in: context.types) == true {
                        held.linear.insert(name)
                    }

                    guard held.linear.contains(name) || held.owed else { continue }

                    held.live.insert(name)

                case let .assignment(path)?:
                    held = try written(statement.expression, into: path, held: held, guarded: guarded)

                case nil:
                    held = try moving(statement.expression, held: held, guarded: guarded)
                }
            }

            if let result = block.result {
                if case let (name, .borrowed)? = operand(result, held: held) {
                    throw refusal(answered: name)
                }

                held = try asPart
                    ? carrying(result, held: held, guarded: guarded)
                    : moving(result, held: held, guarded: guarded)
            } else {
                held.owed = false
            }

            if let stranded = hidden.map(\.name).first(where: held.live.contains) {
                throw refusal(stranded: stranded)
            }

            for outer in hidden.reversed() {
                held.restoring(outer)
            }

            return held
        }

        // A declaration's own body, walked. Its result is a way out of the
        // procedure the way a `return` is, which an inner block's result is
        // not, so the one entry that knows which block this is says so.
        func answering(_ block: Block, held: Held) throws {
            let left = try through(block, held: held, guarded: nil)

            if left.owed {
                handsOut = true
            }

            guard let stranded = left.live.sorted().first else { return }

            throw refusal(stranded: stranded)
        }

        // MARK: - Private
        // What is still held after this expression is read.
        private func moving(_ expression: Expression, held: Held, guarded: String?) throws -> Held {
            var held = held
            held.owed = false

            switch expression {
            case .literal:
                return held

            // A bare name is the value itself, so reading it is handing it on.
            // A path below the name reads a part of it and hands nothing on.
            case let .reference(path):
                guard let head = path.head, path.segments.count == 1 else { return held }

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

                held.live.remove(head)
                held.moved.insert(head)
                held.owed = true

                return held

            // A cast hands on what it read. Where that is nothing a name
            // held, the type it names is what says the value is one.
            case let .cast(value, type, _):
                var cast = try moving(value, held: held, guarded: guarded)
                cast.owed = cast.owed || type.handedOnce(in: context.types)

                return cast

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

                // A closure is a procedure and its body is text, so the same
                // walk runs over it, seeded with what the closure itself was
                // handed rather than with what the body around it holds. The
                // two do not meet: a name from out here reaching in is the
                // capture the checks below refuse.
                //
                // What such a body may not do is answer one. Nothing reads
                // inside a body that travels as a value, so what it handed back
                // would arrive with nothing to say it is owed. Read from the
                // walk rather than from whether a `returns` was typed, and read
                // the same whichever way the body answers.
                let inside = Consuming(context: context, place: place)
                let seeded = procedure.signature.parameters
                let taken = Set(seeded.filter { parameter in
                    if case .consuming = parameter.declared { return true }

                    return false
                }.map(\.name))

                try inside.answering(
                    block,
                    held: Held(
                        live: taken,
                        borrowed: Set(seeded.filter { parameter in
                            if case .borrowing = parameter.declared { return true }

                            return false
                        }.map(\.name)),
                        linear: taken
                    )
                )

                guard !inside.handsOut else {
                    throw refusal(
                        "carries a body answering a value handed on exactly once."
                            + " \(LinearityChecker.followedByAName), and a body carried as a"
                            + " value runs where no name is watching"
                    )
                }

                for name in held.live.sorted() where reads(procedure, name: name) {
                    throw refusal(
                        "captures '\(name)' in a closure, which runs no fixed"
                            + " number of times"
                    )
                }

                for name in held.borrowed.sorted() where reads(procedure, name: name) {
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

                for argument in arguments {
                    carried = try moving(argument, held: carried, guarded: "in a call of a value")
                }

                carried.owed = false

                return carried

            // What the declaration says it answers. One that wrote no `returns`
            // is read off its body, and the mark does not survive that reading,
            // so a declaration whose body answers one is held to writing it.
            case let .call(call):
                var called = try moving(call, held: held, guarded: guarded)
                called.owed = context.signature(of: call.selector)?.returns?.handedOnce(in: context.types) == true

                return called

            case let .block(block):
                return try through(block, held: held, guarded: guarded)

            // Every way through has to be holding the same thing at the end of
            // it, or what a body holds after the conditional would depend on
            // which arm ran, which is not something the text shows. An arm that
            // ends the body is not one of those ways: no run comes back from
            // it, so what the body holds afterwards stands on the arms that
            // finish.
            case let .conditional(condition, then, otherwise):
                let asked = try moving(condition, held: held, guarded: guarded)
                let taken = try through(Block(body: then), held: asked, guarded: guarded)
                let left = try through(Block(body: otherwise ?? []), held: asked, guarded: guarded)

                switch (taken.endsTheBody, left.endsTheBody) {
                case (true, false):
                    return left

                case (false, true):
                    return taken

                // Both arms ended the body, and a body is not ended while
                // still holding one, so there is nothing left for the two of
                // them to disagree about.
                case (true, true):
                    return taken.merged(with: left)

                case (false, false):
                    guard taken.live == left.live else {
                        let parted = taken.live.symmetricDifference(left.live).sorted()

                        throw refusal(
                            "hands '\(parted[0])' on in one arm and not in the other."
                                + " What a body holds after a conditional is the same"
                                + " whichever arm ran"
                        )
                    }

                    return taken.merged(with: left)
                }

            case let .loop(condition, body):
                let asked = try moving(condition, held: held, guarded: guarded)
                var rounds = try through(body, held: asked, guarded: "inside a loop")

                // A round may not run at all, so a loop is a way through
                // whatever its body does.
                rounds.endsTheBody = false

                return rounds

            // A failure lands between statements, so which of the body's moves
            // happened is not something the text shows. What finishes is the
            // body's own end or the rescue's, so an attempt leaves where both
            // of them do, holding what either way took.
            case let .attempt(body, rescue):
                let attempted = try through(body, held: held, guarded: "inside an attempt")
                var rescued = try through(rescue, held: held, guarded: "inside an attempt")

                rescued.live.formUnion(attempted.live)
                rescued.endsTheBody = attempted.endsTheBody && rescued.endsTheBody
                rescued.owed = attempted.owed || rescued.owed

                return rescued

            case let .leave(leave):
                if let value = leave.value, case let (name, .borrowed)? = operand(value, held: held) {
                    throw refusal(answered: name)
                }

                var carried = try leave.value.map { value in
                    try moving(value, held: held, guarded: guarded)
                } ?? held

                // A `return` hands a value to the caller the way a result does,
                // so it is asked the same question at the same moment: after
                // the move, where a name that was handed on reads as gone.
                // Only leaving the procedure ends the body. A `break` leaves the
                // construct and a `continue` ends the round, and what the body
                // was holding it holds still on the other side of either.
                guard leave.reach == .procedure else { return carried }

                carried.endsTheBody = true

                if carried.owed {
                    handsOut = true
                }

                guard let stranded = carried.live.sorted().first else { return carried }

                throw refusal("leaves while still holding '\(stranded)'")
            }
        }

        // A call hands its arguments to slots the callee declared, so a value
        // handed on lands somewhere that says it takes one. A slot that does
        // not say so would let the obligation go. The walk hands them in
        // position order, the order the run evaluates them in.
        private func moving(_ call: Call, held: Held, guarded: String?) throws -> Held {
            let parameters = context.signature(of: call.selector)?.parameters ?? []

            var carried = held

            for (position, argument) in call.arguments.enumerated() {
                carried = try handed(
                    argument,
                    to: parameters.indices.contains(position) ? parameters[position] : nil,
                    held: carried,
                    guarded: guarded,
                    of: call
                )
            }

            return carried
        }

        // A write into a box. Written whole, the box takes what the value
        // carries the way a binding does, and what was there is gone without
        // having been handed on. Written below the name, the value goes inside
        // the list or record the box holds.
        private func written(_ expression: Expression, into path: Path, held: Held, guarded: String?) throws -> Held {
            guard let head = path.head, path.segments.count == 1 else {
                return try carrying(expression, held: held, guarded: guarded)
            }

            var written = try moving(expression, held: held, guarded: guarded)

            guard !written.live.contains(head) else {
                throw refusal("writes over '\(head)', which it is still holding")
            }

            guard written.linear.contains(head) || written.owed else { return written }

            if let guarded {
                throw refusal("writes one into '\(head)' \(guarded), which happens no fixed number of times")
            }

            written.live.insert(head)
            written.moved.remove(head)

            return written
        }

        // One element of a list or one field of a record. What a value written
        // there does is not something a name follows: the walk tracks names,
        // and a name does not go into a type. So one still held may not be
        // written into either, the same rule a declared type is held to.
        private func carrying(_ expression: Expression, held: Held, guarded: String?) throws -> Held {
            if let (name, holding) = operand(expression, held: held) {
                throw holding == .gone ? refusal(handedTwice: name) : refusal(carried: name)
            }

            if case let .block(block) = expression {
                return try through(block, held: held, guarded: guarded, asPart: true)
            }

            let carried = try moving(expression, held: held, guarded: guarded)

            guard !carried.owed else { throw refusal(carriedValue: expression) }

            return carried
        }

        private func operand(_ expression: Expression, held: Held) -> (name: Name, holding: Held.Holding)? {
            guard
                case let .reference(path) = expression,
                let head = path.head,
                path.segments.count == 1,
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
                // A slot that borrows leaves the obligation with the caller, so
                // a value no name holds would be owed by nobody once it is
                // read.
                if case .borrowing? = parameter?.declared {
                    throw refusal(
                        "hands '\(call.selector)' a value no name holds, and the slot borrows it."
                            + " \(LinearityChecker.followedByAName), so it is bound to one first"
                    )
                }

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

        // Whether a closure's body reads the name around it, at any depth. A
        // body introducing the spelling reads its own name from the statement
        // after on, and a closure taking it as a parameter reads its own
        // throughout.
        private func reads(_ procedure: Procedure, name: Name) -> Bool {
            guard !procedure.signature.names.contains(name), let block = procedure.block else { return false }

            return reads(block.body, then: block.result, name: name)
        }

        private func reads(_ body: Body, then result: Expression?, name: Name) -> Bool {
            for statement in body.statements {
                if reads(statement.expression, name: name) { return true }
                if statement.binding?.introduced == name { return false }
            }

            return result.map { result in reads(result, name: name) } ?? false
        }

        private func reads(_ expression: Expression, name: Name) -> Bool {
            switch expression {
            case .literal:
                return false

            case let .reference(path):
                return path.expandingIndexReferences.contains { path in path.head == name }

            case let .array(elements):
                return elements.contains { element in reads(element, name: name) }

            case let .record(fields):
                return fields.values.contains { field in reads(field, name: name) }

            case let .closure(procedure):
                return reads(procedure, name: name)

            case let .apply(callee, arguments):
                return ([callee] + arguments).contains { operand in reads(operand, name: name) }

            case let .cast(value, _, _):
                return reads(value, name: name)

            case let .block(block):
                return reads(block.body, then: block.result, name: name)

            case let .conditional(condition, then, otherwise):
                return reads(condition, name: name)
                    || reads(then, then: nil, name: name)
                    || reads(otherwise ?? [], then: nil, name: name)

            case let .loop(condition, body):
                return reads(condition, name: name) || reads(body.body, then: body.result, name: name)

            case let .attempt(body, rescue):
                return reads(body.body, then: body.result, name: name)
                    || reads(rescue.body, then: rescue.result, name: name)

            case let .call(call):
                return call.arguments.contains { argument in reads(argument, name: name) }

            case let .leave(leave):
                return leave.value.map { value in reads(value, name: name) } ?? false
            }
        }

        private func refusal(stranded name: Name) -> BuildError {
            refusal(
                "still holds '\(name)' where it ends. A value written `linear` is"
                    + " handed on, and a body that reaches its end holding one has"
                    + " dropped it"
            )
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

    // MARK: - Property
    // Why a doubt and an obligation do not stand over one value. Said once
    // because the two doors that refuse it (a `?` written on a declared type,
    // an `as?` reading one) refuse it for the one reason; what each of them is
    // refusing is its own sentence, because the subjects differ.
    static let followedByAName =
        "A value handed on once is followed by a name that holds it on every way"
            + " through"

    // MARK: - Initializer
    // MARK: - Public
    // Every value a body must hand on, handed on once. The declaration's own
    // slots are where such a value enters a body: `linear` is a document's
    // spelling and a folded value is a value, never a promise.
    func consumed(
        _ block: Block,
        at place: Place,
        holding signature: Signature,
        in context: TypingContext
    ) throws {
        let taken = signature.parameters.filter { parameter in
            if case .consuming = parameter.declared { return true }

            return false
        }
        let borrowed = signature.parameters.filter { parameter in
            if case .borrowing = parameter.declared { return true }

            return false
        }

        guard !taken.isEmpty || !borrowed.isEmpty || context.types.types.values.contains(where: { type in
            type.handedOnce(in: context.types)
        }) else {
            return
        }

        let walk = Consuming(context: context, place: place)
        try walk.answering(
            block,
            held: Consuming.Held(
                live: Set(taken.map(\.name)),
                borrowed: Set(borrowed.map(\.name)),
                linear: Set(taken.map(\.name))
            )
        )

        // What a declaration answers is read off its body where nobody wrote
        // `returns`, and the mark does not survive that reading. So a body
        // answering one is held to writing what it answers, or the caller
        // binding it would take an obligation nothing told it about.
        if signature.returns == nil, walk.handsOut {
            throw BuildError(
                "answers a value handed on exactly once and does not write"
                    + " `returns`. What a declaration answers is read off its body"
                    + " where nobody wrote it, and the mark is not something a"
                    + " reading keeps",
                at: place.child(.result)
            )
        }
    }

    // MARK: - Private
}
