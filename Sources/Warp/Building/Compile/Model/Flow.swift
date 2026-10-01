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
// indefinite one joins with what the name held.
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

    // A write made on a way that left.
    mutating func escape(_ type: LoweredType, on name: Name) {
        escaped[name] = escaped[name]?.joined(type) ?? type
    }

    // The same landing rule, on what the names around the flow hold. A box
    // that declared its type was checked where it was written, so a write into
    // it changes nothing about what it holds.
    func apply(to environment: inout [Name: Binding]) {
        for (name, write) in written {
            guard case let .assigned(held)? = environment[name] else { continue }

            environment[name] = .assigned(write.definite ? write.type : held.joined(write.type))
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
