//
//  Way.swift
//  Warp
//
//  Created by JSilver on 10/2/26.
//

import Foundation

// What one way through a piece of a body did to the names around it: what it
// wrote, and which boxes it took. A flow holds the way that goes on and the
// ways that left, each one of these, so every rule for combining ways is
// written here once and applies to whichever ways are combined.
struct Way {
    // MARK: - Property
    // The names written, each with whether every finishing way through made
    // the write. A definite write retypes the name; an indefinite one joins
    // with what the name held.
    var written: [Name: (type: LoweredType, definite: Bool)] = [:]

    // The boxes a closure captured or a call handed in place, each with the
    // type it read as there, or the type it was already held to. A closure or
    // a callee may read and write the box later as that type, so from then on
    // every write to it is held to that type.
    var held: [Name: LoweredType] = [:]

    // MARK: - Initializer
    // MARK: - Public
    // Ways of which one ran, met: each joined with the ones before it, or nil
    // where there is none.
    static func met(_ ways: [Way], meeting: Flow.Meeting) rethrows -> Way? {
        guard var met = ways.first else { return nil }

        for way in ways.dropFirst() {
            met = try met.joined(with: way, meeting: meeting)
        }

        return met
    }

    // How a write lands on what an earlier write left. A definite write
    // replaces; an indefinite one may not have happened, so it joins with what
    // was there, and whether the name was written at all stays the earlier
    // fact. What lands is the reading as a name holds it, so a literal whole
    // number written to a name is an Int there.
    mutating func land(_ landing: (type: LoweredType, definite: Bool), on name: Name) {
        let later = (type: landing.type.asHeld, definite: landing.definite)

        guard let before = written[name], !later.definite else {
            written[name] = later
            return
        }

        written[name] = (before.type.joined(later.type), before.definite)
    }

    // A box taken, held to what it read as. One taken already on this way
    // stays held to what it was taken as first: the walk read it held then.
    mutating func hold(_ type: LoweredType, on name: Name) {
        held[name] = held[name] ?? type.asHeld
    }

    // This way, then another after it.
    func followed(by later: Way) -> Way {
        var flowed = self

        for (name, write) in later.written {
            flowed.land(write, on: name)
        }

        for (name, type) in later.held {
            flowed.hold(type, on: name)
        }

        return flowed
    }

    // One of two ways ran. A name both wrote holds either; a name one wrote may
    // not have been written at all, so nothing about it is definite. A box
    // both took stays at the one type both held it to, which the meeting
    // judges; one only one took is held.
    func joined(with other: Way, meeting: Flow.Meeting) rethrows -> Way {
        var flowed = Way()

        for name in Set(written.keys).union(other.written.keys) {
            switch (written[name], other.written[name]) {
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

        flowed.held = held

        for (name, theirs) in other.held.sorted(by: { $0.key < $1.key }) {
            guard let mine = held[name] else {
                flowed.held[name] = theirs
                continue
            }

            try meeting(name, mine, theirs)
        }

        return flowed
    }

    // This way, on what the names around it hold. A box that declared its
    // type was checked where it was written, so a write into it changes
    // nothing about what it holds. A box taken holds what it was taken as
    // from then on, and a write into it leaves it reading that type.
    func apply(to environment: inout [Name: Binding]) {
        for (name, write) in written {
            guard let current = environment[name] else { continue }

            switch current.holding {
            case .assigned:
                environment[name] = current.map { read in write.definite ? write.type : read.joined(write.type) }

            case let .held(type):
                environment[name] = current.map { read in write.definite ? type : read.joined(type) }

            case .fixed, .declared:
                continue
            }
        }

        for (name, type) in held {
            guard let current = environment[name] else { continue }

            environment[name] = current.taken(to: type)
        }
    }

    // The same way where it may not have run, or not run to its end.
    func indefinite() -> Way {
        var indefinite = self

        indefinite.written = written.mapValues { write in (write.type, false) }

        return indefinite
    }

    // The same way seen from outside a body that declared these names: what
    // it did to them is that body's own.
    func outside(_ locals: Set<Name>) -> Way {
        var seen = self

        seen.written = written.filter { name, _ in !locals.contains(name) }
        seen.held = held.filter { name, _ in !locals.contains(name) }

        return seen
    }

    // MARK: - Private
}
