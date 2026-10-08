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
        // never one of these. Beside them, which name each spelling reads,
        // and whether the value just read carries an obligation.
        struct Held {
            // How a name is being held, where it is one of these at all. One
            // reading, so every judgment about an operand is made from the
            // same fact rather than each asking the sets again.
            enum Holding {
                case live
                case borrowed
                case gone
            }

            // One name as a body introduced it. A nested body may introduce a
            // spelling the body around it holds, and the two are different
            // names, each holding its own value: which of them a spelling
            // reads is the scope's to say. A name no body introduced, a
            // parameter or one the module binds, is its spelling's first, and
            // no body introduces that spelling again.
            struct Local: Hashable, Comparable {
                // MARK: - Property
                let name: Name
                let introduction: Int

                // MARK: - Initializer
                init(_ name: Name, introduction: Int = 0) {
                    self.name = name
                    self.introduction = introduction
                }

                // MARK: - Public
                static func < (lhs: Local, rhs: Local) -> Bool {
                    (lhs.name, lhs.introduction) < (rhs.name, rhs.introduction)
                }

                // MARK: - Private
            }

            // MARK: - Property
            // Which name each spelling reads here. A spelling missing from it
            // reads its first.
            var scope: [Name: Local] = [:]

            var live: Set<Local>
            var moved: Set<Local> = []

            // What the body was handed to read and not to keep. A borrowed
            // name may be read and passed on to another slot that borrows, and
            // that is all: the obligation stayed with whoever handed it over,
            // and a body cannot give away what it never took.
            var borrowed: Set<Local> = []

            // The names whose slot declares a type written `linear`: a write
            // into one takes the obligation whatever wrote the value, since
            // the slot naming the type carries it.
            var linear: Set<Local> = []

            // Whether this way through ended the body. Only leaving the
            // procedure does: a run comes back out of a loop from a `break`
            // still holding what the way through held.
            var endsTheBody = false

            // Whether what was just read carries an obligation: read off a
            // name that held one, or answered by a call or a cast declaring
            // one. Whatever takes the value takes the obligation with it.
            var carriesObligation = false

            // MARK: - Initializer
            // A body's start: what it was handed to keep, which declares a
            // type written `linear`, and what it was handed to read.
            init(taking taken: Set<Name>, borrowing borrowed: Set<Name>) {
                live = Set(taken.map { name in Local(name) })
                linear = live
                self.borrowed = Set(borrowed.map { name in Local(name) })
            }

            // MARK: - Public
            func local(_ name: Name) -> Local {
                scope[name] ?? Local(name)
            }

            func holding(_ name: Name) -> Holding? {
                let local = local(name)

                if live.contains(local) { return .live }
                if borrowed.contains(local) { return .borrowed }
                if moved.contains(local) { return .gone }

                return nil
            }

            mutating func move(_ name: Name) {
                let local = local(name)

                live.remove(local)
                moved.insert(local)
            }

            mutating func take(_ name: Name) {
                let local = local(name)

                moved.remove(local)
                live.insert(local)
            }

            // Two ways through, joined. Being handed on and being borrowed are
            // facts either way may have made, so both accumulate; what is
            // still held has to be the same on both, which the arms say where
            // they are judged.
            func merged(with other: Held) -> Held {
                var joined = self
                joined.moved.formUnion(other.moved)
                joined.borrowed.formUnion(other.borrowed)
                joined.linear.formUnion(other.linear)
                joined.endsTheBody = endsTheBody && other.endsTheBody
                joined.carriesObligation = false

                return joined
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

        // How many names the walk has seen a body introduce, so each one is
        // told from any other of its spelling.
        private var introductions = 0

        // MARK: - Initializer
        init(context: TypingContext, place: Place) {
            self.context = context
            self.place = place
        }

        // MARK: - Public
        // What is still held after this block. `guarded` is why a move is
        // refused here, and nil where one is allowed. A name the block
        // introduces is read nowhere after it, so one still holding its value
        // where the block ends has dropped it. `reading` reads the result where
        // it is read otherwise than as an answer, handed the names the block
        // introduced: as an element or a field, or as a loop's result, read
        // once after the last round that finished.
        func through(
            _ block: Block,
            held: Held,
            guarded: String?,
            reading: ((Expression, Held, [Held.Local]) throws -> Held)? = nil
        ) throws -> Held {
            let scope = held.scope
            var held = held
            var introduced: [Held.Local] = []

            for statement in block.body.statements {
                // A borrowed name written bare is judged here, before the walk,
                // because the walk refuses one wherever a value leaves by and
                // a second name for the same borrow is not that.
                if case let (borrowed, .borrowed)? = operand(statement.expression, held: held) {
                    switch statement.binding {
                    case let .constant(name, _)?:
                        let local = introducing(name, into: &held)
                        introduced.append(local)
                        held.borrowed.insert(local)

                    case .variable?, .assignment?:
                        throw refusal(kept: borrowed)

                    case nil:
                        break
                    }

                    continue
                }

                switch statement.binding {
                case let .constant(name, declared)?, let .variable(name, declared)?:
                    held = try moving(statement.expression, held: held, guarded: guarded, naming: name)

                    let carries = held.carriesObligation
                    let local = introducing(name, into: &held)
                    introduced.append(local)

                    if declared?.handedOnce(in: context.types) == true {
                        held.linear.insert(local)
                    }

                    guard held.linear.contains(local) || carries else { continue }

                    held.live.insert(local)

                case let .assignment(path)?:
                    held = try written(statement.expression, into: path, held: held, guarded: guarded)

                // A statement naming nothing drops its answer, so an answer
                // carrying an obligation would be handed on to nobody.
                case nil:
                    held = try moving(statement.expression, held: held, guarded: guarded)

                    guard !held.carriesObligation else {
                        throw refusal(
                            "drops a value handed on once. A statement naming nothing"
                                + " drops what it answers, so the value is bound to a name"
                                + " or handed on where it is read"
                        )
                    }
                }
            }

            if let result = block.result {
                held = try reading.map { reading in try reading(result, held, introduced) }
                    ?? answered(result, held: held, guarded: guarded)
            } else {
                held.carriesObligation = false
            }

            if let stranded = introduced.first(where: held.live.contains) {
                throw refusal(stranded: stranded.name)
            }

            held.scope = scope

            return held
        }

        // A declaration's own body, walked. Its result is a way out of the
        // procedure the way a `return` is, which an inner block's result is
        // not, so the one entry that knows which block this is says so.
        func answering(_ block: Block, held: Held) throws {
            let left = try through(block, held: held, guarded: nil)

            if left.carriesObligation {
                handsOut = true
            }

            guard let stranded = left.live.sorted().first else { return }

            throw refusal(stranded: stranded.name)
        }

        // MARK: - Private
        // What is still held after this expression is read, and whether what
        // it answers carries an obligation. `naming` is the name of the
        // statement this is the value of, which a loop binds its round to and
        // an attempt its failure.
        private func moving(_ expression: Expression, held: Held, guarded: String?, naming: Name? = nil) throws -> Held {
            var held = held
            held.carriesObligation = false

            switch expression {
            case .literal:
                return held

            // A bare name is the value itself, so reading it is handing it on.
            // A path below the name reads a part of it and hands nothing on.
            case let .reference(path):
                guard let head = path.head else { return held }

                // A name that handed its value on holds nothing, so there is
                // no part of it left to read either, as a path or as an index.
                guard path.segments.count == 1 else {
                    try readable(path, held: held)

                    return held
                }

                // Everywhere a borrowed name may stand is read before the walk
                // reaches it: an operand of a slot that borrows, a second name
                // for the same borrow, and the two places a body answers from.
                // So reaching here is the name leaving by some other way.
                switch held.holding(head) {
                case .borrowed?:
                    throw refusal(gaveAway: head)

                case .gone?:
                    throw refusal(handedTwice: head)

                case nil:
                    return held

                case .live?:
                    if let guarded {
                        throw refusal("hands '\(head)' on \(guarded), which happens no fixed number of times")
                    }

                    held.move(head)
                    held.carriesObligation = true

                    return held
                }

            // A cast hands on what it read. Where that is nothing a name
            // held, the type it names is what says the value is one.
            case let .cast(value, type, _):
                var cast = try moving(value, held: held, guarded: guarded)
                cast.carriesObligation = cast.carriesObligation || type.handedOnce(in: context.types)

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

                try inside.answering(
                    block,
                    held: Held(
                        taking: Set(seeded.filter { parameter in
                            if case .consuming = parameter.declared { return true }

                            return false
                        }.map(\.name)),
                        borrowing: Set(seeded.filter { parameter in
                            if case .borrowing = parameter.declared { return true }

                            return false
                        }.map(\.name))
                    )
                )

                guard !inside.handsOut else {
                    throw refusal(
                        "carries a body answering a value handed on exactly once."
                            + " \(LinearityChecker.followedByAName), and a body carried as a"
                            + " value runs where no name is watching"
                    )
                }

                // A name another name of its spelling hides is one the
                // closure cannot reach.
                let reached = { (local: Held.Local, writing: Bool) in
                    held.local(local.name) == local && self.reaches(procedure, name: local.name, writing: writing)
                }

                for local in held.live.sorted() where reached(local, false) || reached(local, true) {
                    throw refusal(
                        "captures '\(local.name)' in a closure, which runs no fixed"
                            + " number of times"
                    )
                }

                for local in held.borrowed.sorted() where reached(local, false) {
                    throw refusal(
                        "captures '\(local.name)' in a closure, and it borrowed"
                            + " '\(local.name)' rather than taking it. A closure runs"
                            + " where the lending call cannot see"
                    )
                }

                for local in held.moved.sorted() where reached(local, false) {
                    throw refusal(
                        "reads '\(local.name)' in a closure after handing it on. A value"
                            + " written `linear` is gone from the name that held it once it"
                            + " is given away"
                    )
                }

                for local in held.linear.sorted() where reached(local, true) {
                    throw refusal(
                        "writes '\(local.name)' in a closure, and '\(local.name)' declares a"
                            + " value handed on once. A closure runs no fixed number of times"
                    )
                }

                return held

            // Which value is called is settled at run time, so nothing here
            // says what it does with what it was handed.
            // What runs inside an operand runs once, before the call. What the
            // operand answers is what the value called takes.
            case let .apply(callee, arguments):
                var carried = held

                for operand in [callee] + arguments {
                    if case let (name, .live)? = self.operand(operand, held: carried) {
                        throw refusal("hands '\(name)' on in a call of a value, which happens no fixed number of times")
                    }

                    carried = try moving(operand, held: carried, guarded: guarded)

                    guard !carried.carriesObligation else {
                        throw refusal("hands one on in a call of a value, which happens no fixed number of times")
                    }
                }

                return carried

            // What the declaration says it answers. One that wrote no `returns`
            // is read off its body, and the mark does not survive that reading,
            // so a declaration whose body answers one is held to writing it.
            case let .call(call):
                var called = try moving(call, held: held, guarded: guarded)
                called.carriesObligation = context.signature(of: call.selector)?.returns?.handedOnce(in: context.types) == true

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
                            "hands '\(parted[0].name)' on in one arm and not in the other."
                                + " What a body holds after a conditional is the same"
                                + " whichever arm ran"
                        )
                    }

                    return taken.merged(with: left)
                }

            // The round is read in the condition, the body and the result,
            // under the statement's name.
            case let .loop(condition, body):
                var round = held

                if let naming {
                    introducing(naming, into: &round)
                }

                // The condition is read once a round and once more, and the
                // result once, after the last round that finished.
                let asked = try moving(condition, held: round, guarded: "inside a loop")
                // What the result reads is what the last round that finished
                // left, so a value a round made and still holds there is one
                // every round before it dropped.
                var rounds = try through(body, held: asked, guarded: "inside a loop") { result, held, introduced in
                    if let stranded = introduced.first(where: held.live.contains) {
                        throw self.refusal(stranded: stranded.name)
                    }

                    return try self.answered(result, held: held, guarded: guarded)
                }

                // A round may not run at all, so a loop is a way through
                // whatever its body does.
                rounds.endsTheBody = false
                rounds.scope = held.scope

                return rounds

            // A failure lands between statements, so which of the body's moves
            // happened is not something the text shows. What finishes is the
            // body's own end or the rescue's, so an attempt leaves where both
            // of them do, holding what either way took.
            case let .attempt(body, rescue):
                let attempted = try through(body, held: held, guarded: "inside an attempt")

                // The failure is read in the rescue alone, under the
                // statement's name.
                var failed = held

                if let naming {
                    introducing(naming, into: &failed)
                }

                var rescued = try through(rescue, held: failed, guarded: "inside an attempt")

                rescued.live.formUnion(attempted.live)
                rescued.endsTheBody = attempted.endsTheBody && rescued.endsTheBody
                rescued.carriesObligation = attempted.carriesObligation || rescued.carriesObligation
                rescued.scope = held.scope

                return rescued

            case let .leave(leave):
                var carried = try leave.value.map { value in
                    try answered(value, held: held, guarded: guarded)
                } ?? held

                // A `return` hands a value to the caller the way a result does,
                // so it is asked the same question at the same moment: after
                // the move, where a name that was handed on reads as gone.
                // Only leaving the procedure ends the body. A `break` leaves the
                // construct and a `continue` ends the round, and what the body
                // was holding it holds still on the other side of either.
                guard leave.reach == .procedure else { return carried }

                carried.endsTheBody = true

                if carried.carriesObligation {
                    handsOut = true
                }

                carried.carriesObligation = false

                guard let stranded = carried.live.sorted().first else { return carried }

                throw refusal("leaves while still holding '\(stranded.name)'")
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
                try readable(path, held: held)

                return try carrying(expression, held: held, guarded: guarded)
            }

            var written = try moving(expression, held: held, guarded: guarded)

            guard written.holding(head) != .live else {
                throw refusal("writes over '\(head)', which it is still holding")
            }

            guard written.linear.contains(written.local(head)) || written.carriesObligation else { return written }

            if let guarded {
                throw refusal("writes one into '\(head)' \(guarded), which happens no fixed number of times")
            }

            written.take(head)

            return written
        }

        // Whether every name a path below its head reads, the head and each
        // index, still holds its value. A write below the head reads the head
        // as well, since it writes into the value the head holds.
        private func readable(_ path: Path, held: Held) throws {
            for read in path.expandingIndexReferences {
                guard let head = read.head, held.holding(head) == .gone else { continue }

                throw refusal(readAfterHanding: head)
            }
        }

        // What a body or a leave answers. A borrowed name answered hands on
        // what this body never took.
        private func answered(_ result: Expression, held: Held, guarded: String?) throws -> Held {
            if case let (name, .borrowed)? = operand(result, held: held) {
                throw refusal(answered: name)
            }

            return try moving(result, held: held, guarded: guarded)
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
                return try through(block, held: held, guarded: guarded) { result, held, _ in
                    try self.carrying(result, held: held, guarded: guarded)
                }
            }

            let carried = try moving(expression, held: held, guarded: guarded)

            guard !carried.carriesObligation else { throw refusal(carriedValue: expression) }

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

                let handed = try moving(argument, held: held, guarded: guarded)

                // A value no name holds is taken by the slot or by nobody.
                if handed.carriesObligation {
                    if let guarded {
                        throw refusal("hands one on \(guarded), which happens no fixed number of times")
                    }

                    guard case .consuming? = parameter?.declared else {
                        throw refusal(
                            "hands '\(call.selector)' a value handed on once, and the slot says"
                                + " nothing about what it does with one. A slot takes the"
                                + " obligation by writing `consuming`"
                        )
                    }
                }

                return handed
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

        // Whether a closure's body reaches the name around it, at any depth:
        // writes it, `writing`, or otherwise reads it. A body introducing the
        // spelling reaches its own name from the statement after on, a loop
        // its round from the start of the loop and an attempt its failure in
        // the rescue, and a closure taking it as a parameter its own
        // throughout.
        private func reaches(_ procedure: Procedure, name: Name, writing: Bool) -> Bool {
            guard !procedure.signature.names.contains(name), let block = procedure.block else { return false }

            return reaches(block.body, result: block.result, name: name, writing: writing)
        }

        private func reaches(_ body: Body, result: Expression?, name: Name, writing: Bool) -> Bool {
            for statement in body.statements {
                if case let .assignment(path)? = statement.binding {
                    let indexes = path.segments.compactMap { segment -> Path? in
                        guard case let .indexRef(index, _) = segment else { return nil }

                        return index
                    }

                    if writing ? path.head == name : indexes.contains(where: { index in reads(index, name: name) }) {
                        return true
                    }
                }

                guard statement.binding?.introduced == name else {
                    if reaches(statement.expression, name: name, writing: writing) { return true }

                    continue
                }

                switch statement.expression {
                case .loop:
                    return false

                case let .attempt(attempted, _):
                    return reaches(attempted.body, result: attempted.result, name: name, writing: writing)

                default:
                    return reaches(statement.expression, name: name, writing: writing)
                }
            }

            return result.map { result in reaches(result, name: name, writing: writing) } ?? false
        }

        private func reaches(_ expression: Expression, name: Name, writing: Bool) -> Bool {
            switch expression {
            case .literal:
                return false

            case let .reference(path):
                return !writing && reads(path, name: name)

            case let .array(elements):
                return elements.contains { element in reaches(element, name: name, writing: writing) }

            case let .record(fields):
                return fields.values.contains { field in reaches(field, name: name, writing: writing) }

            case let .closure(procedure):
                return reaches(procedure, name: name, writing: writing)

            case let .apply(callee, arguments):
                return ([callee] + arguments).contains { operand in reaches(operand, name: name, writing: writing) }

            case let .cast(value, _, _):
                return reaches(value, name: name, writing: writing)

            case let .block(block):
                return reaches(block.body, result: block.result, name: name, writing: writing)

            case let .conditional(condition, then, otherwise):
                return reaches(condition, name: name, writing: writing)
                    || reaches(then, result: nil, name: name, writing: writing)
                    || reaches(otherwise ?? [], result: nil, name: name, writing: writing)

            case let .loop(condition, body):
                return reaches(condition, name: name, writing: writing)
                    || reaches(body.body, result: body.result, name: name, writing: writing)

            case let .attempt(body, rescue):
                return reaches(body.body, result: body.result, name: name, writing: writing)
                    || reaches(rescue.body, result: rescue.result, name: name, writing: writing)

            case let .call(call):
                return call.arguments.contains { argument in reaches(argument, name: name, writing: writing) }

            case let .leave(leave):
                return leave.value.map { value in reaches(value, name: name, writing: writing) } ?? false
            }
        }

        private func reads(_ path: Path, name: Name) -> Bool {
            path.expandingIndexReferences.contains { path in path.head == name }
        }

        // A name the body introduces, told from any other of its spelling, and
        // what the spelling reads from here on.
        @discardableResult
        private func introducing(_ name: Name, into held: inout Held) -> Held.Local {
            introductions += 1

            let local = Held.Local(name, introduction: introductions)
            held.scope[name] = local

            return local
        }

        private func refusal(readAfterHanding name: Name) -> BuildError {
            refusal(
                "reaches into '\(name)' after handing it on. A value written `linear`"
                    + " is gone from the name that held it once it is given away"
            )
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
                taking: Set(taken.map(\.name)),
                borrowing: Set(borrowed.map(\.name))
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

        // A caller binds the answer as what `returns` declares, so one that
        // declares a type not written `linear` hands the obligation to nobody.
        if let returns = signature.returns, walk.handsOut, !returns.handedOnce(in: context.types) {
            throw BuildError(
                "answers a value handed on exactly once and declares it answers"
                    + " \(returns.rendered). A caller holds what it answers as the"
                    + " declared type, so the obligation would be held by nobody",
                at: place.child(.result)
            )
        }
    }

    // MARK: - Private
}
