//
//  Flow.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// What ran inside an expression may have written the enclosing names. The one
// thing a nested body does that the body around it has to know about, because
// a write is to a box the enclosing body holds. A flow gathers those writes
// with the one distinction the reading after needs: whether every finishing
// way through made the write. A definite write retypes the name; an
// indefinite one joins with what the name held. It gathers the boxes held
// here the same way, which no later write retypes.
struct Flow {
    // MARK: - Property
    var written: [Name: (type: LoweredType, definite: Bool)] = [:]

    // What was written on ways that left. It flows past nothing here (no run
    // comes back from a leave) but a `break` ends only its loop and an
    // attempt's body only its attempt, so the construct that absorbs the leave
    // puts these back in play. Nothing about an escaped write is ever certain,
    // and the type says so by having no room for the claim. A flow that leaves
    // holds everything it wrote here and nothing under `written`.
    var escaped: [Name: LoweredType] = [:]

    // Whether every way through leaves.
    var leaves = false

    // What every `return` inside here carried out of the procedure, each with
    // the value it carried where that is a constant, and where it was written.
    // Nothing absorbs one, so this only ever gathers on the way up. Kept apart
    // rather than joined, so each is held to the declaration on its own: two
    // that disagree join to `any`, and `any` fits everything.
    var answered: [(reading: LoweredType, value: Value?, place: Place)] = []

    // The boxes a closure captured or a call handed in place here, each with
    // the type it read as there, or the type it was already held to. A
    // closure or a callee may read and write the box later as that type, so
    // from here on every write to it is held to that type, on whichever way
    // the box was taken. Taking a box already held says so again, so a round
    // read where its earlier rounds held the box takes it the same way.
    var held: [Name: LoweredType] = [:]

    // MARK: - Initializer
    // MARK: - Public
    // How a write lands on what an earlier write left. A definite write
    // replaces; an indefinite one may not have happened, so it joins with what
    // was there, and whether the name was written at all stays the earlier
    // fact.
    mutating func land(_ later: (type: LoweredType, definite: Bool), on name: Name) {
        guard let held = written[name], !later.definite else {
            written[name] = later
            return
        }

        written[name] = (held.type.joined(later.type), held.definite)
    }

    // A box taken here, held to what it read as.
    mutating func hold(_ type: LoweredType, on name: Name) {
        held[name] = held[name]?.joined(type) ?? type
    }

    // The boxes another flow took, taken here too.
    mutating func hold(from other: Flow) {
        for (name, type) in other.held {
            hold(type, on: name)
        }
    }

    // A write made on a way that left.
    mutating func escape(_ type: LoweredType, on name: Name) {
        escaped[name] = escaped[name]?.joined(type) ?? type
    }

    // The same landing rule, on what the names around the flow hold. A box
    // that declared its type was checked where it was written, so a write into
    // it changes nothing about what it holds. A box taken here holds what it
    // was taken as from then on.
    func apply(to environment: inout [Name: Binding]) {
        for (name, write) in written {
            guard let held = environment[name], held.holding == .assigned else { continue }

            environment[name] = Binding(.assigned, write.definite ? write.type : held.type.joined(write.type))
        }

        for (name, type) in held {
            guard let current = environment[name], current.holding == .assigned else { continue }

            environment[name] = Binding(.held(type), current.type)
        }
    }

    // A way out took this flow with it: what it wrote is not the body's to hand
    // on (no run comes back) but it is not gone either, because the writes are
    // in the boxes and a loop or an attempt may absorb the leave. They move
    // aside as escaped, indefinite because how far the way got is the run's
    // fact.
    func leaving() -> Flow {
        var left = self

        left.leaves = true

        for (name, write) in written {
            left.escape(write.type, on: name)
        }

        left.written = [:]

        return left
    }

    // The construct the ways out stop at. A `break` ends only its loop and the
    // flow after it goes on, so what escaped on the way is back in play, and
    // nothing a construct absorbed is certain: the round may not have run, the
    // body may have stopped anywhere. A leave that reaches further (a
    // `return`) is over-counted here, which only widens a join.
    func absorbed() -> Flow {
        var stopped = indefinite()

        stopped.leaves = false

        for (name, type) in stopped.escaped {
            stopped.land((type, false), on: name)
        }

        stopped.escaped = [:]

        return stopped
    }

    // One thing ran after another: each later write lands by the landing
    // rule, what escaped keeps riding for the construct that absorbs it, and a
    // sequence whose tail leaves leaves, everything written on the way going
    // with it.
    func followed(by second: Flow) -> Flow {
        guard !leaves else { return self }

        var flowed = self

        for (name, later) in second.written {
            flowed.land(later, on: name)
        }

        for (name, type) in second.escaped {
            flowed.escape(type, on: name)
        }

        flowed.hold(from: second)
        flowed.answered += second.answered

        return second.leaves ? flowed.leaving() : flowed
    }

    // One of two ways ran. A name both wrote holds either; a name one wrote may
    // not have been written at all, so nothing about it is definite. A way
    // that leaves hands on nothing (the ways that finish are the only ways a
    // reading after can stand on) but what it wrote rides along as escaped,
    // for the construct that absorbs the leave.
    func joined(with declined: Flow) -> Flow {
        var flowed = Flow()

        for side in [escaped, declined.escaped] {
            for (name, type) in side {
                flowed.escape(type, on: name)
            }
        }

        flowed.answered = answered + declined.answered

        flowed.hold(from: self)
        flowed.hold(from: declined)

        switch (leaves, declined.leaves) {
        // A leaving flow holds its writes as escaped alone, gathered above.
        case (true, true):
            flowed.leaves = true

        case (true, false):
            flowed.written = declined.written

        case (false, true):
            flowed.written = written

        case (false, false):
            for name in Set(written.keys).union(declined.written.keys) {
                switch (written[name], declined.written[name]) {
                case let (mine?, theirs?):
                    flowed.written[name] = (mine.type.joined(theirs.type), mine.definite && theirs.definite)

                case let (mine?, nil):
                    flowed.written[name] = (mine.type, false)

                case let (nil, theirs?):
                    flowed.written[name] = (theirs.type, false)

                case (nil, nil):
                    break
                }
            }
        }

        return flowed
    }

    // The writes of a body that may not have run, or not run to its end.
    func indefinite() -> Flow {
        var indefinite = self

        indefinite.written = written.mapValues { write in (write.type, false) }

        return indefinite
    }

    // MARK: - Private
}
